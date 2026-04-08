# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    module OpenTelemetry
      describe LoggerProviderResolver do
        describe ".current" do
          it "returns Decidim::Voca.opentelemetry_logger_provider" do
            provider = double("logger_provider")
            allow(Decidim::Voca).to receive(:opentelemetry_logger_provider).and_return(provider)

            expect(described_class.current).to eq(provider)
          end

          it "returns nil when Decidim::Voca has no logger provider set" do
            allow(Decidim::Voca).to receive(:opentelemetry_logger_provider).and_return(nil)

            expect(described_class.current).to be_nil
          end
        end
      end
    end
  end
end
