# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "rake"
require "shellwords"

module Decidim
  module Voca
    module Snapshot
      class Restore
        attr_reader :snapshot_path, :work_dir

        def initialize(snapshot_path, work_dir: nil)
          @snapshot_path = snapshot_path
          root = Rails.root
          work_dir ||= root.join("tmp", "vocasnap-restore")
          @work_dir = Pathname.new(work_dir)
        end

        def execute(password:, is_test_instance: false)
          root = Rails.root
          Dir.chdir(root) do
            load_rails_tasks
            setup_directories
            download_snapshot if remote_path?
            decrypt_snapshot(password)
            extract_archive
            validate_lockfile
            check_gitignore
            check_prerequisites
            confirm_database_drop
            restore_migrations
            restore_database
            migrate_active_storage_to_local
            restore_storage
            run_migrations
            anonymize_if_test(is_test_instance)
            install_dependencies
            precompile_assets
            cleanup
            display_completion_message
          end
        end

        private

        def disconnect_active_record
          ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
        end

        def reconnect_active_record
          disconnect_active_record
          ActiveRecord::Base.establish_connection
        end

        def load_rails_tasks
          Rails.application.load_tasks if Rails.application.respond_to?(:load_tasks)
        end

        def setup_directories
          FileUtils.mkdir_p(work_dir)
        end

        def remote_path?
          snapshot_path.start_with?("http://") || snapshot_path.start_with?("https://")
        end

        def download_snapshot
          local_path = work_dir.join(File.basename(snapshot_path))
          Rails.logger.debug { "Downloading snapshot from #{snapshot_path}..." }

          require "open-uri"
          # rubocop:disable Security/Open
          URI.open(snapshot_path) do |remote|
            # rubocop:enable Security/Open
            File.binwrite(local_path, remote.read)
          end

          @snapshot_path = local_path.to_s
        end

        def decrypt_snapshot(password)
          encrypted_path = snapshot_path
          decrypted_path = work_dir.join("snapshot.tar.gz")

          Encryption.decrypt_file(encrypted_path, decrypted_path.to_s, password)
          @snapshot_path = decrypted_path.to_s
        end

        def extract_archive
          FileUtils.cd(work_dir) do
            system("tar", "-xzf", snapshot_path) || raise("Archive extraction failed")
          end
        end

        def validate_lockfile
          lockfile_path = work_dir.join("vocasnap.lockfile")
          return if Lockfile.validate(lockfile_path.to_s)

          snapshot_modules = extract_snapshot_modules(lockfile_path)
          current_modules = Lockfile.extract_decidim_modules
          missing_modules = find_missing_modules(snapshot_modules, current_modules)

          error_message = "Lockfile validation failed. "
          error_message += "Missing modules: #{missing_modules.join(", ")}. " if missing_modules.any?
          error_message += "Module versions or dependencies do not match the snapshot. " \
                           "Please install the required modules and versions before restoring."

          raise error_message
        end

        def extract_snapshot_modules(lockfile_path)
          return {} unless File.exist?(lockfile_path)

          snapshot_data = JSON.parse(File.read(lockfile_path))
          snapshot_data["decidim_modules"] || {}
        end

        def find_missing_modules(snapshot_modules, current_modules)
          snapshot_module_names = snapshot_modules.keys.map(&:to_s)
          current_module_names = current_modules.keys.map(&:to_s)
          snapshot_module_names - current_module_names
        end

        def check_gitignore
          root = Rails.root
          gitignore_path = root.join(".gitignore")
          return unless File.exist?(gitignore_path)

          gitignore_content = File.read(gitignore_path)
          return if gitignore_content.include?("*.vocasnap") || gitignore_content.include?("*.vocasnapshot")

          Rails.logger.debug "Warning: .gitignore does not exclude *.vocasnap files"
          Rails.logger.debug "Add *.vocasnap to .gitignore? (y/N): "
          response = $stdin.gets.chomp.downcase
          if response == "y"
            File.open(gitignore_path, "a") { |f| f.puts("\n*.vocasnap") }
            Rails.logger.debug "Added *.vocasnap to .gitignore"
          end
        end

        def check_prerequisites
          PrerequisitesChecker.new.check!
        end

        def confirm_database_drop
          loop do
            Rails.logger.debug "This will drop the current database. Continue? (yes/no): "
            response = $stdin.gets.chomp.downcase
            if response == "yes"
              break
            elsif response == "no"
              raise "Restore cancelled"
            end
          end

          disconnect_active_record
          system("bundle exec rails db:drop", exception: true)
        end

        def restore_database
          disconnect_active_record
          db_config = db_config_without_connection
          sql_dump_path = work_dir.join("dump.sql")

          raise "Database dump not found in snapshot" unless File.exist?(sql_dump_path)

          system("bundle exec rails db:create", exception: true)
          reconnect_active_record

          prepared_dump_path = replace_hosts_in_dump(sql_dump_path)
          raise "Prepared database dump not found: #{prepared_dump_path}" unless File.exist?(prepared_dump_path)

          restore_from_sql_dump(db_config, prepared_dump_path)
        end

        def replace_hosts_in_dump(sql_dump_path)
          metadata_path = work_dir.join("metadata.json")
          return sql_dump_path unless File.exist?(metadata_path)

          metadata = JSON.parse(File.read(metadata_path))
          hosts = metadata["hosts"] || []
          return sql_dump_path if hosts.empty?

          content = File.read(sql_dump_path)

          hosts.each do |old_host|
            Rails.logger.debug { "Enter new host for #{old_host} (or press Enter to keep original): " }
            new_host = $stdin.gets.chomp
            next if new_host.empty?

            content.gsub!("http://#{old_host}", "http://#{new_host}")
            content.gsub!("https://#{old_host}", "https://#{new_host}")
          end

          modified_dump_path = work_dir.join("dump_modified.sql")
          File.write(modified_dump_path, content)
          modified_dump_path.to_s
        end

        def db_config_without_connection
          # Get config without establishing connection
          env_name = Rails.env.to_s
          config = ActiveRecord::Base.configurations.configurations.find do |db_config|
            db_config.env_name.to_s == env_name
          end || ActiveRecord::Base.configurations.configurations.first

          config&.configuration_hash || {}
        end

        def restore_from_sql_dump(db_config, sql_dump_path)
          cmd = [
            "psql",
            "-h", (db_config[:host] || "localhost").to_s,
            "-p", (db_config[:port] || 5432).to_s,
            "-U", (db_config[:username] || "postgres").to_s,
            "-d", db_config[:database].to_s,
            "--set", "ON_ERROR_STOP=off", # Continue on non-critical errors
            "-f", sql_dump_path.to_s
          ]

          env = { "PGPASSWORD" => db_config[:password] }
          stdout, stderr, status = Open3.capture3(env, *cmd)

          # Check for critical errors (relation does not exist)
          critical_errors = stderr.lines.select do |line|
            line.match?(/ERROR.*relation.*does not exist/i) && !line.match?(/already exists/i)
          end

          if critical_errors.any?
            warn "Critical errors detected:", critical_errors.join
            warn "Full stderr:", stderr
            raise "Database restore failed: Critical errors during restore"
          end

          unless status.success?
            warn "STDOUT:", stdout
            warn "STDERR:", stderr
            raise "Database restore failed with errors"
          end

          # Verify data was restored by checking organizations table
          verify_restore(db_config, stdout, stderr)
        end

        def verify_restore(_db_config, stdout = nil, stderr = nil)
          # Reconnect to ensure we see the restored data
          reconnect_active_record

          # Check if table exists before querying
          table_exists = ActiveRecord::Base.connection.select_value(
            "SELECT EXISTS (
              SELECT FROM information_schema.tables
              WHERE table_schema = 'public'
              AND table_name = 'decidim_organizations'
            )"
          )

          unless table_exists
            error_msg = "Database restore verification failed: decidim_organizations table does not exist after restore"
            if stdout || stderr
              error_msg += "\n\npsql output:\n"
              error_msg += "STDOUT:\n#{stdout}\n" if stdout.present?
              error_msg += "STDERR:\n#{stderr}\n" if stderr.present?
            end
            raise error_msg
          end

          org_count = ActiveRecord::Base.connection.select_value(
            "SELECT COUNT(*) FROM decidim_organizations"
          ).to_i

          raise "Database restore verification failed: decidim_organizations table is empty after restore" if org_count.zero?
        end

        def restore_migrations
          migrations_snapshot = work_dir.join("migrations")
          root = Rails.root
          migrate_target = root.join("db", "migrate")

          return unless Dir.exist?(migrations_snapshot.to_s)

          FileUtils.mkdir_p(migrate_target.to_s)
          Dir.glob(migrate_target.join("*.rb")).each do |migration_file|
            FileUtils.rm(migration_file)
          end

          Dir.glob(migrations_snapshot.join("*.rb")).each do |migration_file|
            FileUtils.cp(migration_file, migrate_target.join(File.basename(migration_file)))
          end
        end

        def migrate_active_storage_to_local
          reconnect_active_record

          # Update all blobs that are not already using local service
          # rubocop:disable Rails/SkipsModelValidations
          updated_count = ActiveStorage::Blob.where.not(service_name: "local").update_all(service_name: "local")
          # rubocop:enable Rails/SkipsModelValidations

          Rails.logger.debug { "Migrated #{updated_count} Active Storage blob(s) to local service" } if updated_count.positive?
        end

        def restore_storage
          storage_snapshot = work_dir.join("storage")
          root = Rails.root
          storage_target = root.join("storage")

          return unless Dir.exist?(storage_snapshot.to_s)

          FileUtils.rm_rf(storage_target.to_s)
          FileUtils.mv(storage_snapshot.to_s, storage_target.to_s)
        end

        def run_migrations
          # Migration files have been restored from snapshot
          # Database schema is already restored from the dump
          # Run migrations to ensure schema_migrations table is in sync
          disconnect_active_record
          Rake::Task["db:migrate"].invoke
          reconnect_active_record

          status_output, = Open3.capture2("bundle exec rails db:migrate:status 2>&1")
          Rails.logger.debug "Warning: Some migrations are still down. Please check db:migrate:status" if status_output.include?("down")
        end

        def anonymize_if_test(is_test_instance)
          return unless is_test_instance

          reconnect_active_record
          system("bundle exec rails decidim:voca:anonymize", exception: true)
        end

        def install_dependencies
          system("npm install", exception: true)
        end

        def precompile_assets
          packs_dir = Rails.public_path.join("decidim-packs")
          backup_dir = Rails.public_path.join("decidim-packs.bak")

          if Dir.exist?(packs_dir.to_s)
            FileUtils.rm_rf(backup_dir.to_s)
            FileUtils.mv(packs_dir.to_s, backup_dir.to_s)
          end

          Rake::Task["assets:precompile"].invoke

          unless Dir.exist?(packs_dir.to_s)
            FileUtils.mv(backup_dir.to_s, packs_dir.to_s) if Dir.exist?(backup_dir.to_s)
            raise("Asset precompilation failed: decidim-packs directory was not created")
          end

          FileUtils.rm_rf(backup_dir.to_s)
        end

        def cleanup
          FileUtils.rm_rf(work_dir.to_s)
          if File.exist?(snapshot_path) && !remote_path? && File.file?(snapshot_path)
            root = Rails.root
            local_snapshot = Pathname.new(snapshot_path).absolute? ? snapshot_path : root.join(snapshot_path)
            FileUtils.rm_f(local_snapshot.to_s)
          end
        end

        def display_completion_message
          Rails.logger.debug { "\n#{("=" * 60)}" }
          Rails.logger.debug "Restore completed successfully!"
          Rails.logger.debug "=" * 60
          Rails.logger.debug "Ready. You can delete the remote snapshot file."
          Rails.logger.debug "=" * 60
        end
      end
    end
  end
end
