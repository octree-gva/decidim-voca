# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    module OpenTelemetry
      describe OtelLogger do
        # Test the module via a class that includes it and exposes the private helpers
        let(:test_class) do
          Class.new do
            include OtelLogger
            public :message_to_string, :severity_to_number, :severity_to_text, :low_severity?, :otel_severity_pair
          end
        end
        let(:subject) { test_class.new }

        describe "#message_to_string" do
          it "returns the string when msg is a String" do
            expect(subject.message_to_string("hello")).to eq("hello")
          end

          it "returns nil when msg is nil" do
            expect(subject.message_to_string(nil)).to be_nil
          end

          it "returns msg.to_s when msg responds to :to_s" do
            obj = double("obj", to_s: "stringified")
            expect(subject.message_to_string(obj)).to eq("stringified")
          end

          it "returns msg.inspect otherwise" do
            expect(subject.message_to_string(42)).to eq("42")
          end
        end

        describe "#low_severity?" do
          it "returns true for DEBUG and INFO" do
            expect(subject.low_severity?(0)).to be true
            expect(subject.low_severity?(1)).to be true
            expect(subject.low_severity?("DEBUG")).to be true
            expect(subject.low_severity?("INFO")).to be true
          end

          it "returns false for WARN and ERROR" do
            expect(subject.low_severity?("WARN")).to be false
            expect(subject.low_severity?("ERROR")).to be false
          end
        end

        describe "#severity_to_number" do
          it "returns OTel severity number for known severities" do
            expect(subject.severity_to_number("DEBUG")).to eq(5)
            expect(subject.severity_to_number("INFO")).to eq(9)
            expect(subject.severity_to_number("WARN")).to eq(13)
            expect(subject.severity_to_number("ERROR")).to eq(17)
            expect(subject.severity_to_number("FATAL")).to eq(21)
          end

          it "returns 9 (INFO) for unknown severity" do
            expect(subject.severity_to_number("UNKNOWN")).to eq(9)
          end
        end

        describe "#severity_to_text" do
          it "returns OTel severity text for known severities" do
            expect(subject.severity_to_text("WARN")).to eq("WARN")
            expect(subject.severity_to_text("ERROR")).to eq("ERROR")
          end

          it "returns INFO for unknown severity" do
            expect(subject.severity_to_text("UNKNOWN")).to eq("INFO")
          end
        end
      end
    end
  end
end
