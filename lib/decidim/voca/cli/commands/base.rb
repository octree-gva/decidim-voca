# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class Base
          def initialize
            @options = {
              format: ci? ? "json" : "table"
            }
          end

          def format
            @options[:format]
          end

          def ci?
            ["1", "true"].include?(ENV.fetch("CI", "false"))
          end

          def interactive!
            puts_error("This command is not available in CI") if ci?
          end

          protected

          def accounts
            Decidim::Voca::CLI::Accounts.instance
          end

          def accounts_names
            accounts.all.map { |account| account["name"] }
          end

          def prompt
            @prompt ||= TTY::Prompt.new
          end

          def default_options(opts)
            opts.on("-h", "--help", "Show command help") do
              prompt.say(opts)
              exit 0 # rubocop:disable Rails/Exit
            end
            opts.on("-f", "--format FORMAT", "Output format (json, table)") do |format|
              @options[:format] = format
            end
          end

          def red(text)
            "\e[31m#{text}\e[0m"
          end

          def puts_error(text)
            if format == "json"
              prompt.say({ error: text }.to_json)
            else
              prompt.say(red(text), color: :red)
            end
            exit 0 # rubocop:disable Rails/Exit
          end
        end
      end
    end
  end
end
