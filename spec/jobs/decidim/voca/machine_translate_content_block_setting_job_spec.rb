# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslateContentBlockSettingJob do
  include ActiveJob::TestHelper

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "fr",
      enable_machine_translations: true
    )
  end
  let(:content_block) do
    create(:content_block, organization:, scope_name: :homepage, manifest_name: :hero).tap do |block|
      set_jsonb_column(block, :settings, { "welcome_text_fr" => "Bonjour" })
    end
  end

  before { stub_dummy_machine_translator }

  describe "#perform" do
    it "writes flat welcome_text_en for the target locale" do
      described_class.perform_now(content_block.id, "welcome_text", "en", "fr", html: false)

      content_block.reload
      settings = content_block.read_attribute(:settings)
      expect(settings["welcome_text_fr"]).to eq("Bonjour")
      expect(settings["welcome_text_en"]).to eq("en - Bonjour")
      expect(settings).not_to have_key("welcome_text")
    end

    it "does nothing when source text is blank" do
      set_jsonb_column(content_block, :settings, { "welcome_text_fr" => "" })

      described_class.perform_now(content_block.id, "welcome_text", "en", "fr", html: false)

      content_block.reload
      expect(content_block.read_attribute(:settings)["welcome_text_en"]).to be_nil
    end
  end
end
