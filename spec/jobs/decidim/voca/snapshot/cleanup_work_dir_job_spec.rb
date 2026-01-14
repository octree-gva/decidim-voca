# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    module Snapshot
      describe CleanupWorkDirJob do
        describe "#perform" do
          context "when work_dir_path is nil" do
            it "returns early without raising an error" do
              expect { described_class.new.perform(nil) }.not_to raise_error
            end
          end

          context "when work_dir_path is provided but directory does not exist" do
            it "returns early without raising an error" do
              non_existent_path = "/tmp/non_existent_directory_#{SecureRandom.hex}"
              expect { described_class.new.perform(non_existent_path) }.not_to raise_error
            end
          end

          context "when work_dir_path is provided and directory exists" do
            let(:work_dir) { Dir.mktmpdir("cleanup_test") }

            after do
              FileUtils.rm_rf(work_dir) if File.exist?(work_dir)
            end

            it "removes the directory" do
              expect(Pathname.new(work_dir).exist?).to be true

              described_class.new.perform(work_dir)

              expect(Pathname.new(work_dir).exist?).to be false
            end

            it "removes nested files and directories recursively" do
              nested_file = File.join(work_dir, "nested", "file.txt")
              FileUtils.mkdir_p(File.dirname(nested_file))
              File.write(nested_file, "test content")

              expect(File.exist?(nested_file)).to be true

              described_class.new.perform(work_dir)

              expect(Pathname.new(work_dir).exist?).to be false
              expect(File.exist?(nested_file)).to be false
            end
          end
        end
      end
    end
  end
end

