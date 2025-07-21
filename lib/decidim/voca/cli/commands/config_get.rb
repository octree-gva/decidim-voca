# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigGet < Config
          def run(args)
            parse_options(args)
            execute(args.first)
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                Get Configuration (v.#{::Decidim::Voca.version})
                If no key is provided, the entire account will be displayed.
                If a key is provided, the key will be displayed from the account.

                Usage:
                  voca config get [key] [options]
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
              display_one(account, config_key)
            else
              display(account)
            end
          end

          def display_one(account, config_key)
            if format == "table"
              data = [[config_key, account[config_key]]]
              prompt.say(TTY::Table.new(data).render(:ascii))
            else
              prompt.say({ config_key => account[config_key] }.to_json)
            end
          end

          def display(account)
            if format == "table"
              data = account.to_a
              prompt.say(TTY::Table.new(data).render(:ascii))
            else
              prompt.say(account.to_json)
            end
          end
        end
      end
    end
  end
end
