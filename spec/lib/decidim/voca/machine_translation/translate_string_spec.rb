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

    it "does not treat Decidim::Voca::DeepL as the deepl-rb gem" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Voca::DeepL::MachineTranslator)
      allow(Decidim::Voca::Installation).to receive(:deepl_enabled?).and_return(true)
      hide_const("::DeepL")

      expect(described_class.call(
               text: "Hello",
               source_locale: "en",
               target_locale: "fr",
               html: false,
               context: nil
             )).to eq("Hello")
    end

    it "does not raise when Decidim::Dev is not loaded" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Voca::DeepL::MachineTranslator)
      allow(Decidim::Voca::Installation).to receive(:deepl_enabled?).and_return(true)
      hide_const("::DeepL")
      hide_const("Decidim::Dev")

      expect do
        described_class.call(
          text: "Hello",
          source_locale: "en",
          target_locale: "fr",
          html: false,
          context: nil
        )
      end.not_to raise_error
    end

    # Production html content-block: CSS background-image data URI alone exceeds DeepL byte gate.
    it "strips oversized CSS data URIs before the byte gate and restores them" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Voca::DeepL::MachineTranslator)
      allow(Decidim::Voca::Installation).to receive(:deepl_enabled?).and_return(true)
      hide_const("::DeepL")

      blob = "A" * 140_000
      html = %(<div class="banner" style="background-image: url('data:image/jpeg;base64,#{blob}');"><h2>Découvrez des expériences inspirantes</h2></div>)
      expect(html.bytesize).to be >= 131_000
      expect(described_class.translatable?(html)).to be(false)

      result = described_class.call(
        text: html,
        source_locale: "fr",
        target_locale: "en",
        html: true,
        context: nil
      )

      expect(result).not_to be_nil
      expect(result).to include("data:image/jpeg;base64,#{blob}")
      expect(result).to include("Découvrez des expériences inspirantes")
    end
  end
end
