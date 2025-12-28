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
          
          # Try to get logger provider - Ruby OpenTelemetry logs SDK is incomplete
          # so we store it ourselves in Decidim::Voca
          logger_provider = begin
            if ::OpenTelemetry::Logs.respond_to?(:logger_provider)
              ::OpenTelemetry::Logs.logger_provider
            else
              Decidim::Voca.opentelemetry_logger_provider
            end
          end
          
          return unless logger_provider

          message = msg.is_a?(String) ? msg : msg.inspect
          return if message.nil? || message.empty?

          begin
            logger = logger_provider.logger(name: "decidim-voca")
            return unless logger
            
            attributes = extract_attributes(progname)
            
            # Try different API approaches - Ruby logs SDK API is inconsistent
            if logger.respond_to?(:emit)
              # Method 1: emit with parameters directly
              logger.emit(
                timestamp: timestamp,
                severity_number: severity_to_number(severity),
                severity_text: severity_to_text(severity),
                body: message,
                attributes: attributes
              )
            elsif defined?(::OpenTelemetry::Logs::LogRecord) && ::OpenTelemetry::Logs::LogRecord.respond_to?(:new)
              # Method 2: Create LogRecord and emit it
              log_record = ::OpenTelemetry::Logs::LogRecord.new(
                timestamp: timestamp,
                severity_number: severity_to_number(severity),
                severity_text: severity_to_text(severity),
                body: message,
                attributes: attributes
              )
              logger.emit(log_record)
            else
              # Method 3: Try calling emit with positional args
              logger.emit(timestamp, severity_to_number(severity), severity_to_text(severity), message, attributes)
            end
          rescue StandardError => e
            # Don't break logging if OpenTelemetry fails
            # Use stderr to avoid recursion
            $stderr.puts("[OpenTelemetry] Failed to emit log: #{e.class} - #{e.message}") if ENV["OTEL_DEBUG"]
            $stderr.puts("[OpenTelemetry] Backtrace: #{e.backtrace.first(3).join("\n")}") if ENV["OTEL_DEBUG"]
          end
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

