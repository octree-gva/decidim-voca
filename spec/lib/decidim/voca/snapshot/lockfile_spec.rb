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
        let(:validator) { described_class.validator }

        after do
          FileUtils.rm_rf(temp_dir)
        end

        describe "validator#generate" do
          let(:npm_lock_json) do
            {
              "packages" => {
                "" => { "dependencies" => { "lodash" => "4.17.21" } },
                "node_modules/lodash" => { "version" => "4.17.23" }
              }
            }.to_json
          end

          before do
            allow(validator).to receive(:extract_decidim_modules).and_return(
              "decidim-core" => { version: "0.29.0" },
              "decidim-proposals" => { version: "0.29.0" }
            )
            allow(validator).to receive(:read_npm_lock).and_return(npm_lock_json)
          end

          it "creates a lockfile with module and npm information" do
            validator.generate(lockfile_path)

            expect(File.exist?(lockfile_path)).to be true
            data = JSON.parse(File.read(lockfile_path))
            expect(data["decidim_modules"]).to be_a(Hash)
            expect(data["decidim_modules"]["decidim-core"]).to eq({ "version" => "0.29.0" })
            expect(data["npm_lock"]).to eq("lodash" => "4.17.21")
          end
        end

        describe "validator#validate" do
          context "when lockfile exists and matches" do
            let(:npm_lock_json) do
              {
                "packages" => {
                  "" => { "dependencies" => { "some-npm-pkg" => "1.0.0" } },
                  "node_modules/some-npm-pkg" => { "version" => "1.0.0" }
                }
              }.to_json
            end

            before do
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" }
              )
              allow(validator).to receive(:read_npm_lock).and_return(npm_lock_json)

              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => { "some-npm-pkg" => "1.0.0" }
              }.to_json)
            end

            it "returns false (no errors)" do
              expect(validator.validate(lockfile_path)).to be false
            end
          end

          context "when lockfile doesn't match" do
            before do
              File.write(lockfile_path, {
                "decidim_modules" => {
                  "decidim-core" => { "version" => "0.29.0" }
                },
                "npm_lock" => { "some-npm-pkg" => "1.0.0" }
              }.to_json)
            end

            it "returns true (has errors)" do
              allow(validator).to receive(:extract_decidim_modules).and_return({})
              allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)
              expect(validator.validate(lockfile_path)).to be true
            end
          end
        end

        describe "validator#errors" do
          context "when lockfile does not exist" do
            it "returns empty array" do
              expect(validator.errors(File.join(temp_dir, "nonexistent.lock"))).to eq([])
            end
          end

          context "when package-lock.json is missing but lockfile requires npm packages" do
            before do
              File.write(lockfile_path, {
                "decidim_modules" => {},
                "npm_lock" => { "lodash" => "4.17.21" }
              }.to_json)
              allow(validator).to receive(:extract_decidim_modules).and_return({})
              allow(validator).to receive(:read_npm_lock).and_return(nil)
            end

            it "returns a clear error asking to run npm install" do
              errs = validator.errors(lockfile_path)
              expect(errs.join("\n")).to match(/package-lock\.json not found/i)
              expect(errs.join("\n")).to match(/npm install/i)
            end
          end

          context "with dummy lockfile (symbol keys normalized)" do
            let(:npm_lock_with_lodash) do
              {
                "packages" => {
                  "" => { "dependencies" => { "lodash" => "4.17.21" } },
                  "node_modules/lodash" => { "version" => "4.17.21" }
                }
              }.to_json
            end

            before do
              File.write(lockfile_path, {
                decidim_modules: {
                  "decidim-core" => { "version" => "0.29.0" },
                  "decidim-proposals" => { "version" => "0.29.0" }
                },
                npm_lock: { "lodash" => "4.17.21" }
              }.to_json)
            end

            it "reports missing decidim modules when current has fewer" do
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" }
              )
              allow(validator).to receive(:read_npm_lock).and_return(npm_lock_with_lodash)

              errs = validator.errors(lockfile_path)
              expect(errs).to include(match(/Missing module decidim-proposals/))
            end

            it "reports missing npm packages when current has fewer" do
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" },
                "decidim-proposals" => { "version" => "0.29.0" }
              )
              allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

              errs = validator.errors(lockfile_path)
              expect(errs).to include(match(/Missing npm package lodash/))
            end

            it "returns no errors when current has all target modules and npm packages" do
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" },
                "decidim-proposals" => { "version" => "0.29.0" }
              )
              allow(validator).to receive(:read_npm_lock).and_return(npm_lock_with_lodash)

              expect(validator.errors(lockfile_path)).to eq([])
            end

            it "reports npm package version mismatch" do
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.0" },
                "decidim-proposals" => { "version" => "0.29.0" }
              )
              allow(validator).to receive(:read_npm_lock).and_return(
                {
                  "packages" => {
                    "" => { "dependencies" => { "lodash" => "4.17.20" } },
                    "node_modules/lodash" => { "version" => "4.17.20" }
                  }
                }.to_json
              )

              errs = validator.errors(lockfile_path)
              expect(errs).to include(match(/Version mismatch for npm package lodash: lockfile 4\.17\.21, current 4\.17\.20/))
            end

            it "reports version mismatch using semantic comparison (e.g. 0.29.2 vs 0.29.10)" do
              File.write(lockfile_path, {
                decidim_modules: { "decidim-core" => { "version" => "0.29.10" } },
                npm_lock: {}
              }.to_json)
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.2" }
              )
              allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

              errs = validator.errors(lockfile_path)
              expect(errs).to include(match(/Version mismatch for decidim-core: lockfile 0\.29\.10, current 0\.29\.2/))
            end

            it "does not report mismatch when versions are equal (0.29.10 == 0.29.10)" do
              File.write(lockfile_path, {
                decidim_modules: { "decidim-core" => { "version" => "0.29.10" } },
                npm_lock: {}
              }.to_json)
              allow(validator).to receive(:extract_decidim_modules).and_return(
                "decidim-core" => { "version" => "0.29.10" }
              )
              allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

              expect(validator.errors(lockfile_path)).to eq([])
            end
          end
        end

        describe "validator#validate!" do
          it "raises with joined errors when lockfile has missing modules" do
            File.write(lockfile_path, {
              "decidim_modules" => { "decidim-core" => { "version" => "0.29.0" } },
              "npm_lock" => {}
            }.to_json)
            allow(validator).to receive(:extract_decidim_modules).and_return({})
            allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

            expect { validator.validate!(lockfile_path) }.to raise_error(/Missing module decidim-core/)
          end

          it "raises when module exists but at wrong version" do
            File.write(lockfile_path, {
              "decidim_modules" => { "decidim-core" => { "version" => "0.29.10" } },
              "npm_lock" => {}
            }.to_json)
            allow(validator).to receive(:extract_decidim_modules).and_return(
              "decidim-core" => { "version" => "0.29.2" }
            )
            allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

            expect { validator.validate!(lockfile_path) }.to raise_error(/Version mismatch for decidim-core: lockfile 0\.29\.10, current 0\.29\.2/)
          end

          it "raises when lockfile has missing npm package" do
            File.write(lockfile_path, {
              "decidim_modules" => {},
              "npm_lock" => { "lodash" => "4.17.21" }
            }.to_json)
            allow(validator).to receive(:extract_decidim_modules).and_return({})
            allow(validator).to receive(:read_npm_lock).and_return({ "packages" => {} }.to_json)

            expect { validator.validate!(lockfile_path) }.to raise_error(/Missing npm package lodash/)
          end

          it "raises when npm package exists but at wrong version" do
            File.write(lockfile_path, {
              "decidim_modules" => {},
              "npm_lock" => { "lodash" => "4.17.21" }
            }.to_json)
            allow(validator).to receive(:extract_decidim_modules).and_return({})
            allow(validator).to receive(:read_npm_lock).and_return(
              {
                "packages" => {
                  "" => { "dependencies" => { "lodash" => "4.17.20" } },
                  "node_modules/lodash" => { "version" => "4.17.20" }
                }
              }.to_json
            )

            expect { validator.validate!(lockfile_path) }.to raise_error(/Version mismatch for npm package lodash: lockfile 4\.17\.21, current 4\.17\.20/)
          end
        end

        describe "validator#normalize_hash" do
          it "stringifies keys and recursively normalizes nested hashes" do
            input = { foo: "a", bar: { baz: "b" } }
            expect(validator.normalize_hash(input)).to eq(
              "foo" => "a", "bar" => { "baz" => "b" }
            )
          end

          it "returns non-hash unchanged" do
            expect(validator.normalize_hash("string")).to eq("string")
            expect(validator.normalize_hash(nil)).to be_nil
          end
        end

        describe "validator#extract_decidim_modules" do
          # Realistic slice from a Gemfile.lock (e.g. decidim-toggle), with PATH + GEM and decidim specs
          let(:gemfile_lock_content) do
            <<~LOCKFILE
              GIT
                remote: https://git.octree.ch/decidim/decidim-module-geo
                revision: a9ad70e5221bbc5019589e6bd48aa38c2526fdaf
                tag: v0.3.7
                specs:
                  decidim-decidim_geo (0.3.7)
                    activerecord-postgis-adapter
                    decidim-admin (>= 0.29)
                    decidim-api (>= 0.29)
                    decidim-core (>= 0.29)
                    deface (~> 1.9.0)
                    ffi-geos (~> 2.5)
                    rgeo (~> 3.0)
                    rgeo-geojson (~> 2.2)
                    rgeo-shapefile (~> 3.1)

              GIT
                remote: https://git.octree.ch/decidim/decidim-module-spam_signal
                revision: 669ad0f2ee12e0ca7ed01e5e36e280baf347f5e1
                tag: v1.0.6
                specs:
                  decidim-spam_signal (1.0.6)
                    decidim-admin (>= 0.27, < 0.30)
                    decidim-comments (>= 0.27, < 0.30)
                    decidim-core (>= 0.27, < 0.30)
                    decidim-forms (>= 0.27, < 0.30)
                    deface (~> 1.9)

              PATH
                remote: .
                specs:
                  decidim-toggle (0.1.0)
                    decidim-core (>= 0.29, < 0.30)
                    decidim-system (>= 0.29, < 0.30)
                    deface (>= 1.5)

              GEM
                remote: https://rubygems.org/
                specs:
                  decidim-core (0.29.1)
                    active_link_to (~> 1.0)
                    acts_as_list (~> 1.0)
                  decidim-admin (0.29.1)
                    active_link_to (~> 1.0)
                    decidim-core (= 0.29.1)
                  decidim-proposals (0.29.1)
                    decidim-comments (= 0.29.1)
                    decidim-core (= 0.29.1)
                  decidim-system (0.29.1)
                    decidim-core (= 0.29.1)
            LOCKFILE
          end

          before do
            allow(Rails).to receive(:root).and_return(Pathname.new(temp_dir))
            gemfile_lock_path = File.join(temp_dir, "Gemfile.lock")
            File.write(gemfile_lock_path, gemfile_lock_content)
          end

          it "extracts decidim modules with versions from Gemfile.lock (PATH, GEM, GIT)" do
            modules = validator.extract_decidim_modules
            expect(modules).to include(
              "decidim-decidim_geo" => { "version" => "0.3.7" },
              "decidim-spam_signal" => { "version" => "1.0.6" },
              "decidim-toggle" => { "version" => "0.1.0" },
              "decidim-core" => { "version" => "0.29.1" },
              "decidim-admin" => { "version" => "0.29.1" },
              "decidim-proposals" => { "version" => "0.29.1" },
              "decidim-system" => { "version" => "0.29.1" }
            )
            expect(modules.size).to eq(7)
          end
        end

        describe "validator#read_npm_lock" do
          context "when package-lock.json exists" do
            before do
              allow(Rails).to receive(:root).and_return(Pathname.new(temp_dir))
              npm_lock_path = File.join(temp_dir, "package-lock.json")
              File.write(npm_lock_path, "npm lock file content")
            end

            it "returns the content of package-lock.json" do
              expect(validator.read_npm_lock).to eq("npm lock file content")
            end
          end
        end

        describe "validator#extract_npm_packages" do
          it "returns empty hash for nil or empty content" do
            expect(validator.extract_npm_packages(nil)).to eq({})
            expect(validator.extract_npm_packages("")).to eq({})
          end

          it "extracts only root dependencies (names and versions) from package-lock v3" do
            package_lock = {
              "lockfileVersion" => 3,
              "packages" => {
                "" => {
                  "name" => "my-app",
                  "version" => "1.0.0",
                  "dependencies" => { "lodash" => "^4.17.0", "@babel/core" => "^7.28.0" }
                },
                "node_modules/lodash" => { "version" => "4.17.21" },
                "node_modules/@babel/core" => { "version" => "7.28.0" }
              }
            }.to_json

            result = validator.extract_npm_packages(package_lock)
            expect(result).to eq("lodash" => "4.17.21", "@babel/core" => "7.28.0")
          end

          it "skips file: deps and ignores devDependencies" do
            package_lock = {
              "lockfileVersion" => 3,
              "packages" => {
                "" => {
                  "name" => "decidim-ocsin-app",
                  "version" => "0.1.0",
                  "dependencies" => {
                    "@decidim/browserslist-config" => "file:packages/browserslist-config",
                    "@decidim/core" => "file:packages/core",
                    "codemirror" => "^5.65.20",
                    "form-storage" => "^1.3.5",
                    "tom-select" => "^2.2.2"
                  },
                  "devDependencies" => {
                    "@decidim/dev" => "file:packages/dev",
                    "@openapitools/openapi-generator-cli" => "^2.21.0"
                  }
                },
                "node_modules/codemirror" => { "version" => "5.65.20" },
                "node_modules/form-storage" => { "version" => "1.3.5" },
                "node_modules/tom-select" => { "version" => "2.2.2" }
              }
            }.to_json

            result = validator.extract_npm_packages(package_lock)
            expect(result).to eq("codemirror" => "5.65.20", "form-storage" => "1.3.5", "tom-select" => "2.2.2")
          end
        end
      end
    end
  end
end
