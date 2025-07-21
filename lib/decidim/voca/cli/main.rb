# frozen_string_literal: true

module Decidim
  module Voca
    module CLI
      class Main 
        def usage
          <<~USAGE
              Voca Client (v.#{::Decidim::Voca.version})
              Usage: voca [command] [options]
              Commands:
                - help
                - config help
                - config create
                - config list
                - config get [key]
                - config set [key] [value]
                - config delete [key] 
                - config use [name]
            USAGE
        end

        def initialize
          @main_parser = OptionParser.new do |opts|
            opts.banner = usage

            opts.on("-h", "--help", "Show this help message") do
              puts opts # rubocop:disable Rails/Output
              exit 0 # rubocop:disable Rails/Exit
            end
          end
        end

        def run(args)
          prompt = TTY::Prompt.new
          if ENV.fetch("DISABLE_VOCA_BIN", "false") == "true"
            prompt.say("voca is disabled. See DISABLE_VOCA_BIN environment variable", color: :red)
            exit 0 # rubocop:disable Rails/Exit
          end
          command = args.first

          case command
          when "config"
            Commands::Config.new.run(args[1..])
          when "help", nil
            prompt.say(usage)
          else
            @main_parser.parse(args)
            prompt.say(@main_parser)
            prompt.say("Unknown command: #{command}", color: :red)
            exit 0 # rubocop:disable Rails/Exit
          end
        end
      end
    end
  end
end
