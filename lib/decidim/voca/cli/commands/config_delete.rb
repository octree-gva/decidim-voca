# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigDelete < Config
          def run(args)
            parse_options(args)
            execute(args.first)
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                Delete Configuration (v.#{::Decidim::Voca.version})
                If no key is provided, the entire account will be deleted.
                If a key is provided, the key will be deleted from the account.

                Usage:
                  voca config delete [key] [options]
              USAGE
              opts.on("-n", "--name NAME", "Account name") do |name|
                @options[:account] = name
              end
            end
            parser.parse!(args)
          end

          def execute(config_key)
            account = find_account
            if config_key
              account.delete(config_key)
              accounts.save
              if format == "table"
                prompt.say("Account key #{config_key} deleted", color: :green)
              else
                prompt.say({ success: "Account key #{config_key} deleted" }.to_json)
              end
            else
              accounts.delete(account)
              if format == "table"
                prompt.say("Account deleted", color: :green)
              else
                prompt.say({ success: "Account deleted" }.to_json)
              end
            end
          end
        end
      end
    end
  end
end
