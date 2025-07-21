# frozen_string_literal: true

require "tty-prompt"
require "pastel"
require "fileutils"
require "time"

module Decidim
  module Voca
    module ConsoleHook
      def interactive_ask_organization(prompt)
        choices = Decidim::Organization.pluck(:host, :id).to_h
        prompt.select("Which organization?", choices, required: true, filter: true)
      end

      def interactive_ask_operator(prompt)
        prompt.ask("Who are you?", required: true, validate: /[a-zA-Z0-9]{4,}/)
      end

      def welcome_message
        pastel = Pastel.new
        <<~TEXT
          You are running a console on a #{pastel.red("production server")}. This a big thing.

          - Identify yourself
          - Do as little as possible
          - If you want to just consult a data, run --sandbox

        TEXT
      end

      def start(*args)
        # Prompt for metadata BEFORE starting the console
        prompt = TTY::Prompt.new
        Rails.logger.debug welcome_message
        operator = interactive_ask_operator(prompt)
        org_id = interactive_ask_organization(prompt)
        org = Decidim::Organization.find(org_id)

        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
        log_dir = File.expand_path("tmp/interventions", Dir.pwd)
        FileUtils.mkdir_p(log_dir)
        log_path = File.join(log_dir, "console-#{timestamp}.log")

        log_file = File.open(log_path, "w")
        log_file.puts "x started at=#{Time.now.utc.iso8601} operator=\"#{operator}\" org=#{org.id}<#{org.host}> +meta"
        log_file.flush

        # Disable colorized logging
        Rails.application.config.colorize_logging = false

        # Force SQL logging with custom formatter
        sql_logger = Logger.new(log_file)
        sql_logger.level = Logger::DEBUG
        sql_logger.formatter = proc do |_severity, datetime, _progname, msg|
          "x -> #{datetime.strftime("%Y-%m-%dT%H:%M:%S")} #{msg} +sql\n"
        end
        ActiveRecord::Base.logger = sql_logger
        ActiveRecord.verbose_query_logs = true

        # Hook into IRB context creation
        IRB::Context.class_eval do
          alias_method :evaluate_without_voca_hook, :evaluate
          define_method :log_file do
            log_file
          end

          def evaluate(*args, **kwargs)
            code = args.first
            if log_file && code && !code.strip.empty?
              timestamp = Time.zone.now.strftime("%Y-%m-%dT%H:%M:%S")
              log_file.puts "x #{timestamp} #{code.strip}"
              result = evaluate_without_voca_hook(*args, **kwargs)
              timestamp = Time.zone.now.strftime("%Y-%m-%dT%H:%M:%S")
              log_file.puts "x -> #{timestamp} #{result.inspect} +ruby"
              log_file.flush
            else
              result = evaluate_without_voca_hook(*args, **kwargs)
            end
            result
          end
        end

        # Run the original rails console
        super(*args)

        log_file.puts "x ended at=#{Time.now.utc.iso8601} +meta"
        log_file.close

        Rails.logger.debug { "log file: #{log_path}" }
      end
    end
  end
end
