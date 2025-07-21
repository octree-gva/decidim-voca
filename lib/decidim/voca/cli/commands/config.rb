# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class Config < Base
          def initialize
            super
            @options[:account] = nil
          end

          def run(args)
            command = args.first
            case command
            when "create"
              ConfigCreate.new.run(args[1..])
            when "list"
              ConfigList.new.run(args[1..])
            when "get"
              ConfigGet.new.run(args[1..])
            when "set"
              ConfigSet.new.run(args[1..])
            when "delete"
              ConfigDelete.new.run(args[1..])
            when "use"
              ConfigUse.new.run(args[1..])
            when "help"
              Rails.logger.debug usage
            else
              Rails.logger.debug usage
              ConfigGet.new.run(args)
            end
          end

          protected

          def usage
            <<~USAGE
              Configure Voca Accounts (v.#{::Decidim::Voca.version})
              Usage:
                - voca config create
                - voca config list
                - voca config get [key]
                - voca config set [key] [value]
                - voca config delete [key] (delete a key)
                - voca config use [name] (use an account)
            USAGE
          end

          def find_account
            @options[:account] ||= interactive_ask_account
            account = accounts.find(@options[:account])
            if account.nil?
              if format == "table"
                prompt.say("Account not found", color: :red)
              else
                prompt.say({ error: "Account not found" }.to_json)
              end
              exit 0 # rubocop:disable Rails/Exit
            end
            account
          end

          def interactive_ask_account
            prompt.select("Your account name", accounts_names, required: true, filter: true)
          end

          def interactive_prompt_for(account, key, required: true)
            prompt_text = case key
                          when "s3_access_key"
                            "S3 access key"
                          when "s3_secret_key"
                            "S3 secret key"
                          when "s3_bucket_name"
                            "S3 bucket name"
                          when "s3_region"
                            "S3 region"
                          when "s3_endpoint"
                            "S3 endpoint"
                          when "secret_key_base"
                            "Secret Key Base"
                          when "jelastic_host"
                            "Jelastic Host"
                          when "jelastic_token"
                            "Jelastic Token"
                          else
                            raise "Unknown key: #{key}"
                          end
            prompt.mask(prompt_text, default: account[key], required:)
          end
        end
      end
    end
  end
end
