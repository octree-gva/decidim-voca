# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    module OpenTelemetry
      describe RequestEnv do
        describe ".from_request_object" do
          it "returns env when request responds to :env" do
            env = { "rack.input" => nil }
            request = double("request", env: env)
            expect(described_class.from_request_object(request)).to eq(env)
          end

          it "returns nil when request is nil" do
            expect(described_class.from_request_object(nil)).to be_nil
          end

          it "returns nil when request does not respond to :env" do
            expect(described_class.from_request_object(Object.new)).to be_nil
          end
        end

        describe ".from_context" do
          it "returns context[:request].env when context has request" do
            env = { "PATH_INFO" => "/" }
            request = double("request", env: env)
            expect(described_class.from_context({ request: request })).to eq(env)
          end

          it "returns context[:env] when it is a Hash" do
            env = { "rack.input" => nil }
            expect(described_class.from_context({ env: env })).to eq(env)
          end

          it "falls back to from_current when context has no request or env" do
            allow(described_class).to receive(:from_current).and_return(nil)
            expect(described_class.from_context({})).to be_nil
          end
        end
      end
    end
  end
end
