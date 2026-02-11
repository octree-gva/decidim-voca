# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      module OtelLogger
        include DecidimContextAttributes
        def add(severity, message = nil, progname = nil, &block)
          # Extract message before calling super (block might have side effects)
          # If message is nil, try to get it from the block
          log_message = if message.nil? && block
                          block.call
                        else
                          message
                        end

          # If still nil, use progname as fallback
          log_message ||= progname

          result = super
          send_to_otel(severity, Time.zone.now, progname, log_message) if log_message
          result
        end

        private

        def send_to_otel(severity, timestamp, progname, msg)
          return unless defined?(::OpenTelemetry::Logs)
          return if low_severity?(severity)

          logger_provider = resolve_logger_provider
          return unless logger_provider

          message = message_to_string(msg)
          return if message.blank?

          emit_log(logger_provider, severity, timestamp, message, progname)
        rescue StandardError => e
          warn("[OpenTelemetry] Failed to emit log: #{e.class} - #{e.message}") if ENV["OTEL_DEBUG"]
          warn("[OpenTelemetry] Backtrace: #{e.backtrace.first(3).join("\n")}") if ENV["OTEL_DEBUG"]
        end

        LOW_SEVERITY = [0, 1, "DEBUG", "debug", "INFO", "info"].freeze
        def low_severity?(severity)
          LOW_SEVERITY.include?(severity)
        end

        def resolve_logger_provider
          if ::OpenTelemetry::Logs.respond_to?(:logger_provider)
            ::OpenTelemetry::Logs.logger_provider
          else
            Decidim::Voca.opentelemetry_logger_provider
          end
        end

        def message_to_string(msg)
          return nil if msg.nil?

          if msg.is_a?(String)
            msg
          elsif msg.respond_to?(:to_s)
            msg.to_s
          else
            msg.inspect
          end
        end

        def emit_log(logger_provider, severity, timestamp, message, progname)
          logger = logger_provider.logger(name: "decidim-voca")
          return unless logger

          attributes = extract_attributes(progname)
          logger.on_emit(
            timestamp:,
            severity_number: severity_to_number(severity),
            severity_text: severity_to_text(severity),
            body: message,
            attributes:
          )
        end

        # OTel severity: [number, text] for DEBUG, INFO, WARN, ERROR, FATAL (index 0..4)
        OTEL_SEVERITIES = [[5, "DEBUG"], [9, "INFO"], [13, "WARN"], [17, "ERROR"], [21, "FATAL"]].freeze
        SEVERITY_NAMES = %w(DEBUG INFO WARN ERROR FATAL).freeze

        def severity_to_number(severity)
          pair = otel_severity_pair(severity)
          pair ? pair.first : 9
        end

        def severity_to_text(severity)
          pair = otel_severity_pair(severity)
          pair ? pair.last : "INFO"
        end

        def otel_severity_pair(severity)
          idx = severity.is_a?(Integer) ? severity : SEVERITY_NAMES.index(severity.to_s.upcase)
          idx && idx.between?(0, 4) ? OTEL_SEVERITIES[idx] : nil
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
          return attrs unless span&.context&.valid?

          trace_id = span.context.trace_id
          span_id = span.context.span_id
          attrs["trace_id"] = trace_id.unpack1("H*")
          attrs["span_id"] = span_id.unpack1("H*")
          attrs
        end

        def extract_env
          begin
            request = ActionDispatch::Request.current
            return request.env if request.respond_to?(:env)
          rescue StandardError
            # ActionDispatch::Request.current might not be available
          end

          request = Thread.current[:request]
          return request.env if request.respond_to?(:env)

          nil
        end
      end
    end
  end
end
