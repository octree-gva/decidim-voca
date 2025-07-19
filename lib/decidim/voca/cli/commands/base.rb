# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      module Commands
        class Base
          def initialize
            @options = {
              format: "json",
            }
          end

          def format
            @options[:format]
          end

          protected

          def default_options(opts)
            opts.on("-h", "--help", "Show command help") do
              puts opts # rubocop:disable Rails/Output
              exit 0 # rubocop:disable Rails/Exit
            end
          end

          def red(text)
            "\e[31m#{text}\e[0m"
          end

          def puts_error(text)
            if format == "json"
              puts({ error: text }.to_json) # rubocop:disable Rails/Output
            else
              puts "" # rubocop:disable Rails/Output
              puts red(text) # rubocop:disable Rails/Output
            end
            exit 0 # rubocop:disable Rails/Exit
          end
        end
      end
    end
  end
end
