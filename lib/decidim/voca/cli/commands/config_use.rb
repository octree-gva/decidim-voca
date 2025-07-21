# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigUse < Config
          def run(args)
            parse_options(args)
            execute
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                Use Account (v.#{::Decidim::Voca.version})
                Mark an account as in use, this account will be used when running commands.

                Usage:
                  voca config use [options]
              USAGE
              opts.on("-n", "--name NAME", "Account name") do |name|
                @options[:account] = name
              end
            end
            parser.parse!(args)
          end

          def execute
            account = find_account
            accounts.all.each do |a|
              a["in_use"] = false
            end
            account["in_use"] = true
            accounts.save
            if format == "table"
              prompt.say("Using #{account["name"]} account", color: :green)
            else
              prompt.say({ success: "Using #{account["name"]} account" }.to_json)
            end
          end
        end
      end
    end
  end
end
