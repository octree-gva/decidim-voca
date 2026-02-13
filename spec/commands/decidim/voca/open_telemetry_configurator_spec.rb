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
            expect_any_instance_of(described_class).not_to receive(:configure_opentelemetry!)
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
            allow_any_instance_of(described_class).to receive(:require_opentelemetry!)
            allow_any_instance_of(described_class).to receive(:configure_sdk!)
            allow_any_instance_of(described_class).to receive(:verify_configuration!)

            expect { described_class.call }.to broadcast(:ok)
          end

          it "broadcasts :invalid when configuration raises" do
            allow_any_instance_of(described_class).to receive(:require_opentelemetry!)
            allow_any_instance_of(described_class).to receive(:configure_sdk!).and_raise(StandardError.new("config failed"))

            expect { described_class.call }.to broadcast(:invalid, "config failed")
          end
        end
      end
    end
  end
end
