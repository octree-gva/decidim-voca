# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "decidim/voca/snapshot"

module Decidim
  module Voca
    module Snapshot
      describe Dump do
        let(:work_dir) { Dir.mktmpdir }
        let(:public_dir) { Dir.mktmpdir }
        let(:password) { "test-password" }
        let(:db_config) do
          {
            host: "localhost",
            port: 5432,
            username: "decidim",
            password: "password",
            database: "decidim_test"
          }
        end

        before do
          allow(Rails).to receive(:root).and_return(Pathname.new(Dir.mktmpdir))
          allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(
            double(configuration_hash: db_config)
          )
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:rm)
          allow(FileUtils).to receive(:mv)
        end

        after do
          FileUtils.rm_rf(work_dir.to_s)
          FileUtils.rm_rf(public_dir.to_s)
        end

        describe "#initialize" do
          it "generates a unique snapshot name" do
            dump1 = described_class.new
            dump2 = described_class.new
            expect(dump1.snapshot_name).not_to eq(dump2.snapshot_name)
            expect(dump1.snapshot_name).to match(/^snapshot-[0-9a-f-]+\.vocasnap$/)
          end
        end

        describe "#execute" do
          let(:dump) { described_class.new(work_dir:, public_dir:) }

          before do
            allow(dump).to receive(:setup_directories)
            allow(dump).to receive(:dump_database)
            allow(dump).to receive(:create_lockfile)
            allow(dump).to receive(:create_archive).and_return(Pathname.new("archive.tar.gz"))
            allow(dump).to receive(:encrypt_archive)
            allow(dump).to receive(:cleanup_old_snapshots)
            allow(dump).to receive(:move_to_public)
            allow(dump).to receive(:display_download_link)
          end

          it "executes all required steps" do
            dump.execute(password:)

            expect(dump).to have_received(:setup_directories)
            expect(dump).to have_received(:dump_database)
            expect(dump).to have_received(:create_lockfile)
            expect(dump).to have_received(:encrypt_archive).with(password)
          end
        end

        describe "#dump_database" do
          let(:dump) { described_class.new(work_dir:, public_dir:) }

          before do
            allow(FileUtils).to receive(:mkdir_p)
            allow(File).to receive(:exist?).and_return(false)
          end

          it "calls pg_dump with correct parameters" do
            allow(dump).to receive(:system).and_return(true)
            dump.send(:dump_database)
            expect(dump).to have_received(:system).with(
              hash_including("PGPASSWORD" => "password"),
              "pg_dump",
              "-h", "localhost",
              "-p", "5432",
              "-U", "decidim",
              "-d", "decidim_test",
              "--no-owner",
              "--no-acl",
              "-f", anything
            )
          end

          it "raises error if pg_dump fails" do
            allow(dump).to receive(:system).and_return(false)
            expect { dump.send(:dump_database) }.to raise_error("Database dump failed")
          end
        end

        describe "#create_archive" do
          let(:dump) { described_class.new(work_dir:, public_dir:) }
          let(:storage_path) { Rails.root.join("storage") }

          before do
            allow(Rails).to receive(:root).and_return(Pathname.new(Dir.mktmpdir))
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:cp_r)
            allow(Dir).to receive(:exist?).and_call_original
            allow(Dir).to receive(:exist?).with(storage_path.to_s).and_return(false)
            allow(FileUtils).to receive(:cd).and_yield
            allow(dump).to receive(:system).and_return(true)
          end

          it "creates tar archive with database dump and lockfile" do
            dump.send(:create_archive)
            expect(dump).to have_received(:system).with(
              "tar", "-czf", anything, "dump.sql", "vocasnap.lockfile"
            )
          end
        end

        describe "#encrypt_archive" do
          let(:dump) { described_class.new(work_dir:, public_dir:) }

          before do
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:rm)
            Pathname.new(work_dir).join("#{dump.snapshot_name}.tar.gz")
            allow(dump).to receive(:work_dir).and_return(Pathname.new(work_dir))
            allow(File).to receive(:exist?).and_return(true)
            allow(Encryption).to receive(:encrypt_file)
          end

          it "encrypts the archive and removes unencrypted file" do
            archive_path = Pathname.new(work_dir).join("#{dump.snapshot_name}.tar.gz")
            encrypted_path = Pathname.new(work_dir).join(dump.snapshot_name)
            allow(Encryption).to receive(:encrypt_file)

            dump.send(:encrypt_archive, password)

            expect(Encryption).to have_received(:encrypt_file).with(
              archive_path.to_s,
              encrypted_path.to_s,
              password
            )
            expect(FileUtils).to have_received(:rm).with(archive_path.to_s)
          end
        end
      end
    end
  end
end
