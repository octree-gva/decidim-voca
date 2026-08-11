# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::AwesomeMenuLabelMachineTranslation do
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
  let(:menu_value) do
    [
      {
        "url" => "/processes",
        "label" => { "en" => "first" },
        "position" => 1
      }
    ]
  end
  let(:awesome_config) do
    create(:awesome_config, organization:, var: "menu", value: menu_value)
  end

  before do
    Decidim::Voca::DeepL::EngineConfig.apply_mergeable_fields!
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "enqueues MachineTranslateAwesomeMenuLabelJob when default locale label changes" do
    awesome_config
    clear_enqueued_jobs

    new_value = [
      {
        "url" => "/processes",
        "label" => { "en" => "second" },
        "position" => 1
      }
    ]

    expect do
      awesome_config.update!(value: new_value)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob).with(
      awesome_config.id,
      "/processes",
      "fr",
      "en"
    )
  end

  it "does not enqueue for non-menu config values" do
    config = create(:awesome_config, organization:, var: "styles", value: { "color" => "red" })
    clear_enqueued_jobs

    expect do
      config.update!(value: { "color" => "blue" })
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob)
  end
end
