# frozen_string_literal: true

require "spec_helper"
require "decidim/voca/snapshot"

module Decidim
  module Voca
    module Snapshot
      describe PrerequisitesChecker do
        let(:checker) { described_class.new }
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
          allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(
            double(configuration_hash: db_config)
          )
        end

        describe "#check!" do
          before do
            allow(checker).to receive(:check_psql_available!)
            allow(checker).to receive(:check_postgresql_version_compatibility!)
          end

          it "checks all prerequisites" do
            checker.check!
            expect(checker).to have_received(:check_psql_available!)
            expect(checker).to have_received(:check_postgresql_version_compatibility!)
          end
        end

        describe "#check_psql_available!" do
          it "does not raise when psql is available" do
            allow(checker).to receive(:system).with("which", "psql", out: File::NULL, err: File::NULL).and_return(true)
            expect { checker.send(:check_psql_available!) }.not_to raise_error
          end

          it "raises when psql is not available" do
            allow(checker).to receive(:system).with("which", "psql", out: File::NULL, err: File::NULL).and_return(false)
            allow(checker).to receive(:detect_os).and_return({ type: :unknown })
            expect { checker.send(:check_psql_available!) }.to raise_error(/Missing required binary: psql/)
          end
        end

        describe "#postgresql_server_version" do
          let(:connection) { double(execute: nil) }

          before do
            allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
          end

          context "when version query succeeds" do
            let(:version_result) do
              [
                { "version" => "PostgreSQL 14.5 on x86_64-pc-linux-gnu" }
              ]
            end

            before do
              allow(connection).to receive(:execute).with("SELECT version();").and_return(version_result)
            end

            it "returns the PostgreSQL version" do
              expect(checker.postgresql_server_version).to eq("14.5")
            end
          end
        end

        describe "#psql_version" do
          context "when psql is available" do
            let(:status) { double(success?: true) }

            before do
              allow(Open3).to receive(:capture2).with("psql --version 2>&1").and_return(["psql (PostgreSQL) 14.5\n", status])
            end

            it "returns the version" do
              expect(checker.psql_version).to eq("14.5")
            end
          end
        end

        describe "#check_postgresql_version_compatibility!" do
          it "does not raise when versions are compatible" do
            allow(checker).to receive(:postgresql_server_version).and_return("14.5")
            allow(checker).to receive(:psql_version).and_return("14.5")
            expect { checker.send(:check_postgresql_version_compatibility!) }.not_to raise_error
          end

          it "raises when client is older than server" do
            allow(checker).to receive(:postgresql_server_version).and_return("15.0")
            allow(checker).to receive(:psql_version).and_return("14.5")
            allow(checker).to receive(:upgrade_psql_hint).and_return("Upgrade instructions")
            expect { checker.send(:check_postgresql_version_compatibility!) }.to raise_error(/Version mismatch/)
          end
        end

        describe "#detect_os" do
          it "detects common Linux distributions" do
            allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
            allow(File).to receive(:readlines).with("/etc/os-release").and_return(["ID=ubuntu"])
            expect(checker.detect_os).to eq({ type: :debian, id: "ubuntu" })
          end
        end
      end
    end
  end
end
