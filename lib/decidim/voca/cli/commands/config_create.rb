# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class ConfigCreate < Config
          def run(args)
            parse_options(args)
            execute
          end

          private

          def parse_options(args)
            parser = OptionParser.new do |opts|
              default_options(opts)
              opts.banner = <<~USAGE
                Create a new account (v.#{::Decidim::Voca.version})
                Usage:
                  voca config create [options]
              USAGE
              opts.on("-n", "--name NAME", "Account name") do |name|
                @options[:account] = name
              end
            end
            parser.parse!(args)
          end

          def execute
            @options[:account] ||= prompt.ask("New account name", required: true, filter: /[a-zA-Z0-9]+/)
            accounts.create(@options[:account], {})
            accounts.save
            message = "Account created. Use 'voca config set -n #{@options[:account]}' to set the account credentials"
            if format == "table"
              prompt.say(message, color: :green)
            else
              prompt.say({ success: message }.to_json)
            end
          end
        end
      end
    end
  end
end
