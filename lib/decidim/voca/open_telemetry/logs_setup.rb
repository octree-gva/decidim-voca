# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class LogsSetup
        BATCH_SCHEDULE_DELAY_MS = 1000
        BATCH_MAX_QUEUE_SIZE = 2048
        BATCH_MAX_EXPORT_SIZE = 512

        def self.call(logs_endpoint:, exporter_timeout:, resource:)
          new(logs_endpoint:, exporter_timeout:, resource:).call
        end

        def initialize(logs_endpoint:, exporter_timeout:, resource:)
          @logs_endpoint = logs_endpoint
          @exporter_timeout = exporter_timeout
          @resource = resource
        end

        def call
          return nil unless available?

          ensure_logs_env
          exporter = build_exporter
          return nil unless exporter

          processor = build_processor(exporter)
          provider = build_provider(processor)
          register_processor(provider, processor)
          persist_provider(provider)
          schedule_flush(processor)
          extended = extend_rails_logger
          log_result(extended)
          { extended: }
        rescue StandardError => e
          Rails.logger.error("[OpenTelemetry] Failed to configure logging: #{e.class} - #{e.message}")
          Rails.logger.error("[OpenTelemetry] Backtrace: #{e.backtrace.first(5).join("\n")}")
          nil
        end

        private

        attr_reader :logs_endpoint, :exporter_timeout, :resource

        def available?
          if logs_endpoint.blank?
            Rails.logger.debug("[OpenTelemetry] Logs endpoint not configured - skipping logs setup")
            return false
          end
          unless defined?(::OpenTelemetry::SDK::Logs::LoggerProvider)
            Rails.logger.debug("[OpenTelemetry] Logs SDK not available - skipping logs setup")
            return false
          end
          true
        end

        def ensure_logs_env
          return if ENV["OTEL_EXPORTER_OTLP_LOGS_ENDPOINT"]

          ENV["OTEL_EXPORTER_OTLP_LOGS_ENDPOINT"] = logs_endpoint
          Rails.logger.debug { "[OpenTelemetry] Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=#{logs_endpoint}" }
        end

        def build_exporter
          unless defined?(::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter)
            Rails.logger.error("[OpenTelemetry] Logs-specific OTLP exporter not available")
            return nil
          end
          Rails.logger.debug { "[OpenTelemetry] Created logs exporter" }
          ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
            endpoint: logs_endpoint,
            timeout: exporter_timeout,
            headers: {}
          )
        end

        def build_processor(exporter)
          if defined?(::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor)
            ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter)
          else
            build_batch_processor(exporter)
          end
        end

        def build_batch_processor(exporter)
          processor = ::OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
            exporter,
            exporter_timeout: exporter_timeout * 1000,
            schedule_delay: BATCH_SCHEDULE_DELAY_MS,
            max_queue_size: BATCH_MAX_QUEUE_SIZE,
            max_export_batch_size: BATCH_MAX_EXPORT_SIZE
          )
          at_exit do
            processor.force_flush(timeout: exporter_timeout) if processor.respond_to?(:force_flush)
          rescue StandardError => e
            warn("[OpenTelemetry] Failed to flush logs on shutdown: #{e.message}")
          end
          processor
        end

        def build_provider(_processor)
          ::OpenTelemetry::SDK::Logs::LoggerProvider.new(resource:)
        end

        def register_processor(provider, processor)
          if provider.respond_to?(:add_log_record_processor)
            provider.add_log_record_processor(processor)
          elsif provider.respond_to?(:log_record_processors=)
            provider.log_record_processors = [processor]
          else
            provider.instance_variable_set(:@log_record_processors, [processor])
          end
        end

        def persist_provider(provider)
          Decidim::Voca.opentelemetry_logger_provider = provider
          Rails.logger.debug("[OpenTelemetry] Logger provider stored in Decidim::Voca")
        end

        def schedule_flush(processor)
          return unless processor.respond_to?(:force_flush)

          at_exit { processor.force_flush(timeout: 5) }
        end

        def extend_rails_logger
          if Rails.logger.is_a?(ActiveSupport::Logger)
            Rails.logger.extend(OtelLogger)
            Rails.logger.debug("[OpenTelemetry] Extended Rails.logger with OtelLogger")
            true
          elsif Rails.logger.respond_to?(:broadcast)
            extend_broadcast_loggers
          else
            Rails.logger.warn("[OpenTelemetry] Rails.logger is #{Rails.logger.class} - cannot extend with OtelLogger")
            false
          end
        end

        def extend_broadcast_loggers
          broadcasts = Rails.logger.instance_variable_get(:@broadcasts) || []
          count = 0
          broadcasts.each do |logger|
            if logger.is_a?(ActiveSupport::Logger)
              logger.extend(OtelLogger)
              count += 1
            end
          end
          Rails.logger.debug { "[OpenTelemetry] Extended #{count} logger(s) in BroadcastLogger" }
          count.positive?
        end

        def log_result(extended)
          if extended
            Rails.logger.info("[OpenTelemetry] Logging configured successfully")
          else
            Rails.logger.warn("[OpenTelemetry] Logger provider configured but Rails logger was not extended")
          end
        end
      end
    end
  end
end
