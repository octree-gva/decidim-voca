# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "json"
require "decidim/voca/snapshot"

module Decidim
  module Voca
    module Snapshot
      describe Lockfile do
        let(:temp_dir) { Dir.mktmpdir }
        let(:lockfile_path) { File.join(temp_dir, "vocasnap.lockfile") }

        after do
          FileUtils.rm_rf(temp_dir)
        end

        describe ".generate" do
          before do
            allow(described_class).to receive(:extract_decidim_modules).and_return(
              "decidim-core" => { version: "0.29.0" },
              "decidim-proposals" => { version: "0.29.0" }
            )
            allow(described_class).to receive(:read_npm_lock).and_return("npm lock content")
          end

          it "creates a lockfile with module and npm information" do
            described_class.generate(lockfile_path)

            expect(File.exist?(lockfile_path)).to be true
            data = JSON.parse(File.read(lockfile_path))
            expect(data["decidim_modules"]).to be_a(Hash)
            expect(data["npm_lock"]).to eq("npm lock content")
          end

          it "includes decidim modules in the lockfile" do
            described_class.generate(lockfile_path)

            data = JSON.parse(File.read(lockfile_path))
            expect(data["decidim_modules"]["decidim-core"]).to eq({ "version" => "0.29.0" })
          end
        end

        describe ".validate" do
          context "when lockfile does not exist" do
            it "returns false" do
              expect(described_class.validate("/nonexistent/path")).to be false
            end
          end

          context "when lockfile exists and matches" do
            before do
              allow(described_class).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" }
              )
              allow(described_class).to receive(:read_npm_lock).and_return("npm content")

              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => "npm content"
              }.to_json)
            end

            it "returns true" do
              expect(described_class.validate(lockfile_path)).to be true
            end
          end

          context "when lockfile exists but modules don't match" do
            before do
              allow(described_class).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.30.0" }
              )
              allow(described_class).to receive(:read_npm_lock).and_return("npm content")

              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => "npm content"
              }.to_json)
            end

            it "returns false" do
              expect(described_class.validate(lockfile_path)).to be false
            end
          end

          context "when lockfile exists but npm lock doesn't match" do
            before do
              allow(described_class).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" }
              )
              allow(described_class).to receive(:read_npm_lock).and_return("different npm content")

              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => "npm content"
              }.to_json)
            end

            it "returns false" do
              expect(described_class.validate(lockfile_path)).to be false
            end
          end
        end

        describe ".extract_decidim_modules" do
          let(:gemfile_lock_content) do
            <<~LOCKFILE
              GEM
                remote: https://rubygems.org/
                specs:
                  decidim-core (0.29.0)
                  decidim-proposals (0.29.0)
                  decidim-voca (0.1.0)
            LOCKFILE
          end

          before do
            allow(Rails).to receive(:root).and_return(Pathname.new(temp_dir))
            gemfile_lock_path = File.join(temp_dir, "Gemfile.lock")
            File.write(gemfile_lock_path, gemfile_lock_content)
          end

          it "extracts decidim modules from Gemfile.lock" do
            modules = described_class.extract_decidim_modules
            expect(modules).to have_key("decidim-core")
            expect(modules).to have_key("decidim-proposals")
            expect(modules).to have_key("decidim-voca")
          end

          it "includes version information" do
            modules = described_class.extract_decidim_modules
            expect(modules["decidim-core"]["version"]).to eq("0.29.0")
          end
        end

        describe ".read_npm_lock" do
          context "when package-lock.json exists" do
            before do
              allow(Rails).to receive(:root).and_return(Pathname.new(temp_dir))
              npm_lock_path = File.join(temp_dir, "package-lock.json")
              File.write(npm_lock_path, "npm lock file content")
            end

            it "returns the content of package-lock.json" do
              expect(described_class.read_npm_lock).to eq("npm lock file content")
            end
          end

          context "when package-lock.json does not exist" do
            let(:npm_lock_path) { File.join(temp_dir, "package-lock.json") }

            before do
              allow(Rails).to receive(:root).and_return(Pathname.new(temp_dir))
              # Ensure package-lock.json doesn't exist
              File.delete(npm_lock_path) if File.exist?(npm_lock_path)
              File.write(File.join(temp_dir, "package.json"), "{\"dependencies\": {}}")
            end

            it "runs npm install" do
              File.delete(npm_lock_path) if File.exist?(npm_lock_path)
              
              allow(Kernel).to receive(:system).with("npm install", chdir: temp_dir.to_s) do
                File.write(npm_lock_path, '{"packages": {}}')
                true
              end
             
              described_class.read_npm_lock
              
              expect(File.exist?(npm_lock_path)).to be true
            end
          end
        end
      end
    end
  end
end
