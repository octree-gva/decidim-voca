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

      def configure_opentelemetry!
        require_opentelemetry!
        configure_sdk!
      end

      def require_opentelemetry!
        require "opentelemetry/sdk"
        require "opentelemetry/exporter/otlp"
        require "opentelemetry/instrumentation/all"
      end

      def configure_sdk!
        Rails.logger.debug("[OpenTelemetry] Configuring SDK...")
        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = service_name
          c.resource = resource
          c.use_all
          c.add_span_processor(span_processor)
        end
        Rails.logger.info("[OpenTelemetry] SDK configured successfully")
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

