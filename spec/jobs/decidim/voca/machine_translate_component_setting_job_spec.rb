# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslateComponentSettingJob, type: :job do
  include ActiveJob::TestHelper

  let(:organization) do
    create(
      :organization,
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
      c.update_column(:settings, settings_hash)
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

    it "does nothing when the component is missing" do
      expect do
        described_class.perform_now(-1, "dummy_global_translatable_text", "fr", "en", html: true)
      end.not_to raise_error
    end

    it "does nothing when source text is blank" do
      component.update_column(:settings, { "global" => { "dummy_global_translatable_text" => { "en" => "" } } })

      described_class.perform_now(component.id, "dummy_global_translatable_text", "fr", "en", html: true)

      component.reload
      expect(component.read_attribute(:settings).dig("global", "dummy_global_translatable_text", "machine_translations")).to be_nil
    end
  end
end
