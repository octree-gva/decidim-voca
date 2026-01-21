# frozen_string_literal: true

require "spec_helper"

# Load the CLI class from bin/vocasnap
spec_dir = __dir__
project_root = File.expand_path("../../../../", spec_dir)
lib_path = File.join(project_root, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
require "decidim/voca/snapshot"
require "thor"
require "io/console"
require "fileutils"

# Load bin/vocasnap but prevent it from executing
unless defined?(Decidim::Voca::VocasnapCLI)
  bin_path = File.join(project_root, "bin", "vocasnap")
  original_program_name = $PROGRAM_NAME
  original_argv = ARGV.dup
  $PROGRAM_NAME = bin_path
  ARGV.clear
  load bin_path
  ARGV.replace(original_argv)
  $PROGRAM_NAME = original_program_name
end

module Decidim
  module Voca
    describe VocasnapCLI do
      let(:cli) { described_class.new }

      describe "#validate_password" do
        context "with valid passwords" do
          it "accepts password with all requirements met" do
            password = %(MySecure123!@#)
            errors = cli.send(:validate_password, password)
            expect(errors).to be_empty
          end

          it "accepts password with exactly 13 characters" do
            password = %(Abc123!@#$%^&)
            errors = cli.send(:validate_password, password)
            expect(errors).to be_empty
          end

          it "accepts password with many unique characters" do
            password = %(MyP@ssw0rd!2024)
            errors = cli.send(:validate_password, password)
            expect(errors).to be_empty
          end

          it "accepts password with special characters" do
            password = %(Test123!@#$%^&*())
            errors = cli.send(:validate_password, password)
            expect(errors).to be_empty
          end
        end

        context "with invalid passwords" do
          it "rejects password that is too short" do
            password = %(Short1!@)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must be over 12 characters")
            expect(errors).to include("Password must have at least 9 unique characters")
          end

          it "rejects password with exactly 12 characters" do
            password = %(Exactly12!@)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must be over 12 characters")
          end

          it "rejects password without uppercase letter" do
            password = %(lowercase123!@#)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must contain at least 1 uppercase letter")
          end

          it "rejects password without lowercase letter" do
            password = %(UPPERCASE123!@#)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must contain at least 1 lowercase letter")
          end

          it "rejects password without number" do
            password = %(NoNumbers!@#)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must contain at least 1 number")
            expect(errors).to include("Password must be over 12 characters")
          end

          it "rejects password without symbol" do
            password = "NoSymbols123"
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must contain at least 1 symbol")
            expect(errors).to include("Password must be over 12 characters")
          end

          it "rejects password with fewer than 9 unique characters" do
            password = %(AAAAA123!@#$)
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must have at least 9 unique characters")
            expect(errors).to include("Password must be over 12 characters")
            expect(errors).to include("Password must contain at least 1 lowercase letter")
          end

          it "rejects password with exactly 8 unique characters" do
            password = "Aabbccdd123!"
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must be over 12 characters")
          end

          it "rejects password with multiple violations" do
            password = "short"
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must be over 12 characters")
            expect(errors).to include("Password must have at least 9 unique characters")
            expect(errors).to include("Password must contain at least 1 uppercase letter")
            expect(errors).to include("Password must contain at least 1 number")
            expect(errors).to include("Password must contain at least 1 symbol")
          end

          it "rejects password with only lowercase and numbers" do
            password = "lowercase12345"
            errors = cli.send(:validate_password, password)
            expect(errors).to include("Password must contain at least 1 uppercase letter")
            expect(errors).to include("Password must contain at least 1 symbol")
            expect(errors).not_to include("Password must be over 12 characters")
          end
        end
      end
    end
  end
end
