# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigSet < Config
          def run(args)
            parse_options(args)
            execute(args.first, args[1])
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                Update Configuration Key (v.#{::Decidim::Voca.version})

                Usage:
                  voca config set [key] [value] [options]
              USAGE
              opts.on("-n", "--name NAME", "Account name") do |name|
                @options[:account] = name
              end
            end
            parser.parse!(args)
          end

          def execute(config_key, config_value)
            account = find_account
            if config_key
              account[config_key] = config_value
              config_value ||= interactive_prompt_for(account, config_key, required: false)
              account[config_key] = config_value
            else
              %w(
                s3_access_key
                s3_secret_key
                s3_bucket_name
                s3_region
                s3_endpoint
                secret_key_base
                jelastic_token
                jelastic_host
              ).each do |key|
                account[key] = interactive_prompt_for(account, key, required: true)
              end
            end
            accounts.save

            if format == "table"
              prompt.say("Account updated", color: :green)
            else
              prompt.say({ success: "Account updated" }.to_json)
            end
          end
        end
      end
    end
  end
end
