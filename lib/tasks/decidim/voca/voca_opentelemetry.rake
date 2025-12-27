# frozen_string_literal: true

namespace :decidim do
  namespace :voca do
    namespace :opentelemetry do
      desc "Test OpenTelemetry configuration and send a test span"
      task test: :environment do
        puts "=== OpenTelemetry Debugging ==="
        puts

        # Check if enabled
        enabled = Decidim::Voca.opentelemetry_enabled?
        puts "✓ Enabled: #{enabled}"
        unless enabled
          puts "  Reason: opentelemetry_enabled? returned false"
          puts "  Check: OTEL_EXPORTER_OTLP_ENDPOINT or OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
          exit 1
        end

        # Check endpoint
        endpoint = Decidim::Voca.opentelemetry_traces_endpoint
        puts "✓ Traces endpoint: #{endpoint}"

        # Check if OpenTelemetry is defined
        if defined?(::OpenTelemetry)
          puts "✓ OpenTelemetry gem loaded"
        else
          puts "✗ OpenTelemetry gem not loaded"
          puts "  Add 'opentelemetry-sdk' and 'opentelemetry-exporter-otlp' to Gemfile"
          exit 1
        end

        # Check SDK configuration
        begin
          tracer_provider = ::OpenTelemetry.tracer_provider
          puts "✓ Tracer provider available: #{tracer_provider.class}"
        rescue StandardError => e
          puts "✗ Tracer provider error: #{e.message}"
          exit 1
        end

        # Create a test span
        puts
        puts "Creating test span..."
        begin
          tracer = ::OpenTelemetry.tracer_provider.tracer("decidim-voca-test")
          span = tracer.start_span("test.span") do |s|
            s.set_attribute("test.attribute", "test_value")
            s.set_attribute("test.timestamp", Time.now.to_i)
            puts "✓ Test span created and finished"
          end
          puts "✓ Span sent to exporter"
        rescue StandardError => e
          puts "✗ Failed to create span: #{e.class} - #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
          exit 1
        end

        # Check span processor
        begin
          span_processors = ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
          if span_processors&.any?
            puts "✓ Span processors configured: #{span_processors.length}"
            span_processors.each_with_index do |processor, i|
              puts "  [#{i + 1}] #{processor.class}"
            end
          else
            puts "⚠ No span processors found"
          end
        rescue StandardError => e
          puts "⚠ Could not inspect span processors: #{e.message}"
        end

        puts
        puts "=== Summary ==="
        puts "Configuration looks correct. Check your logs for [OpenTelemetry] messages."
        puts "If traces still don't appear in SigNoz:"
        puts "  1. Verify endpoint is reachable: curl #{endpoint}"
        puts "  2. Check network connectivity to SigNoz/OTLP collector"
        puts "  3. Review application logs for OpenTelemetry errors"
        puts "  4. Verify OTLP collector is running and configured correctly"
      end

      desc "Show OpenTelemetry configuration"
      task config: :environment do
        puts "=== OpenTelemetry Configuration ==="
        puts
        puts "Enabled: #{Decidim::Voca.opentelemetry_enabled?}"
        puts "Traces endpoint: #{Decidim::Voca.opentelemetry_traces_endpoint}"
        puts "Service name: #{ENV.fetch('MASTER_ID', ENV.fetch('OTEL_SERVICE_NAME', 'rails-app'))}"
        puts "Host name: #{ENV.fetch('MASTER_HOST', ENV.fetch('MASTER_IP', 'unknown'))}"
        puts
        puts "Environment variables:"
        puts "  OTEL_EXPORTER_OTLP_ENDPOINT: #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] || '(not set)'}"
        puts "  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: #{ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] || '(not set)'}"
        puts "  OTEL_SERVICE_NAME: #{ENV['OTEL_SERVICE_NAME'] || '(not set)'}"
        puts "  MASTER_ID: #{ENV['MASTER_ID'] || '(not set)'}"
        puts "  MASTER_HOST: #{ENV['MASTER_HOST'] || '(not set)'}"
        puts "  MASTER_IP: #{ENV['MASTER_IP'] || '(not set)'}"
      end
    end
  end
end

