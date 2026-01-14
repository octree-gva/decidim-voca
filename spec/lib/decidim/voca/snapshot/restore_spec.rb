# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "decidim/voca/snapshot"

module Decidim
  module Voca
    module Snapshot
      describe Restore do
        let(:work_dir) { Dir.mktmpdir }
        let(:snapshot_path) { File.join(work_dir, "snapshot.vocasnap") }
        let(:password) { "test-password" }
        let(:restore) { described_class.new(snapshot_path, work_dir: work_dir) }
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
          allow(FileUtils).to receive(:rm_rf).and_call_original
          allow(FileUtils).to receive(:rm)
          allow(FileUtils).to receive(:mv)
          allow(FileUtils).to receive(:cp_r)
          allow(Rake::Task).to receive(:[]).and_return(double(invoke: nil))
          allow(restore).to receive(:system).and_return(true)
          allow(PrerequisitesChecker).to receive(:new).and_return(double(check!: nil))
        end

        after do
          FileUtils.rm_rf(work_dir.to_s) if Dir.exist?(work_dir.to_s)
        end

        describe "#initialize" do
          it "sets snapshot path and work directory" do
            restore = described_class.new("snapshot.vocasnap", work_dir: work_dir)

            expect(restore.snapshot_path).to eq("snapshot.vocasnap")
            expect(restore.work_dir.to_s).to eq(work_dir)
          end

          it "uses default work directory when not provided" do
            allow(Rails).to receive(:root).and_return(Pathname.new("/app"))
            restore = described_class.new("snapshot.vocasnap")

            expect(restore.work_dir.to_s).to include("tmp/vocasnap-restore")
          end
        end

        describe "#execute" do
          before do
            allow(restore).to receive(:setup_directories)
            allow(restore).to receive(:download_snapshot)
            allow(restore).to receive(:decrypt_snapshot)
            allow(restore).to receive(:extract_archive)
            allow(restore).to receive(:validate_lockfile)
            allow(restore).to receive(:check_gitignore)
            allow(restore).to receive(:confirm_database_drop)
            allow(restore).to receive(:restore_database)
            allow(restore).to receive(:restore_storage)
            allow(restore).to receive(:run_migrations)
            allow(restore).to receive(:anonymize_if_test)
            allow(restore).to receive(:install_dependencies)
            allow(restore).to receive(:precompile_assets)
            allow(restore).to receive(:cleanup)
            allow(restore).to receive(:display_completion_message)
          end

          it "calls all required steps in order" do
            allow(restore).to receive(:remote_path?).and_return(false)
            allow(Rails.application).to receive(:respond_to?).with(:load_tasks).and_return(true)
            allow(Rails.application).to receive(:load_tasks)
            expect(restore).to receive(:setup_directories).ordered
            expect(restore).not_to receive(:download_snapshot)
            expect(restore).to receive(:decrypt_snapshot).with(password).ordered
            expect(restore).to receive(:extract_archive).ordered
            expect(restore).to receive(:validate_lockfile).ordered
            expect(restore).to receive(:check_gitignore).ordered
            expect(restore).to receive(:check_prerequisites).ordered
            expect(restore).to receive(:confirm_database_drop).ordered
            expect(restore).to receive(:restore_database).ordered
            expect(restore).to receive(:restore_storage).ordered
            expect(restore).to receive(:run_migrations).ordered
            expect(restore).to receive(:anonymize_if_test).with(false).ordered
            expect(restore).to receive(:install_dependencies).ordered
            expect(restore).to receive(:precompile_assets).ordered
            expect(restore).to receive(:cleanup).ordered
            expect(restore).to receive(:display_completion_message).ordered

            restore.execute(password: password, is_test_instance: false)
          end

        end

        describe "#remote_path?" do
          it "returns true for http URLs" do
            restore = described_class.new("http://example.com/snapshot.vocasnap")
            expect(restore.send(:remote_path?)).to be true
          end

          it "returns true for https URLs" do
            restore = described_class.new("https://example.com/snapshot.vocasnap")
            expect(restore.send(:remote_path?)).to be true
          end

          it "returns false for local paths" do
            restore = described_class.new("/local/path/snapshot.vocasnap")
            expect(restore.send(:remote_path?)).to be false
          end
        end

        describe "#download_snapshot" do
          let(:remote_url) { "https://example.com/snapshot.vocasnap" }
          let(:restore) { described_class.new(remote_url, work_dir: work_dir) }

          before do
            allow(restore).to receive(:remote_path?).and_return(true)
            file_double = double(read: "snapshot content")
            allow(URI).to receive(:open).with(remote_url).and_yield(file_double)
            file_handle = double(write: nil)
            allow(File).to receive(:open).with(anything, "wb").and_yield(file_handle)
          end

          it "downloads the snapshot file" do
            expect(URI).to receive(:open).with(remote_url)
            restore.send(:download_snapshot)
          end

          it "updates snapshot_path to local file" do
            restore.send(:download_snapshot)
            expect(restore.snapshot_path).to include("snapshot.vocasnap")
            expect(restore.snapshot_path).not_to eq(remote_url)
          end
        end

        describe "#decrypt_snapshot" do
          before do
            allow(Encryption).to receive(:decrypt_file)
          end

          it "decrypts the snapshot file" do
            encrypted_path = snapshot_path
            decrypted_path = File.join(work_dir, "snapshot.tar.gz")

            expect(Encryption).to receive(:decrypt_file).with(
              encrypted_path,
              decrypted_path,
              password
            )

            restore.send(:decrypt_snapshot, password)
          end
        end

        describe "#extract_archive" do
          before do
            allow(FileUtils).to receive(:cd).and_yield
            allow(restore).to receive(:system).and_return(true)
          end

          it "extracts the tar archive" do
            expect(restore).to receive(:system).with(
              "tar", "-xzf", snapshot_path
            ).and_return(true)

            restore.send(:extract_archive)
          end

          it "raises error if extraction fails" do
            allow(restore).to receive(:system).and_return(false)

            expect { restore.send(:extract_archive) }.to raise_error("Archive extraction failed")
          end
        end

        describe "#validate_lockfile" do
          let(:lockfile_path) { File.join(work_dir, "vocasnap.lockfile") }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(lockfile_path).and_return(true)
            allow(Lockfile).to receive(:validate).and_return(true)
            allow(Lockfile).to receive(:extract_decidim_modules).and_return({})
            allow(restore).to receive(:extract_snapshot_modules).and_return({})
            allow(restore).to receive(:find_missing_modules).and_return([])
          end

          it "validates the lockfile" do
            expect(Lockfile).to receive(:validate).with(lockfile_path)
            restore.send(:validate_lockfile)
          end

          context "when validation fails" do
            before do
              allow(Lockfile).to receive(:validate).and_return(false)
              allow(Lockfile).to receive(:extract_decidim_modules).and_return({})
              allow(restore).to receive(:extract_snapshot_modules).and_return({})
              allow(restore).to receive(:find_missing_modules).and_return([])
            end

            it "raises error with validation message" do
              expect { restore.send(:validate_lockfile) }.to raise_error(/Lockfile validation failed/)
            end
          end
        end

        describe "#check_gitignore" do
          let(:gitignore_path) { Rails.root.join(".gitignore") }

          before do
            allow(File).to receive(:exist?).with(gitignore_path).and_return(true)
            allow(File).to receive(:read).with(gitignore_path).and_return("node_modules\n")
          end

          context "when .gitignore doesn't exclude vocasnap files" do
            before do
              allow($stdin).to receive(:gets).and_return("y\n")
              allow(File).to receive(:open).and_yield(double(puts: nil))
            end

            it "asks to add *.vocasnap" do
              expect(File).to receive(:open).with(gitignore_path, "a")
              restore.send(:check_gitignore)
            end
          end

          context "when .gitignore already excludes vocasnap files" do
            before do
              allow(File).to receive(:read).with(gitignore_path).and_return("*.vocasnap\n")
            end

            it "does not ask to add it" do
              expect(File).not_to receive(:open)
              restore.send(:check_gitignore)
            end
          end
        end

        describe "#check_prerequisites" do
          let(:prerequisites_checker) { instance_double(PrerequisitesChecker) }

          before do
            allow(PrerequisitesChecker).to receive(:new).and_return(prerequisites_checker)
            allow(prerequisites_checker).to receive(:check!)
          end

          it "creates a PrerequisitesChecker instance" do
            expect(PrerequisitesChecker).to receive(:new).and_return(prerequisites_checker)
            restore.send(:check_prerequisites)
          end

          it "calls check! on the PrerequisitesChecker" do
            expect(prerequisites_checker).to receive(:check!)
            restore.send(:check_prerequisites)
          end
        end

        describe "#restore_database" do
          let(:dump_path) { Pathname.new(File.join(work_dir, "dump.sql")) }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(dump_path).and_return(true)
            allow(restore).to receive(:system).and_return(true)
            allow(restore).to receive(:replace_hosts_in_dump).and_return(dump_path)
            allow(restore).to receive(:get_db_config_without_connection).and_return(db_config)
            allow(restore).to receive(:restore_from_sql_dump)
            allow(restore).to receive(:disconnect_active_record)
            allow(restore).to receive(:reconnect_active_record)
          end

          it "creates the database" do
            expect(restore).to receive(:system).with("bundle exec rails db:create", exception: true)

            restore.send(:restore_database)
          end

          it "calls restore_from_sql_dump with correct parameters" do
            sql_dump_path = dump_path
            allow(restore).to receive(:replace_hosts_in_dump).and_return(sql_dump_path)
            expect(restore).to receive(:restore_from_sql_dump).with(db_config, sql_dump_path)

            restore.send(:restore_database)
          end

          it "raises error if dump file doesn't exist" do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(dump_path).and_return(false)

            expect { restore.send(:restore_database) }.to raise_error("Database dump not found in snapshot")
          end
        end

        describe "#restore_storage" do
          let(:storage_snapshot) { File.join(work_dir, "storage") }
          let(:storage_target) { Rails.root.join("storage") }

          context "when storage snapshot exists" do
            before do
              allow(Dir).to receive(:exist?).and_call_original
              allow(Dir).to receive(:exist?).with(storage_snapshot.to_s).and_return(true)
              allow(Dir).to receive(:exist?).with(storage_target.to_s).and_return(true)
            end

            it "removes existing storage and moves snapshot" do
              expect(FileUtils).to receive(:rm_rf).with(storage_target.to_s)
              expect(FileUtils).to receive(:mv).with(storage_snapshot.to_s, storage_target.to_s)

              restore.send(:restore_storage)
            end
          end

          context "when storage snapshot doesn't exist" do
            before do
              allow(Dir).to receive(:exist?).and_call_original
              allow(Dir).to receive(:exist?).with(storage_snapshot.to_s).and_return(false)
            end

            it "does nothing" do
              expect(FileUtils).not_to receive(:rm_rf).with(storage_target.to_s)
              expect(FileUtils).not_to receive(:mv).with(storage_snapshot.to_s, storage_target.to_s)
              # Allow cleanup calls
              allow(FileUtils).to receive(:rm_rf).and_call_original

              restore.send(:restore_storage)
            end
          end
        end

        describe "#run_migrations" do
          before do
            allow(Rake::Task).to receive(:[]).with("db:migrate").and_return(double(invoke: nil))
            allow(Open3).to receive(:capture2).and_return(["", double(success?: true)])
          end

          it "runs database migrations" do
            migrate_task = double(invoke: nil)
            expect(Rake::Task).to receive(:[]).with("db:migrate").and_return(migrate_task)
            expect(migrate_task).to receive(:invoke)

            restore.send(:run_migrations)
          end

          it "checks migration status" do
            status_output = double(include?: false)
            expect(Open3).to receive(:capture2).with("bundle exec rails db:migrate:status 2>&1").and_return([status_output, double(success?: true)])

            restore.send(:run_migrations)
          end
        end

        describe "#anonymize_if_test" do
          context "when is_test_instance is true" do
            before do
              allow(restore).to receive(:system).and_return(true)
            end

            it "runs anonymization" do
              expect(restore).to receive(:system).with("bundle exec rails decidim:voca:anonymize", exception: true)

              restore.send(:anonymize_if_test, true)
            end
          end

          context "when is_test_instance is false" do
            it "does nothing" do
              expect(restore).not_to receive(:system)
              restore.send(:anonymize_if_test, false)
            end
          end
        end

        describe "#install_dependencies" do
          it "runs npm install" do
            expect(restore).to receive(:system).with("npm install", exception: true)

            restore.send(:install_dependencies)
          end

          it "raises error if npm install fails" do
            expect(restore).to receive(:system).with("npm install", exception: true).and_raise(StandardError.new("npm install failed"))

            expect { restore.send(:install_dependencies) }.to raise_error("npm install failed")
          end
        end

        describe "#precompile_assets" do
          it "runs assets precompilation" do
            precompile_task = double(invoke: nil)
            expect(Rake::Task).to receive(:[]).with("assets:precompile").and_return(precompile_task)
            expect(precompile_task).to receive(:invoke)
            packs_dir = Rails.root.join("public", "decidim-packs")
            backup_dir = Rails.root.join("public", "decidim-packs.bak")
            allow(Dir).to receive(:exist?).and_call_original
            allow(Dir).to receive(:exist?).with(packs_dir.to_s).and_return(false, true)
            allow(Dir).to receive(:exist?).with(backup_dir.to_s).and_return(false)

            restore.send(:precompile_assets)
          end
        end

        describe "#cleanup" do
          it "removes work directory" do
            expect(FileUtils).to receive(:rm_rf).with(restore.work_dir.to_s)

            restore.send(:cleanup)
          end
        end
      end
    end
  end
end

