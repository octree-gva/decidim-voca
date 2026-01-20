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
        let(:restore) { described_class.new(snapshot_path, work_dir:) }
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
          FileUtils.rm_rf(work_dir.to_s)
        end

        describe "#initialize" do
          it "sets snapshot path and work directory" do
            restore = described_class.new("snapshot.vocasnap", work_dir:)
            expect(restore.snapshot_path).to eq("snapshot.vocasnap")
            expect(restore.work_dir.to_s).to eq(work_dir)
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
            allow(restore).to receive(:check_prerequisites)
            allow(restore).to receive(:confirm_database_drop)
            allow(restore).to receive(:restore_database)
            allow(restore).to receive(:migrate_active_storage_to_local)
            allow(restore).to receive(:restore_storage)
            allow(restore).to receive(:run_migrations)
            allow(restore).to receive(:anonymize_if_test)
            allow(restore).to receive(:install_dependencies)
            allow(restore).to receive(:precompile_assets)
            allow(restore).to receive(:cleanup)
            allow(restore).to receive(:display_completion_message)
            allow(restore).to receive(:remote_path?).and_return(false)
            allow(Rails.application).to receive(:respond_to?).with(:load_tasks).and_return(true)
            allow(Rails.application).to receive(:load_tasks)
          end

          it "executes all required steps" do
            restore.execute(password:, is_test_instance: false)

            expect(restore).to have_received(:setup_directories)
            expect(restore).to have_received(:decrypt_snapshot).with(password)
            expect(restore).to have_received(:extract_archive)
            expect(restore).to have_received(:validate_lockfile)
            expect(restore).to have_received(:restore_database)
            expect(restore).not_to have_received(:download_snapshot)
          end
        end

        describe "#decrypt_snapshot" do
          before do
            allow(Encryption).to receive(:decrypt_file)
          end

          it "decrypts the snapshot file" do
            restore.send(:decrypt_snapshot, password)
            expect(Encryption).to have_received(:decrypt_file).with(
              snapshot_path,
              File.join(work_dir, "snapshot.tar.gz"),
              password
            )
          end
        end

        describe "#extract_archive" do
          before do
            allow(FileUtils).to receive(:cd).and_yield
            allow(restore).to receive(:system).and_return(true)
          end

          it "extracts the tar archive" do
            restore.send(:extract_archive)
            expect(restore).to have_received(:system).with("tar", "-xzf", snapshot_path)
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
            restore.send(:validate_lockfile)
            expect(Lockfile).to have_received(:validate).with(lockfile_path)
          end

          context "when validation fails" do
            before do
              allow(Lockfile).to receive(:validate).and_return(false)
              allow(Lockfile).to receive(:extract_decidim_modules).and_return({})
              allow(restore).to receive(:extract_snapshot_modules).and_return({})
              allow(restore).to receive(:find_missing_modules).and_return([])
            end

            it "raises an error" do
              expect { restore.send(:validate_lockfile) }.to raise_error(/Lockfile validation failed/)
            end
          end
        end

        describe "#restore_database" do
          let(:dump_path) { Pathname.new(File.join(work_dir, "dump.sql")) }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(dump_path).and_return(true)
            allow(restore).to receive(:system).and_return(true)
            allow(restore).to receive(:replace_hosts_in_dump).and_return(dump_path)
            allow(restore).to receive(:db_config_without_connection).and_return(db_config)
            allow(restore).to receive(:restore_from_sql_dump)
            allow(restore).to receive(:disconnect_active_record)
            allow(restore).to receive(:reconnect_active_record)
          end

          it "creates database and restores from dump" do
            restore.send(:restore_database)
            expect(restore).to have_received(:system).with("bundle exec rails db:create", exception: true)
            expect(restore).to have_received(:restore_from_sql_dump).with(db_config, dump_path)
          end

          it "raises error if dump file doesn't exist" do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(dump_path).and_return(false)

            expect { restore.send(:restore_database) }.to raise_error("Database dump not found in snapshot")
          end
        end

        describe "#migrate_active_storage_to_local" do
          let(:where_relation) { double("where_relation") }
          let(:not_relation) { double("not_relation") }
          let(:blob_class) { Class.new }
          let(:original_blob) { defined?(ActiveStorage::Blob) ? ActiveStorage::Blob : nil }

          before do
            allow(restore).to receive(:reconnect_active_record)
            # Create a stub class that responds to where
            allow(blob_class).to receive(:where).and_return(where_relation)
            allow(where_relation).to receive(:not).and_return(not_relation)
            # Replace ActiveStorage::Blob constant before the method runs
            if defined?(ActiveStorage)
              ActiveStorage.send(:remove_const, :Blob) if ActiveStorage.const_defined?(:Blob)
              ActiveStorage.const_set(:Blob, blob_class)
            end
          end

          after do
            # Restore original ActiveStorage::Blob to avoid side effects
            if defined?(ActiveStorage) && original_blob
              ActiveStorage.send(:remove_const, :Blob) if ActiveStorage.const_defined?(:Blob)
              ActiveStorage.const_set(:Blob, original_blob)
            elsif defined?(ActiveStorage) && !original_blob
              ActiveStorage.send(:remove_const, :Blob) if ActiveStorage.const_defined?(:Blob)
            end
          end

          it "migrates non-local blobs to local service" do
            allow(not_relation).to receive(:update_all).and_return(5)
            restore.send(:migrate_active_storage_to_local)
            expect(restore).to have_received(:reconnect_active_record)
            expect(where_relation).to have_received(:not).with(service_name: "local")
            expect(not_relation).to have_received(:update_all).with(service_name: "local")
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
              restore.send(:restore_storage)
              expect(FileUtils).to have_received(:rm_rf).with(storage_target.to_s)
              expect(FileUtils).to have_received(:mv).with(storage_snapshot.to_s, storage_target.to_s)
            end
          end
        end

        describe "#run_migrations" do
          let(:migrate_task) { double(invoke: nil) }

          before do
            allow(Rake::Task).to receive(:[]).with("db:migrate").and_return(migrate_task)
            allow(Open3).to receive(:capture2).and_return(["", double(success?: true)])
          end

          it "runs database migrations" do
            restore.send(:run_migrations)
            expect(migrate_task).to have_received(:invoke)
          end
        end
      end
    end
  end
end
