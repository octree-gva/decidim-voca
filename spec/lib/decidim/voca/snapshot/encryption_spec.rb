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
              input_file.close!
              output_file.close!
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
              input_file.close!
              encrypted_file.close!
              decrypted_file.close!
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
              input_file.close!
              encrypted_file.close!
              decrypted_file.close!
            end
          end
        end

        describe ".derive_key" do
          it "returns consistent 32-byte keys" do
            key1 = described_class.derive_key(password)
            key2 = described_class.derive_key(password)
            expect(key1).to eq(key2)
            expect(key1.length).to eq(32)
          end
        end
      end
    end
  end
end
