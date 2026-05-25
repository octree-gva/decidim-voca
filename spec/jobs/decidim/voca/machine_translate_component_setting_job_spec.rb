# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslateComponentSettingJob do
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
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:settings_hash) do
    {
      "global" => {
        "dummy_global_translatable_text" => {
          "en" => "<p>Hello world</p>"
        }
      }
    }
  end
  let(:component) do
    create(:component, participatory_space: participatory_process).tap do |c|
      # rubocop:disable Rails/SkipsModelValidations -- fixture JSONB shape for job under test
      c.update_column(:settings, settings_hash)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  before { stub_dummy_machine_translator }

  describe "#perform" do
    it "merges machine_translations for the target locale under settings global key" do
      described_class.perform_now(
        component.id,
        "dummy_global_translatable_text",
        "fr",
        "en",
        html: true
      )

      component.reload
      nested = component.read_attribute(:settings).dig("global", "dummy_global_translatable_text")
      expect(nested["machine_translations"]["fr"]).to eq("fr - <p>Hello world</p>")
      expect(nested["en"]).to eq("<p>Hello world</p>")
    end

    it "does nothing when source text is blank" do
      # rubocop:disable Rails/SkipsModelValidations -- set invalid source for job branch
      component.update_column(:settings, { "global" => { "dummy_global_translatable_text" => { "en" => "" } } })
      # rubocop:enable Rails/SkipsModelValidations

      described_class.perform_now(component.id, "dummy_global_translatable_text", "fr", "en", html: true)

      component.reload
      expect(component.read_attribute(:settings).dig("global", "dummy_global_translatable_text", "machine_translations")).to be_nil
    end
  end
end
