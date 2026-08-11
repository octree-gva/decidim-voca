# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslateContentBlockSettingJob do
  include ActiveJob::TestHelper

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:content_block) do
    create(:content_block, organization:, scope_name: :homepage, manifest_name: :hero).tap do |block|
      set_jsonb_column(block, :settings, { "welcome_text" => { "en" => "Hello world" } })
    end
  end

  before { stub_dummy_machine_translator }

  describe "#perform" do
    it "merges machine_translations for the target locale under welcome_text" do
      described_class.perform_now(content_block.id, "welcome_text", "fr", "en", html: false)

      content_block.reload
      nested = content_block.read_attribute(:settings)["welcome_text"]
      expect(nested["machine_translations"]["fr"]).to eq("fr - Hello world")
      expect(nested["en"]).to eq("Hello world")
    end

    it "coalesces flat welcome_text_en keys before translating" do
      set_jsonb_column(content_block, :settings, { "welcome_text_en" => "Flat hello" })

      described_class.perform_now(content_block.id, "welcome_text", "fr", "en", html: false)

      content_block.reload
      nested = content_block.read_attribute(:settings)["welcome_text"]
      expect(nested["en"]).to eq("Flat hello")
      expect(nested["machine_translations"]["fr"]).to eq("fr - Flat hello")
      expect(content_block.read_attribute(:settings)).not_to have_key("welcome_text_en")
    end

    it "does nothing when source text is blank" do
      set_jsonb_column(content_block, :settings, { "welcome_text" => { "en" => "" } })

      described_class.perform_now(content_block.id, "welcome_text", "fr", "en", html: false)

      content_block.reload
      expect(content_block.read_attribute(:settings).dig("welcome_text", "machine_translations")).to be_nil
    end
  end
end
