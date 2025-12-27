# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      module OtelLogger
        include DecidimContextAttributes
        def add(severity, message = nil, progname = nil, &block)
          # Extract message before calling super (block might have side effects)
          log_message = message || (block ? block.call : nil)
          result = super
          send_to_otel(severity, Time.now, progname, log_message)
          result
        end

        private

        def send_to_otel(severity, timestamp, progname, msg)
          return unless defined?(::OpenTelemetry::Logs)
          return unless (logger_provider = ::OpenTelemetry::Logs.logger_provider)

          message = msg.is_a?(String) ? msg : msg.inspect
          return if message.nil? || message.empty?

          logger = logger_provider.logger("decidim-voca")
          log_record = logger.create_log_record(
            timestamp: timestamp,
            severity_number: severity_to_number(severity),
            severity_text: severity_to_text(severity),
            body: message,
            attributes: extract_attributes(progname)
          )

          logger.emit(log_record)
        rescue StandardError => e
          # Don't break logging if OpenTelemetry fails
          # Use original logger to avoid recursion
          original_logger = Rails.logger.instance_variable_get(:@logdev)&.dev
          original_logger&.puts("[OpenTelemetry] Failed to emit log: #{e.message}")
        end

        def severity_to_number(severity)
          case severity
          when 0, "DEBUG", "debug" then 5
          when 1, "INFO", "info" then 9
          when 2, "WARN", "warn" then 13
          when 3, "ERROR", "error" then 17
          when 4, "FATAL", "fatal" then 21
          else 9
          end
        end

        def severity_to_text(severity)
          case severity
          when 0, "DEBUG", "debug" then "DEBUG"
          when 1, "INFO", "info" then "INFO"
          when 2, "WARN", "warn" then "WARN"
          when 3, "ERROR", "error" then "ERROR"
          when 4, "FATAL", "fatal" then "FATAL"
          else "INFO"
          end
        end

        def extract_attributes(progname)
          attrs = {}
          attrs["logger.name"] = progname if progname

          # Try to extract Decidim context from current request
          env = extract_env
          if env
            set_user_attributes(env, attrs)
            set_organization_attributes(env, attrs)
            set_participatory_space_attributes(env, attrs)
            set_component_attributes(env, attrs)
          end

          # Add trace context if available
          span = ::OpenTelemetry::Trace.current_span
          if span&.context&.valid?
            trace_id = span.context.trace_id
            span_id = span.context.span_id
            attrs["trace_id"] = trace_id.unpack1("H*")
            attrs["span_id"] = span_id.unpack1("H*")
          end

          attrs
        end

        def extract_env
          # Try to get current request from ActionDispatch::Request.current
          if defined?(ActionDispatch::Request)
            begin
              request = ActionDispatch::Request.current
              return request.env if request&.respond_to?(:env)
            rescue StandardError
              # ActionDispatch::Request.current might not be available
            end
          end

          # Try to get request from Thread.current (Rails pattern)
          if (request = Thread.current[:request])&.respond_to?(:env)
            return request.env
          end

          nil
        end

      end
    end
  end
end

