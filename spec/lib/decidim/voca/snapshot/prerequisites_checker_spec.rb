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

          it "checks psql availability" do
            expect(checker).to receive(:check_psql_available!)
            checker.check!
          end

          it "checks PostgreSQL version compatibility" do
            expect(checker).to receive(:check_postgresql_version_compatibility!)
            checker.check!
          end
        end

        describe "#check_psql_available!" do
          context "when psql is available" do
            before do
              allow(checker).to receive(:system).with("which", "psql", out: File::NULL, err: File::NULL).and_return(true)
            end

            it "does not raise an error" do
              expect { checker.send(:check_psql_available!) }.not_to raise_error
            end
          end

          context "when psql is not available" do
            before do
              allow(checker).to receive(:system).with("which", "psql", out: File::NULL, err: File::NULL).and_return(false)
              allow(checker).to receive(:detect_os).and_return({ type: :unknown })
              allow(checker).to receive(:postgresql_server_version).and_return("16.11")
            end

            it "raises an error" do
              expect { checker.send(:check_psql_available!) }.to raise_error(/Missing required binary: psql/)
            end
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

          context "when version query returns empty result" do
            before do
              allow(connection).to receive(:execute).with("SELECT version();").and_return([])
            end

            it "returns nil" do
              expect(checker.postgresql_server_version).to be_nil
            end
          end

          context "when database connection fails" do
            before do
              allow(connection).to receive(:execute).and_raise(StandardError.new("Connection failed"))
            end

            it "returns nil" do
              expect(checker.postgresql_server_version).to be_nil
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

          context "when psql command fails" do
            let(:status) { double(success?: false) }

            before do
              allow(Open3).to receive(:capture2).with("psql --version 2>&1").and_return(["command not found", status])
            end

            it "returns nil" do
              expect(checker.psql_version).to be_nil
            end
          end
        end

        describe "#check_postgresql_version_compatibility!" do
          before do
            allow(checker).to receive(:postgresql_server_version).and_return("14.5")
            allow(checker).to receive(:psql_version).and_return("14.5")
          end

          context "when versions are compatible" do
            it "does not raise an error" do
              expect { checker.send(:check_postgresql_version_compatibility!) }.not_to raise_error
            end
          end

          context "when client version is newer than server" do
            before do
              allow(checker).to receive(:psql_version).and_return("15.0")
            end

            it "does not raise an error" do
              expect { checker.send(:check_postgresql_version_compatibility!) }.not_to raise_error
            end
          end

          context "when client version is older than server" do
            before do
              allow(checker).to receive(:postgresql_server_version).and_return("15.0")
              allow(checker).to receive(:psql_version).and_return("14.5")
              allow(checker).to receive(:upgrade_psql_hint).and_return("Upgrade instructions")
            end

            it "raises an error with upgrade hint" do
              expect(checker).to receive(:upgrade_psql_hint).with(15).and_return("Upgrade instructions")
              expect { checker.send(:check_postgresql_version_compatibility!) }.to raise_error(/Version mismatch/)
            end
          end

          context "when server version is nil" do
            before do
              allow(checker).to receive(:postgresql_server_version).and_return(nil)
            end

            it "does not raise an error" do
              expect { checker.send(:check_postgresql_version_compatibility!) }.not_to raise_error
            end
          end

          context "when client version is nil" do
            before do
              allow(checker).to receive(:psql_version).and_return(nil)
            end

            it "does not raise an error" do
              expect { checker.send(:check_postgresql_version_compatibility!) }.not_to raise_error
            end
          end
        end

        describe "#detect_os" do
          context "on Linux systems" do
            context "on Debian-based systems" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
                allow(File).to receive(:readlines).with("/etc/os-release").and_return([
                  'ID=ubuntu',
                  'VERSION_CODENAME=jammy'
                ])
              end

              it "returns debian type" do
                expect(checker.detect_os).to eq({ type: :debian, id: "ubuntu" })
              end
            end

            context "on Fedora" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
                allow(File).to receive(:readlines).with("/etc/os-release").and_return([
                  'ID=fedora'
                ])
              end

              it "returns fedora type" do
                expect(checker.detect_os).to eq({ type: :fedora, id: "fedora" })
              end
            end

            context "on RHEL/CentOS" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
                allow(File).to receive(:readlines).with("/etc/os-release").and_return([
                  'ID=centos'
                ])
              end

              it "returns rhel type" do
                expect(checker.detect_os).to eq({ type: :rhel, id: "centos" })
              end
            end

            context "on Arch Linux" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
                allow(File).to receive(:readlines).with("/etc/os-release").and_return([
                  'ID=arch'
                ])
              end

              it "returns arch type" do
                expect(checker.detect_os).to eq({ type: :arch, id: "arch" })
              end
            end

            context "on Alpine Linux" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(true)
                allow(File).to receive(:readlines).with("/etc/os-release").and_return([
                  'ID=alpine'
                ])
              end

              it "returns alpine type" do
                expect(checker.detect_os).to eq({ type: :alpine, id: "alpine" })
              end
            end

            context "when os-release doesn't exist" do
              before do
                allow(File).to receive(:exist?).with("/etc/os-release").and_return(false)
              end

              it "returns unknown type" do
                expect(checker.detect_os).to eq({ type: :unknown })
              end
            end
          end
        end

        describe "#upgrade_psql_hint" do
          context "for Debian-based systems" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :debian })
            end

            it "returns Debian upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("apt-get install -y postgresql-client-14")
              expect(hint).to include("apt.postgresql.org")
            end
          end

          context "for Fedora" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :fedora })
            end

            it "returns Fedora upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("dnf install -y postgresql14")
            end
          end

          context "for RHEL/CentOS" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :rhel })
            end

            it "returns RHEL upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("yum install -y postgresql14")
            end
          end

          context "for Arch Linux" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :arch })
            end

            it "returns Arch upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("pacman -Syu postgresql")
            end
          end

          context "for Alpine Linux" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :alpine })
            end

            it "returns Alpine upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("apk add postgresql14-client")
            end
          end

          context "for unknown OS" do
            before do
              allow(checker).to receive(:detect_os).and_return({ type: :unknown })
            end

            it "returns generic upgrade instructions" do
              hint = checker.upgrade_psql_hint(14)
              expect(hint).to include("Upgrade psql to PostgreSQL 14")
              expect(hint).to include("package manager")
            end
          end
        end
      end
    end
  end
end

