# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslation::TranslateString do
  before { stub_dummy_machine_translator }

  describe ".call" do
    it "uses Dev dummy format when DummyTranslator is configured" do
      expect(described_class.call(
               text: "Hello",
               source_locale: "en",
               target_locale: "fr",
               html: false,
               context: "ctx"
             )).to eq("fr - Hello")
    end

    it "returns nil when no translation service is configured" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(nil)
      expect(described_class.call(
               text: "Hello",
               source_locale: "en",
               target_locale: "fr",
               html: false,
               context: nil
             )).to be_nil
    end
  end
end
