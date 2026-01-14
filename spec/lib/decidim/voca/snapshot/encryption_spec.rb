# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "decidim/voca/snapshot"

module Decidim
  module Voca
    module Snapshot
      describe Encryption do
        let(:password) { "test-password-123" }
        let(:test_content) { "This is test content to encrypt and decrypt" }

        describe ".encrypt_file" do
          it "encrypts a file successfully" do
            input_file = Tempfile.new("input")
            output_file = Tempfile.new("output")

            begin
              File.write(input_file.path, test_content)
              described_class.encrypt_file(input_file.path, output_file.path, password)

              expect(File.exist?(output_file.path)).to be true
              expect(File.size(output_file.path)).to be > 0
              expect(File.read(output_file.path)).not_to eq(test_content)
            ensure
              input_file.close
              input_file.unlink
              output_file.close
              output_file.unlink
            end
          end

          it "produces different output for same input with different passwords" do
            input_file = Tempfile.new("input")
            output_file1 = Tempfile.new("output1")
            output_file2 = Tempfile.new("output2")

            begin
              File.write(input_file.path, test_content)
              described_class.encrypt_file(input_file.path, output_file1.path, "password1")
              described_class.encrypt_file(input_file.path, output_file2.path, "password2")

              expect(File.read(output_file1.path)).not_to eq(File.read(output_file2.path))
            ensure
              input_file.close
              input_file.unlink
              output_file1.close
              output_file1.unlink
              output_file2.close
              output_file2.unlink
            end
          end
        end

        describe ".decrypt_file" do
          it "decrypts an encrypted file successfully" do
            input_file = Tempfile.new("input")
            encrypted_file = Tempfile.new("encrypted")
            decrypted_file = Tempfile.new("decrypted")

            begin
              File.write(input_file.path, test_content)
              described_class.encrypt_file(input_file.path, encrypted_file.path, password)
              described_class.decrypt_file(encrypted_file.path, decrypted_file.path, password)

              expect(File.read(decrypted_file.path)).to eq(test_content)
            ensure
              input_file.close
              input_file.unlink
              encrypted_file.close
              encrypted_file.unlink
              decrypted_file.close
              decrypted_file.unlink
            end
          end

          it "raises error with wrong password" do
            input_file = Tempfile.new("input")
            encrypted_file = Tempfile.new("encrypted")
            decrypted_file = Tempfile.new("decrypted")

            begin
              File.write(input_file.path, test_content)
              described_class.encrypt_file(input_file.path, encrypted_file.path, "correct-password")

              expect do
                described_class.decrypt_file(encrypted_file.path, decrypted_file.path, "wrong-password")
              end.to raise_error(OpenSSL::Cipher::CipherError)
            ensure
              input_file.close
              input_file.unlink
              encrypted_file.close
              encrypted_file.unlink
              decrypted_file.close
              decrypted_file.unlink
            end
          end
        end

        describe ".derive_key" do
          it "returns a consistent key for the same password" do
            key1 = described_class.derive_key(password)
            key2 = described_class.derive_key(password)

            expect(key1).to eq(key2)
            expect(key1.length).to eq(32) # SHA256 produces 32 bytes
          end

          it "returns different keys for different passwords" do
            key1 = described_class.derive_key("password1")
            key2 = described_class.derive_key("password2")

            expect(key1).not_to eq(key2)
          end
        end
      end
    end
  end
end

