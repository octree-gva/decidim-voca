# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigList < Config
          def run(args)
            parse_options(args)
            execute
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                List Accounts (v.#{::Decidim::Voca.version})
                Usage:
                  voca config list [options]
              USAGE
            end
            parser.parse!(args)
          end

          def execute
            if format == "table"
              accounts.all.map do |account|
                data = account.to_a
                in_use = account["in_use"] ? Pastel.new.green("(IN USE)") : "\n"
                prompt.say("#{account["name"]} Account #{in_use}")
                prompt.say(TTY::Table.new(data).render(:ascii))
                prompt.say("\n")
              end
            else
              accounts.all.map do |account|
                prompt.say(account.to_json)
              end
            end
          end
        end
      end
    end
  end
end
