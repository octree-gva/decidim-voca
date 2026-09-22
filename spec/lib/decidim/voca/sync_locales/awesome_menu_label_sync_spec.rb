# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::AwesomeMenuLabelSync do
  include ActiveJob::TestHelper

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "fr",
      enable_machine_translations: true,
      machine_translation_display_priority: "translation"
    )
  end
  let(:awesome_config) do
    create(
      :awesome_config,
      organization:,
      var: "menu",
      value: [
        {
          "url" => "/processes",
          "label" => { "fr" => "Démarches participatives" },
          "position" => 1
        }
      ]
    )
  end

  before do
    stub_dummy_machine_translator
    awesome_config
    clear_enqueued_jobs
  end

  it "populates machine_translations en from FR human source during sync" do
    described_class.new(awesome_config).call

    awesome_config.reload
    label = awesome_config.value.first["label"]
    expect(label["fr"]).to eq("Démarches participatives")
    expect(label.dig("machine_translations", "en")).to eq("en - Démarches participatives")
  end

  it "does not enqueue jobs (translates inline)" do
    expect do
      described_class.new(awesome_config).call
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob)
  end

  it "is a no-op for non-menu configs" do
    config = create(:awesome_config, organization:, var: "css", value: { "x" => 1 })

    expect { described_class.new(config).call }.not_to raise_error
  end
end
