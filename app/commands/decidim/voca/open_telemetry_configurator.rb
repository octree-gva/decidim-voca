# frozen_string_literal: true

module Decidim
  module Voca
    ##
    # Configures OpenTelemetry for Decidim Voca
    class OpenTelemetryConfigurator < Decidim::Command
      def call
        return broadcast(:ok) unless Decidim::Voca.opentelemetry_enabled?

        configure_opentelemetry!
        broadcast(:ok)
      rescue StandardError => e
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
        OpenTelemetry::SDK.configure do |c|
          c.service_name = service_name
          c.resource = resource
          c.use_all
          c.add_span_processor(span_processor)
        end
      end

      def service_name
        ENV.fetch("MASTER_ID", ENV.fetch("OTEL_SERVICE_NAME", "rails-app")).to_s
      end

      def resource
        OpenTelemetry::SDK::Resources::Resource.create(
          "deployment.environment" => Rails.env.to_s,
          "service.version" => Decidim.version.to_s,
          "host.name" => host_name
        )
      end

      def host_name
        ENV.fetch("MASTER_HOST", ENV.fetch("MASTER_IP", "unknown")).to_s
      end

      def span_processor
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: traces_endpoint
          )
        )
      end
    end
  end
end

