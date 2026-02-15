# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe OpenTelemetryConfigurator do
      describe "#call" do
        context "when OpenTelemetry is disabled" do
          before { allow(Decidim::Voca).to receive(:opentelemetry_enabled?).and_return(false) }

          it "broadcasts :ok without configuring" do
            expect { described_class.call }.to broadcast(:ok)
          end

          it "does not call configure_opentelemetry!" do
            allow(described_class).to receive(:new).and_wrap_original do |m, *args, **kwargs|
              instance = m.call(*args, **kwargs)
              expect(instance).not_to receive(:configure_opentelemetry!)
              instance
            end
            described_class.call
          end
        end

        context "when OpenTelemetry is enabled" do
          before do
            allow(Decidim::Voca).to receive(:opentelemetry_enabled?).and_return(true)
            allow(Decidim::Voca).to receive(:opentelemetry_traces_endpoint).and_return("http://otel:4318/v1/traces")
            allow(Decidim::Voca).to receive(:opentelemetry_logs_endpoint).and_return("http://otel:4318/v1/logs")
          end

          it "broadcasts :ok when configuration succeeds" do
            # Stub SDK so we don't load real OpenTelemetry in test
            allow(described_class).to receive(:new).and_wrap_original do |m, *args, **kwargs|
              instance = m.call(*args, **kwargs)
              allow(instance).to receive(:require_opentelemetry!)
              allow(instance).to receive(:configure_sdk!)
              allow(instance).to receive(:verify_configuration!)
              instance
            end
            expect { described_class.call }.to broadcast(:ok)
          end

          it "broadcasts :invalid when configuration raises" do
            allow(described_class).to receive(:new).and_wrap_original do |m, *args, **kwargs|
              instance = m.call(*args, **kwargs)
              allow(instance).to receive(:require_opentelemetry!)
              allow(instance).to receive(:configure_sdk!).and_raise(StandardError.new("config failed"))
              instance
            end
            expect { described_class.call }.to broadcast(:invalid, "config failed")
          end
        end
      end
    end
  end
end
