# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslationHumanSource do
  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr es),
      default_locale: "en"
    )
  end

  describe ".authoring_locale" do
    it "returns default when that slot has text" do
      expect(described_class.authoring_locale(organization, { "en" => "Hi", "fr" => "Salut" }, "fr")).to eq("en")
    end

    it "returns job locale when default is blank and that slot has text" do
      expect(described_class.authoring_locale(organization, { "fr" => "Salut" }, "fr")).to eq("fr")
    end

    it "returns first filled locale in organization order when default and job locale are blank in the hash" do
      expect(described_class.authoring_locale(organization, { "es" => "Hola" }, "en")).to eq("es")
    end

    it "returns nil when organization is nil" do
      expect(described_class.authoring_locale(nil, { "fr" => "x" }, "fr")).to be_nil
    end
  end
end
