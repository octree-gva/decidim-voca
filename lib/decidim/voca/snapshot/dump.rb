# frozen_string_literal: true

require "securerandom"
require "fileutils"
require "json"
require "pathname"

module Decidim
  module Voca
    module Snapshot
      class Dump
        attr_reader :work_dir, :snapshot_name, :public_dir

        def initialize(work_dir: nil, public_dir: nil)
          root = Rails.root
          @work_dir = Pathname.new(work_dir || root.join("tmp", "vocasnap"))
          @public_dir = Pathname.new(public_dir || root.join("public"))
          @snapshot_name = "snapshot-#{SecureRandom.uuid}.vocasnap"
        end

        def execute(password:)
          check_prerequisites
          setup_directories
          dump_database
          create_lockfile
          create_metadata
          create_archive
          encrypt_archive(password)
          cleanup_old_snapshots
          snapshot_path = move_to_public
          display_download_link
          snapshot_path
        rescue StandardError
          cleanup_work_dir
          raise
        ensure
          cleanup_work_dir
        end

        private

        def cleanup_work_dir
          return unless work_dir.exist?

          FileUtils.rm_rf(work_dir)
        end

        def check_prerequisites
          checker = PrerequisitesChecker.new
          checker.check_binaries!(%w(pg_dump tar))
          checker.check_pg_dump_version_compatibility!
        end

        def setup_directories
          FileUtils.mkdir_p(work_dir)
          FileUtils.mkdir_p(public_dir.join("vocasnap"))
        end

        def dump_database
          db_config = ActiveRecord::Base.connection_db_config.configuration_hash
          dump_path = work_dir.join("dump.sql")

          cmd = [
            "pg_dump",
            "-h", (db_config[:host] || "localhost").to_s,
            "-p", (db_config[:port] || 5432).to_s,
            "-U", (db_config[:username] || "postgres").to_s,
            "-d", db_config[:database].to_s,
            "--no-owner",
            "--no-acl",
            "-f", dump_path.to_s
          ]

          env = { "PGPASSWORD" => db_config[:password].to_s } if db_config[:password]

          system(env || {}, *cmd) || raise("Database dump failed")
        end

        def create_lockfile
          lockfile_path = work_dir.join("vocasnap.lockfile")
          Lockfile.generate(lockfile_path.to_s)
        end

        def create_metadata
          return unless defined?(Decidim::Organization)

          hosts = Decidim::Organization.pluck(:host).compact.uniq
          metadata = { hosts: }
          metadata_path = work_dir.join("metadata.json")
          File.write(metadata_path, JSON.generate(metadata), encoding: "UTF-8")
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def create_archive
          archive_path = work_dir.join("#{snapshot_name}.tar.gz")
          root = Rails.root
          storage_path = root.join("storage")

          FileUtils.cd(work_dir) do
            files_to_archive = [
              "dump.sql",
              "vocasnap.lockfile"
            ]

            files_to_archive << "metadata.json" if File.exist?("metadata.json")

            storage_dir = work_dir.join("storage")
            if Dir.exist?(storage_path.to_s)
              FileUtils.cp_r(storage_path.to_s, storage_dir.to_s)
              files_to_archive << "storage"
            elsif has_s3_attachments?
              FileUtils.mkdir_p(storage_dir)
              download_s3_attachments
              files_to_archive << "storage" if Dir.exist?(storage_dir.to_s) && Dir.entries(storage_dir.to_s).reject { |e| e.start_with?(".") }.any?
            end

            copy_migrations
            files_to_archive << "migrations" if Dir.exist?("migrations")

            success = system("tar", "-czf", archive_path.to_s, *files_to_archive)
            raise "Archive creation failed: tar command returned non-zero exit status" unless success
          end

          raise "Archive creation failed: file was not created at #{archive_path}" unless File.exist?(archive_path.to_s)

          archive_path
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def has_s3_attachments?
          return false unless defined?(ActiveStorage)

          ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::S3Service)
        rescue StandardError
          false
        end

        def download_s3_attachments
          return unless defined?(ActiveStorage)

          storage_dir = work_dir.join("storage")
          FileUtils.mkdir_p(storage_dir)

          ActiveStorage::Attachment.find_each do |attachment|
            next unless attachment.blob.service.is_a?(ActiveStorage::Service::S3Service)

            blob = attachment.blob
            blob_path = storage_dir.join(blob.key)
            FileUtils.mkdir_p(blob_path.dirname)

            File.binwrite(blob_path, blob.download)
          end
        rescue StandardError
          raise("Failed to download S3 attachments: #{e.message}")
        end

        def copy_migrations
          root = Rails.root
          migrate_path = root.join("db", "migrate")
          return unless Dir.exist?(migrate_path.to_s)

          migrations_dir = work_dir.join("migrations")
          FileUtils.mkdir_p(migrations_dir)

          Dir.glob(migrate_path.join("*.rb")).each do |migration_file|
            FileUtils.cp(migration_file, migrations_dir.join(File.basename(migration_file)))
          end
        end

        def encrypt_archive(password)
          archive_path = work_dir.join("#{snapshot_name}.tar.gz")
          encrypted_path = work_dir.join(snapshot_name)

          raise "Archive file not found: #{archive_path}. Snapshot creation may have failed earlier." unless File.exist?(archive_path.to_s)

          raise "Password cannot be empty" if password.blank?

          Encryption.encrypt_file(archive_path.to_s, encrypted_path.to_s, password)

          raise "Encryption failed: encrypted file was not created at #{encrypted_path}" unless File.exist?(encrypted_path.to_s)

          FileUtils.rm(archive_path.to_s)
        end

        def cleanup_old_snapshots
          Dir.glob(public_dir.join("vocasnap", "*.vocasnap")).each do |file|
            FileUtils.rm(file)
          end
        end

        def move_to_public
          source = work_dir.join(snapshot_name)
          destination = public_dir.join("vocasnap", snapshot_name)

          raise "Encrypted snapshot file not found: #{source}. Encryption may have failed." unless File.exist?(source.to_s)

          FileUtils.mv(source, destination)
          raise "Failed to move snapshot to public directory" unless File.exist?(destination.to_s)

          destination.to_s
        end

        def display_download_link
          uuid = snapshot_name.gsub(/^snapshot-|\.vocasnap$/, "")
          url = "/vocasnap/#{snapshot_name}"

          Rails.logger.debug { "\n#{("=" * 60)}" }
          Rails.logger.debug "Snapshot created successfully!"
          Rails.logger.debug "=" * 60
          Rails.logger.debug { "UUID: #{uuid}" }
          Rails.logger.debug { "Download URL: #{url}" }
          Rails.logger.debug "=" * 60
        end
      end
    end
  end
end
