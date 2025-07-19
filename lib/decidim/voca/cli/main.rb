# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      class Main
        def initialize
          @main_parser = OptionParser.new do |opts|
            opts.banner = <<~USAGE
              Voca Client (v.#{::Decidim::Voca.version})
              Usage: voca [command] [options]
              Commands:
                - 
            USAGE

            opts.on("-h", "--help", "Show this help message") do
              puts opts # rubocop:disable Rails/Output
              exit 0 # rubocop:disable Rails/Exit
            end
          end
        end

        def run(args)
          if ENV.fetch("DISABLE_VOCA_BIN", "false") == "true"
            Rails.logger.debug "voca is disabled. See DISABLE_VOCA_BIN environment variable"
            exit 0 # rubocop:disable Rails/Exit
          end
          command = args.first

          case command
          when "console"
            Commands::Console.new.run(args[1..])
          when "help", nil
            puts @main_parser # rubocop:disable Rails/Output
          else
            puts @main_parser # rubocop:disable Rails/Output
            puts "Unknown command: #{command}" # rubocop:disable Rails/Output
            exit 0 # rubocop:disable Rails/Exit
          end
        end
      end
    end
  end
end

