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
            expect(data["decidim_modules"]["decidim-core"]).to eq({ "version" => "0.29.0" })
            expect(data["npm_lock"]).to eq("npm lock content")
          end
        end

        describe ".validate" do
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

          context "when lockfile doesn't match" do
            before do
              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => "npm content"
              }.to_json)
            end

            it "returns false" do
              allow(described_class).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.30.0" }
              )
              allow(described_class).to receive(:read_npm_lock).and_return("npm content")
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

          it "extracts decidim modules with versions from Gemfile.lock" do
            modules = described_class.extract_decidim_modules
            expect(modules).to include(
              "decidim-core" => { "version" => "0.29.0" },
              "decidim-proposals" => { "version" => "0.29.0" },
              "decidim-voca" => { "version" => "0.1.0" }
            )
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
        end
      end
    end
  end
end
