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
          Rails.logger.debug("[OpenTelemetry] Logs SDK not available - logs will be disabled: #{e.message}")
        end
        
        begin
          require "opentelemetry/exporter/otlp/logs"
        rescue LoadError => e
          Rails.logger.warn("[OpenTelemetry] OTLP logs exporter not available: #{e.message}")
          Rails.logger.warn("[OpenTelemetry] Add 'opentelemetry-exporter-otlp-logs' to Gemfile")
        end
      end

      def configure_sdk!
        Rails.logger.debug("[OpenTelemetry] Configuring SDK...")
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

      def span_processor
        ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          ::OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: traces_endpoint
          )
        )
      end

      def setup_logging!
        unless logs_endpoint.present?
          Rails.logger.debug("[OpenTelemetry] Logs endpoint not configured - skipping logs setup")
          Rails.logger.debug("[OpenTelemetry] Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT or OTEL_EXPORTER_OTLP_ENDPOINT")
          return
        end

        unless defined?(::OpenTelemetry::SDK::Logs::LoggerProvider)
          Rails.logger.debug("[OpenTelemetry] Logs SDK not available - skipping logs setup")
          return
        end

        Rails.logger.debug("[OpenTelemetry] Configuring logging...")
        Rails.logger.debug("[OpenTelemetry] Logs endpoint: #{logs_endpoint}")
        
        begin
          # Ensure environment variables are set for OTLP exporter auto-configuration
          # See: https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/
          # The exporter should read from OTEL_EXPORTER_OTLP_LOGS_ENDPOINT automatically
          unless ENV["OTEL_EXPORTER_OTLP_LOGS_ENDPOINT"]
            ENV["OTEL_EXPORTER_OTLP_LOGS_ENDPOINT"] = logs_endpoint
            Rails.logger.debug("[OpenTelemetry] Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=#{logs_endpoint}")
          end
          
          # Create OTLP exporter for logs
          # Use logs-specific exporter if available, otherwise fall back to generic
          logs_exporter = if defined?(::OpenTelemetry::Exporter::OTLP::Logs::Exporter)
            # Logs-specific exporter - should auto-read from ENV, but pass endpoint explicitly to be sure
            begin
              ::OpenTelemetry::Exporter::OTLP::Logs::Exporter.new(
                endpoint: logs_endpoint,
                headers: {}
              )
            rescue ArgumentError
              # If it doesn't accept endpoint, try without (it should read from ENV)
              ::OpenTelemetry::Exporter::OTLP::Logs::Exporter.new
            end
          elsif defined?(::OpenTelemetry::Exporter::OTLP::Exporter)
            # Fallback to generic exporter with explicit endpoint
            ::OpenTelemetry::Exporter::OTLP::Exporter.new(
              endpoint: logs_endpoint,
              headers: {}
            )
          else
            Rails.logger.error("[OpenTelemetry] No OTLP exporter available for logs")
            return
          end
          
          Rails.logger.debug("[OpenTelemetry] Created logs exporter: #{logs_exporter.class}")
          
          # Use SimpleLogRecordProcessor for immediate sending instead of batching
          # This ensures logs are sent immediately rather than waiting for batch flush
          log_record_processor = if defined?(::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor)
            ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(logs_exporter)
          else
            # Fallback to batch processor if simple doesn't exist
            batch_processor = ::OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(logs_exporter)
            # Force flush on shutdown
            at_exit { batch_processor.force_flush(timeout: 5) if batch_processor.respond_to?(:force_flush) }
            batch_processor
          end
          
          # LoggerProvider uses .new with just resource, then add processors
          logger_provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: resource)
          
          # Add log record processor - check if there's an add method or setter
          if logger_provider.respond_to?(:add_log_record_processor)
            logger_provider.add_log_record_processor(log_record_processor)
          elsif logger_provider.respond_to?(:log_record_processors=)
            logger_provider.log_record_processors = [log_record_processor]
          else
            # Try to set via instance variable as fallback
            logger_provider.instance_variable_set(:@log_record_processors, [log_record_processor])
          end
          
          # Store logger provider ourselves since OpenTelemetry::Logs.logger_provider getter
          # may not be available in Ruby SDK (logs support is incomplete)
          begin
            ::OpenTelemetry::Logs.logger_provider = logger_provider
            Rails.logger.debug("[OpenTelemetry] Logger provider set via OpenTelemetry::Logs")
          rescue NoMethodError => e
            Rails.logger.warn("[OpenTelemetry] Cannot set logger_provider via OpenTelemetry::Logs: #{e.message}")
            Rails.logger.warn("[OpenTelemetry] This is expected - Ruby OpenTelemetry logs SDK is incomplete")
          end
          
          # Store in our module for access
          Decidim::Voca.opentelemetry_logger_provider = logger_provider
          Rails.logger.debug("[OpenTelemetry] Logger provider stored in Decidim::Voca")
          
          # Ensure batch processor flushes on shutdown
          if log_record_processor.respond_to?(:force_flush)
            at_exit { log_record_processor.force_flush(timeout: 5) }
          end

          # Extend Rails logger to also send to OpenTelemetry
          # Handle both regular Logger and BroadcastLogger
          extended = false
          if Rails.logger.is_a?(ActiveSupport::Logger)
            Rails.logger.extend(Decidim::Voca::OpenTelemetry::OtelLogger)
            extended = true
            Rails.logger.debug("[OpenTelemetry] Extended Rails.logger with OtelLogger")
          elsif Rails.logger.respond_to?(:broadcast)
            # For BroadcastLogger, extend each logger in the broadcast chain
            broadcasts = Rails.logger.instance_variable_get(:@broadcasts) || []
            broadcasts.each do |broadcast_logger|
              if broadcast_logger.is_a?(ActiveSupport::Logger)
                broadcast_logger.extend(Decidim::Voca::OpenTelemetry::OtelLogger)
                extended = true
              end
            end
            Rails.logger.debug("[OpenTelemetry] Extended #{broadcasts.count { |b| b.is_a?(ActiveSupport::Logger) }} logger(s) in BroadcastLogger")
          else
            Rails.logger.warn("[OpenTelemetry] Rails.logger is #{Rails.logger.class} - cannot extend with OtelLogger")
          end

          if extended
            Rails.logger.info("[OpenTelemetry] Logging configured successfully")
          else
            Rails.logger.warn("[OpenTelemetry] Logger provider configured but Rails logger was not extended")
          end
        rescue StandardError => e
          Rails.logger.error("[OpenTelemetry] Failed to configure logging: #{e.class} - #{e.message}")
          Rails.logger.error("[OpenTelemetry] Backtrace: #{e.backtrace.first(5).join("\n")}")
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
        raise
      end
    end
  end
end

