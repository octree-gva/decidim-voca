# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      class Accounts
        include Singleton

        def initialize
          reload
        end

        def in_use
          all.find { |account| account["in_use"] }
        end

        def reload
          @accounts = read_configuration_files
        end

        def all
          @accounts || []
        end

        def find(name)
          all.find { |account| account["name"] == name }
        end

        def create(name, options)
          @accounts << { "name" => name, **options }
          save
        end

        def delete(account)
          @accounts.delete(account)
          save
        end

        def save
          FileUtils.mkdir_p(File.dirname(configuration_file)) unless File.exist?(configuration_file)
          File.write(configuration_file, { accounts: @accounts }.to_yaml)
          reload
        end

        def valid?(account)
          required_keys = %w(name s3_access_key s3_secret_key s3_bucket_name secret_key_base)
          account.is_a?(Hash) && required_keys.all? { |key| account.has_key?(key) && account[key].length > 4 }
        end

        private

        def configuration_file
          @configuration_file ||= ENV.fetch("VOCA_CONFIG_FILE", Rails.root.join(".voca/accounts.yml").to_s)
        end

        def read_configuration_files
          if File.exist?(configuration_file)
            YAML.load_file(configuration_file)[:accounts]
          else
            []
          end
        end
      end
    end
  end
end
