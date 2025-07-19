# frozen_string_literal: true

require "pty"

module Decidim
  module Voca
    module CLI
      module Commands
        class Console < Base
          attr_reader :parser
          def initialize
            super
            @options[:executor] = nil
            @options[:organization] = nil
          end

          def run(args)
            parse_options(args)
            execute
          end

          private

          def parse_options(args)
            @parser = OptionParser.new do |opts|
              opts.banner = <<~USAGE
                Voca CLI for Decidim (V.#{::Decidim::Voca.version})
                Usage: voca console [options]
              USAGE

              default_options(opts)

              opts.on("--executor EXECUTOR", "Who is executing the command") do |executor|
                @options[:executor] = executor
              end
              opts.on("--organization ORGANIZATION", "Organization tenant to use") do |organization|
                @options[:organization] = organization
              end
            end
            parser.parse!(args)
          end

          def execute
            @options[:organization] ||= select_organization_interactively
            puts_error("No organization found for id #{@options[:organization]}") unless Decidim::Organization.exists?(id: @options[:organization])
            @options[:executor] ||= select_executor_interactively
            puts "Console with options: #{@options.inspect}"

            log_file = Rails.root.join("tmp", "console-#{Time.current.iso8601}.txt")
            
            command = "bundle exec rails console"
            PTY.spawn({ "RAILS_ENV" => Rails.env }, command) do |stdout, stdin, pid|
              File.open(log_file, "w") do |log|
                # Handle output from console
                reader = Thread.new do
                  loop do
                    data = stdout.readpartial(1024)
                    $stdout.write(data)
                    clean_data = clean_terminal_output(data)
                    log.write(clean_data)
                    log.flush
                  rescue EOFError
                    break
                  end
                end

                # Handle input to console
                writer = Thread.new do
                  loop do
                    data = $stdin.readpartial(1024)
                    stdin.write(data)
                    stdin.flush
                    log.write(data)
                    log.flush
                  rescue EOFError
                    break
                  end
                end

                reader.join
                writer.join
              end
            rescue PTY::ChildExited
              # Child process exited
            ensure
              log_stream.close
              stdin.close
              stdout.close
              Process.wait(pid) if pid
            end
          end

          def clean_terminal_output(data)
            # More comprehensive ANSI escape sequence removal
            cleaned = data
              # Remove all ANSI escape sequences (CSI sequences)
              .gsub(/\e\[[0-9;]*[a-zA-Z]/, '')
              # Remove other escape sequences
              .gsub(/\e\[[?]?[0-9;]*[hlc]/, '')
              .gsub(/\e\[[0-9]*[ABCD]/, '')
              .gsub(/\e\[[0-9]*[G]/, '')
              .gsub(/\e\[[0-9]*[K]/, '')
              # Remove specific problematic sequences like [22;2R, [22;1R
              .gsub(/\e\[[0-9]+;[0-9]+[R]/, '')
              # Remove any remaining escape sequences
              .gsub(/\e\[[^a-zA-Z]*[a-zA-Z]/, '')
              # Remove standalone escape characters
              .gsub(/\e/, '')
              # Remove control characters except newlines and tabs
              .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
              # Normalize line endings
              .gsub(/\r\n/, "\n")
              .gsub(/\r/, "\n")
              # Remove multiple consecutive newlines (keep max 2)
              .gsub(/\n{3,}/, "\n\n")
              # Remove leading/trailing whitespace from lines
              .gsub(/^\s+|\s+$/, '')
            
            # Force UTF-8 encoding and handle invalid characters
            cleaned.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
          end

          def select_organization_interactively
            organizations = Decidim::Organization.pluck(:id, :host)
            
            if organizations.empty?
              puts_error("No organizations found in the database")
            end

            if organizations.size == 1
              puts "Selecting organization #{organizations.first[1]} (ID: #{organizations.first[0]})"
              return organizations.first[0]
            end           
            
            prompt = TTY::Prompt.new
            choices = organizations.map { |id, host| { name: "#{host} (ID: #{id})", value: id } }
            prompt.select("Select organization:", choices)          
          end

          ##
          # Ask for the executor name (string)
          # Required field with min length of 3
          def select_executor_interactively
            prompt = TTY::Prompt.new
            prompt.ask("Enter the executor name:") do |q|
              q.required true
              q.validate(/^.{3,}$/, "Name must be at least 3 characters long")
            end
          end
        end
      end
    end
  end
end
