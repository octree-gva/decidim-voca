# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::Export::CsvWithLocaleTransformer do
  describe ".value_for_locale" do
    it "returns top-level locale value" do
      h = { "en" => "Hello", "fr" => "Bonjour" }
      expect(described_class.value_for_locale(h, "fr")).to eq("Bonjour")
    end

    it "falls back to machine_translations" do
      h = { "ar" => "مرحبا", "machine_translations" => { "en" => "MT-en" } }
      expect(described_class.value_for_locale(h, "en")).to eq("MT-en")
    end

    it "prefers top-level value over machine_translations for the same locale (legacy installs)" do
      h = { "machine_translations" => { "en" => "MT-en" }, "en" => "human-en" }
      expect(described_class.value_for_locale(h, "en")).to eq("human-en")
    end

    it "returns blank string when missing" do
      expect(described_class.value_for_locale({ "en" => "x" }, "fr")).to eq("")
    end
  end

  describe ".human_source_locale_from" do
    it "returns first non-blank top-level locale excluding machine_translations" do
      h = { "machine_translations" => { "en" => "x" }, "ar" => "orig" }
      expect(described_class.human_source_locale_from(h)).to eq("ar")
    end

    it "prefers top-level locale over machine_translations for the same locale (legacy installs)" do
      h = { "machine_translations" => { "en" => "x" }, "en" => "orig" }
      expect(described_class.human_source_locale_from(h)).to eq("en")
    end

    it "returns nil when only machine_translations has content" do
      h = { "machine_translations" => { "en" => "x" } }
      expect(described_class.human_source_locale_from(h)).to be_nil
    end
  end

  describe ".columns_for_locales" do
    it "builds locale => field => value map" do
      out = described_class.columns_for_locales(
        %w(en fr),
        "title" => { "en" => "T-en", "fr" => "T-fr" },
        "body" => { "en" => "B-en" }
      )
      expect(out["en"]).to eq("title" => "T-en", "body" => "B-en")
      expect(out["fr"]).to eq("title" => "T-fr", "body" => "")
    end
  end
end
