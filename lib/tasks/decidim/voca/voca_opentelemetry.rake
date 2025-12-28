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

        # Check error subscriber registration
        puts
        puts "Testing error reporting integration..."
        begin
          if defined?(Rails.error)
            subscribers = Rails.error.instance_variable_get(:@subscribers) || []
            otel_subscriber = subscribers.find { |s| s.is_a?(Decidim::Voca::OpenTelemetry::OtelErrorSubscriber) }
            if otel_subscriber
              puts "✓ Error subscriber registered"
            else
              puts "⚠ Error subscriber not found in Rails.error subscribers"
              puts "  Subscribers: #{subscribers.map(&:class).join(', ')}"
            end
          else
            puts "⚠ Rails.error not available (Rails < 7.0)"
          end
        rescue StandardError => e
          puts "⚠ Could not check error subscriber: #{e.message}"
        end

        # Test error reporting
        begin
          if defined?(Rails.error)
            test_error = StandardError.new("Test error for OpenTelemetry integration test")
            Rails.error.report(test_error, handled: false, severity: :error, context: { source: "rake_test" })
            puts "✓ Error reported via Rails.error"
            puts "  Check SigNoz for error trace with message: 'Test error for OpenTelemetry integration test'"
          end
        rescue StandardError => e
          puts "⚠ Error reporting test failed: #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
        end

        # Test logs configuration
        puts
        puts "Testing logs configuration..."
        begin
          logs_endpoint = Decidim::Voca.opentelemetry_logs_endpoint
          if logs_endpoint.present?
            puts "✓ Logs endpoint: #{logs_endpoint}"
          else
            puts "⚠ Logs endpoint not configured"
            puts "  Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT or OTEL_EXPORTER_OTLP_ENDPOINT"
          end

          if defined?(::OpenTelemetry::SDK::Logs::LoggerProvider)
            puts "✓ Logs SDK available"
          else
            puts "✗ Logs SDK not available"
            puts "  Add 'opentelemetry-logs-sdk' to Gemfile"
          end

          # Check logger provider - try both OpenTelemetry::Logs and our stored version
          logger_provider = nil
          if defined?(::OpenTelemetry::Logs)
            begin
              if ::OpenTelemetry::Logs.respond_to?(:logger_provider)
                logger_provider = ::OpenTelemetry::Logs.logger_provider
                if logger_provider
                  puts "✓ Logger provider configured (via OpenTelemetry::Logs): #{logger_provider.class}"
                end
              else
                puts "⚠ OpenTelemetry::Logs.logger_provider getter not available (Ruby logs SDK limitation)"
              end
            rescue NoMethodError => e
              puts "⚠ Cannot access logger_provider via OpenTelemetry::Logs: #{e.message}"
            end
          else
            puts "⚠ OpenTelemetry::Logs not available"
          end
          
          # Check our stored logger provider
          stored_provider = Decidim::Voca.opentelemetry_logger_provider
          if stored_provider
            puts "✓ Logger provider configured (stored in Decidim::Voca): #{stored_provider.class}"
            logger_provider ||= stored_provider
          elsif !logger_provider
            puts "⚠ Logger provider not configured"
            puts "  Check that setup_logging! was called in the initializer"
            puts "  Check application logs for '[OpenTelemetry]' messages"
          end

          # Check if Rails logger is extended
          if Rails.logger.is_a?(ActiveSupport::Logger)
            if Rails.logger.singleton_class.included_modules.include?(Decidim::Voca::OpenTelemetry::OtelLogger)
              puts "✓ Rails logger extended with OtelLogger"
            else
              puts "⚠ Rails logger not extended with OtelLogger"
            end
          elsif Rails.logger.respond_to?(:broadcast)
            broadcasts = Rails.logger.instance_variable_get(:@broadcasts) || []
            extended_count = broadcasts.count { |b| b.singleton_class.included_modules.include?(Decidim::Voca::OpenTelemetry::OtelLogger) }
            if extended_count > 0
              puts "✓ Rails logger (BroadcastLogger) extended: #{extended_count}/#{broadcasts.length} loggers"
            else
              puts "⚠ Rails logger (BroadcastLogger) not extended with OtelLogger"
            end
          end

          # Test sending a log record
          test_logger_provider = logger_provider || Decidim::Voca.opentelemetry_logger_provider
          if test_logger_provider
            puts
            puts "Sending test log record..."
            begin
              logger = test_logger_provider.logger(name: "decidim-voca-test")
              
              # Use on_emit method (not emit) - this is the correct API per source code
              logger.on_emit(
                timestamp: Time.now,
                severity_number: 9, # INFO
                severity_text: "INFO",
                body: "Test log message from rake task - #{Time.now.iso8601}",
                attributes: {
                  "test.source" => "rake_task",
                  "test.timestamp" => Time.now.to_i
                }
              )
              
              # Flush log record processors
              if Decidim::Voca.opentelemetry_flush_logs(timeout: 5)
                puts "✓ Flushed log record processors"
              else
                puts "⚠ Could not flush processors"
              end
              
              puts "✓ Test log record sent"
              puts "  Check SigNoz for log with message: 'Test log message from rake task'"
            rescue StandardError => e
              puts "✗ Failed to send log record: #{e.class} - #{e.message}"
              puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
            end
          end

          # Test Rails logger integration
          if test_logger_provider
            puts
            puts "Testing Rails logger integration..."
            begin
              Rails.logger.info("[OpenTelemetry Test] Test log from Rails.logger - #{Time.now.iso8601}")
              
              # Flush log record processors
              Decidim::Voca.opentelemetry_flush_logs(timeout: 5)
              
              puts "✓ Test log sent via Rails.logger.info"
              puts "  Check SigNoz for log with message containing '[OpenTelemetry Test]'"
            rescue StandardError => e
              puts "⚠ Rails logger test failed: #{e.message}"
            end
          end
        rescue StandardError => e
          puts "⚠ Logs configuration test failed: #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
        end

        # Check middleware registration
        begin
          middleware_stack = Rails.application.config.middleware
          middlewares = middleware_stack.instance_variable_get(:@middlewares) || []
          otel_middleware = middlewares.find do |m|
            m.klass == Decidim::Voca::OpenTelemetry::OtelDecidimContext ||
              (m.respond_to?(:klass) && m.klass.to_s == "Decidim::Voca::OpenTelemetry::OtelDecidimContext")
          end
          if otel_middleware
            puts "✓ OtelDecidimContext middleware registered"
          else
            # Try alternative check
            middleware_names = middlewares.map { |m| m.respond_to?(:klass) ? m.klass.to_s : m.to_s }
            if middleware_names.any? { |name| name.include?("OtelDecidimContext") }
              puts "✓ OtelDecidimContext middleware registered (found by name)"
            else
              puts "⚠ OtelDecidimContext middleware not found in stack"
              puts "  Middleware count: #{middlewares.length}"
            end
          end
        rescue StandardError => e
          puts "⚠ Could not check middleware: #{e.message}"
        end

        puts
        puts "=== Summary ==="
        puts "Configuration looks correct. Check your logs for [OpenTelemetry] messages."
        puts "If traces still don't appear in SigNoz:"
        puts "  1. Verify endpoint is reachable: curl #{endpoint}"
        puts "  2. Check network connectivity to SigNoz/OTLP collector"
        puts "  3. Review application logs for OpenTelemetry errors"
        puts "  4. Verify OTLP collector is running and configured correctly"
        puts "If logs still don't appear in SigNoz:"
        puts "  1. Verify logs endpoint is configured: #{Decidim::Voca.opentelemetry_logs_endpoint || '(not set)'}"
        puts "  2. Ensure opentelemetry-logs-sdk gem is installed"
        puts "  3. Check that logger provider is configured in initializer"
        puts "  4. Verify Rails logger is extended with OtelLogger"
      end

      desc "Show OpenTelemetry configuration"
      task config: :environment do
        puts "=== OpenTelemetry Configuration ==="
        puts
        puts "Enabled: #{Decidim::Voca.opentelemetry_enabled?}"
        puts "Traces endpoint: #{Decidim::Voca.opentelemetry_traces_endpoint}"
        puts "Logs endpoint: #{Decidim::Voca.opentelemetry_logs_endpoint || '(not set)'}"
        puts "Service name: #{ENV.fetch('MASTER_ID', ENV.fetch('OTEL_SERVICE_NAME', 'rails-app'))}"
        puts "Host name: #{ENV.fetch('MASTER_HOST', ENV.fetch('MASTER_IP', 'unknown'))}"
        puts
        puts "OpenTelemetry SDK status:"
        puts "  SDK loaded: #{defined?(::OpenTelemetry::SDK)}"
        puts "  Logs SDK loaded: #{defined?(::OpenTelemetry::SDK::Logs)}"
        stored_provider = Decidim::Voca.opentelemetry_logger_provider
        otel_provider = if defined?(::OpenTelemetry::Logs) && ::OpenTelemetry::Logs.respond_to?(:logger_provider)
                          ::OpenTelemetry::Logs.logger_provider
                        end
        logger_provider_status = if stored_provider || otel_provider
                                  'configured'
                                elsif defined?(::OpenTelemetry::Logs) && !::OpenTelemetry::Logs.respond_to?(:logger_provider)
                                  'method not available (Ruby SDK limitation)'
                                else
                                  'not configured'
                                end
        puts "  Logger provider: #{logger_provider_status}"
        puts
        puts "Environment variables:"
        puts "  OTEL_EXPORTER_OTLP_ENDPOINT: #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] || '(not set)'}"
        puts "  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: #{ENV['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] || '(not set)'}"
        puts "  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT: #{ENV['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'] || '(not set)'}"
        puts "  OTEL_SERVICE_NAME: #{ENV['OTEL_SERVICE_NAME'] || '(not set)'}"
        puts "  MASTER_ID: #{ENV['MASTER_ID'] || '(not set)'}"
        puts "  MASTER_HOST: #{ENV['MASTER_HOST'] || '(not set)'}"
        puts "  MASTER_IP: #{ENV['MASTER_IP'] || '(not set)'}"
      end
    end
  end
end

