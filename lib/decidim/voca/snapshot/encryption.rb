# frozen_string_literal: true

module Decidim
  module Voca
    module Snapshot
      class Encryption
        ALGORITHM = "AES-256-CBC"

        def self.encrypt_file(input_path, output_path, password)
          raise "Input file does not exist: #{input_path}" unless File.exist?(input_path)
          raise "Password cannot be empty" if password.blank?

          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.encrypt
          cipher.key = derive_key(password)
          iv = cipher.random_iv
          cipher.iv = iv

          File.open(output_path, "wb") do |out|
            out.write(iv)
            File.open(input_path, "rb") do |in_file|
              while (chunk = in_file.read(4096))
                out.write(cipher.update(chunk))
              end
              out.write(cipher.final)
            end
          end
        rescue Errno::ENOENT => e
          raise "File operation failed: #{e.message}"
        rescue OpenSSL::Cipher::CipherError => e
          raise "Encryption failed: #{e.message}"
        end

        def self.decrypt_file(input_path, output_path, password)
          cipher = OpenSSL::Cipher.new(ALGORITHM)
          cipher.decrypt
          cipher.key = derive_key(password)

          File.open(input_path, "rb") do |in_file|
            iv = in_file.read(16)
            cipher.iv = iv

            File.open(output_path, "wb") do |out|
              while (chunk = in_file.read(4096))
                out.write(cipher.update(chunk))
              end
              out.write(cipher.final)
            end
          end
        end

        def self.derive_key(password)
          OpenSSL::Digest::SHA256.digest(password)
        end
      end
    end
  end
end
