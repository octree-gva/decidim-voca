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
          FileUtils.rm_rf(work_dir.to_s) if Dir.exist?(work_dir.to_s)
          FileUtils.rm_rf(public_dir.to_s) if Dir.exist?(public_dir.to_s)
        end

        describe "#initialize" do
          it "sets default work and public directories" do
            allow(Rails).to receive(:root).and_return(Pathname.new("/app"))
            dump = described_class.new

            expect(dump.work_dir.to_s).to include("tmp/vocasnap")
            expect(dump.public_dir.to_s).to include("public")
          end

          it "accepts custom directories" do
            dump = described_class.new(work_dir: work_dir, public_dir: public_dir)

            expect(dump.work_dir.to_s).to eq(work_dir)
            expect(dump.public_dir.to_s).to eq(public_dir)
          end

          it "generates a unique snapshot name" do
            dump1 = described_class.new
            dump2 = described_class.new

            expect(dump1.snapshot_name).not_to eq(dump2.snapshot_name)
            expect(dump1.snapshot_name).to match(/^snapshot-[0-9a-f-]+\.vocasnap$/)
          end
        end

        describe "#execute" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }
          let(:pg_dump_success) { true }
          let(:tar_success) { true }

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

          it "calls all required steps in order" do
            expect(dump).to receive(:setup_directories).ordered
            expect(dump).to receive(:dump_database).ordered
            expect(dump).to receive(:create_lockfile).ordered
            expect(dump).to receive(:create_archive).ordered
            expect(dump).to receive(:encrypt_archive).ordered
            expect(dump).to receive(:cleanup_old_snapshots).ordered
            expect(dump).to receive(:move_to_public).ordered
            expect(dump).to receive(:display_download_link).ordered

            dump.execute(password: password)
          end
        end

        describe "#dump_database" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }

          before do
            allow(FileUtils).to receive(:mkdir_p)
            allow(File).to receive(:exist?).and_return(false)
          end

          it "calls pg_dump with correct parameters" do
            expect(dump).to receive(:system).with(
              { "PGPASSWORD" => "password" },
              "pg_dump",
              "-h", "localhost",
              "-p", "5432",
              "-U", "decidim",
              "-d", "decidim_test",
              "--no-owner",
              "--no-acl",
              "-f", anything
            ).and_return(true)

            dump.send(:dump_database)
          end

          it "raises error if pg_dump fails" do
            expect(dump).to receive(:system).and_return(false)

            expect { dump.send(:dump_database) }.to raise_error("Database dump failed")
          end
        end

        describe "#create_lockfile" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }

          before do
            allow(FileUtils).to receive(:mkdir_p)
            allow(Lockfile).to receive(:generate)
          end

          it "generates a lockfile" do
            lockfile_path = Pathname.new(work_dir).join("vocasnap.lockfile")
            expect(Lockfile).to receive(:generate).with(lockfile_path.to_s)

            dump.send(:create_lockfile)
          end
        end

        describe "#create_archive" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }
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
            expect(dump).to receive(:system).with(
              "tar", "-czf", anything, "dump.sql", "vocasnap.lockfile"
            ).and_return(true)

            dump.send(:create_archive)
          end

          context "when storage directory exists" do
            before do
              allow(Dir).to receive(:exist?).and_call_original
              allow(Dir).to receive(:exist?).with(storage_path.to_s).and_return(true)
              allow(FileUtils).to receive(:cp_r).with(storage_path.to_s, anything)
            end

            it "includes storage in archive" do
              expect(dump).to receive(:system).with(
                "tar", "-czf", anything, "dump.sql", "vocasnap.lockfile", "storage"
              ).and_return(true)

              dump.send(:create_archive)
            end
          end
        end

        describe "#encrypt_archive" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }

          before do
            allow(FileUtils).to receive(:mkdir_p)
            allow(FileUtils).to receive(:rm)
            archive_path = Pathname.new(work_dir).join("#{dump.snapshot_name}.tar.gz")
            allow(dump).to receive(:work_dir).and_return(Pathname.new(work_dir))
            allow(File).to receive(:exist?).and_return(true)
            allow(Encryption).to receive(:encrypt_file)
          end

          it "encrypts the archive file" do
            archive_path = Pathname.new(work_dir).join("#{dump.snapshot_name}.tar.gz")
            encrypted_path = Pathname.new(work_dir).join(dump.snapshot_name)

            expect(Encryption).to receive(:encrypt_file).with(
              archive_path.to_s,
              encrypted_path.to_s,
              password
            )

            dump.send(:encrypt_archive, password)
          end

          it "removes the unencrypted archive" do
            archive_path = Pathname.new(work_dir).join("#{dump.snapshot_name}.tar.gz")
            allow(Encryption).to receive(:encrypt_file)
            allow(dump).to receive(:work_dir).and_return(Pathname.new(work_dir))

            expect(FileUtils).to receive(:rm).with(archive_path.to_s)

            dump.send(:encrypt_archive, password)
          end
        end

        describe "#cleanup_old_snapshots" do
          let(:dump) { described_class.new(work_dir: work_dir, public_dir: public_dir) }

          before do
            allow(Dir).to receive(:glob).and_return([
              File.join(public_dir, "vocasnap", "old1.vocasnap"),
              File.join(public_dir, "vocasnap", "old2.vocasnap")
            ])
          end

          it "removes old snapshot files" do
            expect(FileUtils).to receive(:rm).with(File.join(public_dir, "vocasnap", "old1.vocasnap"))
            expect(FileUtils).to receive(:rm).with(File.join(public_dir, "vocasnap", "old2.vocasnap"))

            dump.send(:cleanup_old_snapshots)
          end
        end
      end
    end
  end
end

