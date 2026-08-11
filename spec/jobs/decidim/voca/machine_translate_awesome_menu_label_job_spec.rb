# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslateAwesomeMenuLabelJob do
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
  let(:awesome_config) do
    create(
      :awesome_config,
      organization:,
      var: "menu",
      value: [
        {
          "url" => "/about",
          "label" => { "en" => "About us" },
          "position" => 2
        }
      ]
    )
  end

  before { stub_dummy_machine_translator }

  describe "#perform" do
    it "merges machine_translations under the matching item label" do
      described_class.perform_now(awesome_config.id, "/about", "fr", "en")

      awesome_config.reload
      label = awesome_config.value.first["label"]
      expect(label["machine_translations"]["fr"]).to eq("fr - About us")
      expect(label["en"]).to eq("About us")
    end

    it "does nothing when source text is blank" do
      awesome_config.update_column(
        :value,
        [{ "url" => "/about", "label" => { "en" => "" }, "position" => 2 }]
      )

      described_class.perform_now(awesome_config.id, "/about", "fr", "en")

      awesome_config.reload
      expect(awesome_config.value.first["label"]["machine_translations"]).to be_nil
    end
  end
end
