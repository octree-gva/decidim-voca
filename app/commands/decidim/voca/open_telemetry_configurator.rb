# frozen_string_literal: true

module Decidim
  module Voca
    class OpenTelemetryConfigurator < Decidim::Command
      def call
        unless Decidim::Voca.opentelemetry_enabled?
          Rails.logger.debug("[OpenTelemetry] Disabled - opentelemetry_enabled? returned false")
          return broadcast(:ok)
        end

        Rails.logger.info("[OpenTelemetry] Initializing...")
        Rails.logger.info("[OpenTelemetry] Traces endpoint: #{traces_endpoint}")
        Rails.logger.info("[OpenTelemetry] Logs endpoint: #{logs_endpoint}")
        Rails.logger.info("[OpenTelemetry] Service name: #{service_name}")

        configure_opentelemetry!
        verify_configuration!
        broadcast(:ok)
      rescue StandardError => e
        Rails.logger.error("[OpenTelemetry] Configuration failed: #{e.class} - #{e.message}")
        Rails.logger.error("[OpenTelemetry] Backtrace: #{e.backtrace.first(5).join("\n")}")
        broadcast(:invalid, e.message)
      end

      private

      def traces_endpoint
        Decidim::Voca.opentelemetry_traces_endpoint
      end

      def logs_endpoint
        Decidim::Voca.opentelemetry_logs_endpoint
      end

      def configure_opentelemetry!
        require_opentelemetry!
        configure_sdk!
      end

      def require_opentelemetry!
        require "opentelemetry/sdk"
        require "opentelemetry/exporter/otlp"
        require "opentelemetry/instrumentation/all"
        begin
          require "opentelemetry/sdk/logs"
        rescue LoadError => e
          # Logs SDK may not be available in all OpenTelemetry SDK versions
          Rails.logger.debug { "[OpenTelemetry] Logs SDK not available - logs will be disabled: #{e.message}" }
        end

        begin
          require "opentelemetry/exporter/otlp_logs"
        rescue LoadError => e
          Rails.logger.warn("[OpenTelemetry] OTLP logs exporter not available: #{e.message}")
          Rails.logger.warn("[OpenTelemetry] Add 'opentelemetry-exporter-otlp-logs' to Gemfile")
        end
      end

      def configure_sdk!
        Rails.logger.debug("[OpenTelemetry] Configuring SDK...")

        # Set timeout environment variables for OTLP exporter HTTP client
        # These are read by the OpenTelemetry SDK's HTTP client
        ENV["OTEL_EXPORTER_OTLP_TIMEOUT"] = exporter_timeout.to_s unless ENV["OTEL_EXPORTER_OTLP_TIMEOUT"]
        ENV["OTEL_EXPORTER_OTLP_TRACES_TIMEOUT"] = exporter_timeout.to_s unless ENV["OTEL_EXPORTER_OTLP_TRACES_TIMEOUT"]
        ENV["OTEL_EXPORTER_OTLP_LOGS_TIMEOUT"] = exporter_timeout.to_s unless ENV["OTEL_EXPORTER_OTLP_LOGS_TIMEOUT"]

        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = service_name
          c.resource = resource
          c.use_all(excluded_instrumentations: ["OpenTelemetry::Instrumentation::ActionPack"])
          c.add_span_processor(span_processor)
        end
        Rails.logger.info("[OpenTelemetry] SDK configured successfully")
        setup_logging!
        setup_error_reporting!
      end

      def service_name
        ENV.fetch("MASTER_ID", ENV.fetch("OTEL_SERVICE_NAME", "rails-app")).to_s
      end

      def resource
        ::OpenTelemetry::SDK::Resources::Resource.create(
          "deployment.environment" => Rails.env.to_s,
          "service.version" => Decidim.version.to_s,
          "host.name" => host_name
        )
      end

      def host_name
        ENV.fetch("MASTER_HOST", ENV.fetch("MASTER_IP", "unknown")).to_s
      end

      def exporter_timeout
        ENV.fetch("OTEL_EXPORTER_TIMEOUT", "5").to_i
      end

      def span_processor
        # OTLP::Exporter accepts timeout in seconds
        exporter = ::OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: traces_endpoint,
          timeout: exporter_timeout
        )

        # BatchSpanProcessor accepts exporter_timeout in milliseconds
        # schedule_delay in milliseconds, max_queue_size, max_export_batch_size
        ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          exporter,
          exporter_timeout: exporter_timeout * 1000,
          schedule_delay: 1000,
          max_queue_size: 2048,
          max_export_batch_size: 512
        )
      end

      def setup_logging!
        return unless logs_setup_available?

        Rails.logger.debug("[OpenTelemetry] Configuring logging...")
        Rails.logger.debug { "[OpenTelemetry] Logs endpoint: #{logs_endpoint}" }

        ensure_logs_env
        logs_exporter = build_logs_exporter
        return unless logs_exporter

        log_record_processor = build_log_record_processor(logs_exporter)
        logger_provider = build_logger_provider(log_record_processor)
        register_processor_with_provider(logger_provider, log_record_processor)
        persist_logger_provider(logger_provider)
        schedule_log_processor_flush(log_record_processor)
        extended = extend_rails_logger_with_otel
        log_setup_result(extended)
      rescue StandardError => e
        Rails.logger.error("[OpenTelemetry] Failed to configure logging: #{e.class} - #{e.message}")
        Rails.logger.error("[OpenTelemetry] Backtrace: #{e.backtrace.first(5).join("\n")}")
      end

      def logs_setup_available?
        if logs_endpoint.blank?
          Rails.logger.debug("[OpenTelemetry] Logs endpoint not configured - skipping logs setup")
          Rails.logger.debug("[OpenTelemetry] Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT or OTEL_EXPORTER_OTLP_ENDPOINT")
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

      def build_logs_exporter
        unless defined?(::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter)
          Rails.logger.error("[OpenTelemetry] Logs-specific OTLP exporter not available")
          Rails.logger.error("[OpenTelemetry] Cannot use generic OTLP exporter for logs - it encodes logs as spans")
          return nil
        end

        Rails.logger.debug { "[OpenTelemetry] Created logs exporter" }
        ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
          endpoint: logs_endpoint,
          timeout: exporter_timeout,
          headers: {}
        )
      end

      def build_log_record_processor(logs_exporter)
        if defined?(::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor)
          ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(logs_exporter)
        else
          build_batch_log_record_processor(logs_exporter)
        end
      end

      def build_batch_log_record_processor(logs_exporter)
        batch_processor = ::OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
          logs_exporter,
          exporter_timeout: exporter_timeout * 1000,
          schedule_delay: 1000,
          max_queue_size: 2048,
          max_export_batch_size: 512
        )
        at_exit do
          batch_processor.force_flush(timeout: exporter_timeout) if batch_processor.respond_to?(:force_flush)
        rescue StandardError => e
          warn("[OpenTelemetry] Failed to flush logs on shutdown: #{e.message}")
        end
        batch_processor
      end

      def build_logger_provider(_log_record_processor)
        ::OpenTelemetry::SDK::Logs::LoggerProvider.new(resource:)
      end

      def register_processor_with_provider(logger_provider, log_record_processor)
        if logger_provider.respond_to?(:add_log_record_processor)
          logger_provider.add_log_record_processor(log_record_processor)
        elsif logger_provider.respond_to?(:log_record_processors=)
          logger_provider.log_record_processors = [log_record_processor]
        else
          logger_provider.instance_variable_set(:@log_record_processors, [log_record_processor])
        end
      end

      def persist_logger_provider(logger_provider)
        begin
          ::OpenTelemetry::Logs.logger_provider = logger_provider
          Rails.logger.debug("[OpenTelemetry] Logger provider set via OpenTelemetry::Logs")
        rescue NoMethodError => e
          Rails.logger.warn("[OpenTelemetry] Cannot set logger_provider via OpenTelemetry::Logs: #{e.message}")
        end
        Decidim::Voca.opentelemetry_logger_provider = logger_provider
        Rails.logger.debug("[OpenTelemetry] Logger provider stored in Decidim::Voca")
      end

      def schedule_log_processor_flush(log_record_processor)
        return unless log_record_processor.respond_to?(:force_flush)

        at_exit { log_record_processor.force_flush(timeout: 5) }
      end

      def extend_rails_logger_with_otel
        if Rails.logger.is_a?(ActiveSupport::Logger)
          Rails.logger.extend(Decidim::Voca::OpenTelemetry::OtelLogger)
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
        extended_count = 0
        broadcasts.each do |broadcast_logger|
          if broadcast_logger.is_a?(ActiveSupport::Logger)
            broadcast_logger.extend(Decidim::Voca::OpenTelemetry::OtelLogger)
            extended_count += 1
          end
        end
        Rails.logger.debug { "[OpenTelemetry] Extended #{extended_count} logger(s) in BroadcastLogger" }
        extended_count.positive?
      end

      def log_setup_result(extended)
        if extended
          Rails.logger.info("[OpenTelemetry] Logging configured successfully")
        else
          Rails.logger.warn("[OpenTelemetry] Logger provider configured but Rails logger was not extended")
        end
      end

      def setup_error_reporting!
        Rails.error.subscribe(Decidim::Voca::OpenTelemetry::OtelErrorSubscriber.new) if defined?(Rails.error)
        Rails.logger.debug("[OpenTelemetry] Error reporting subscribed")
      end

      def verify_configuration!
        tracer = ::OpenTelemetry.tracer_provider.tracer("decidim-voca")
        span = tracer.start_span("opentelemetry.verification")
        span.set_attribute("verification.check", true)
        span.finish
        Rails.logger.info("[OpenTelemetry] Verification span created - tracer is active")
      rescue StandardError => e
        Rails.logger.warn("[OpenTelemetry] Verification failed: #{e.message}")
        # Don't raise - allow application to continue even if OTEL is misconfigured
        Rails.logger.warn("[OpenTelemetry] Continuing without telemetry - collector may be unavailable")
      end
    end
  end
end
