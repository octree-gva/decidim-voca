# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::AwesomeMenuLabelSync do
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
      var: "mobile_menu",
      value: [
        {
          "url" => "/pages/a-propos",
          "label" => { "en" => "About" },
          "position" => 1
        }
      ]
    )
  end

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "enqueues MachineTranslateAwesomeMenuLabelJob for pending locales" do
    expect do
      described_class.new(awesome_config).call
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob).with(
      awesome_config.id,
      "/pages/a-propos",
      "fr",
      "en"
    )
  end

  it "is a no-op for non-menu configs" do
    config = create(:awesome_config, organization:, var: "css", value: { "x" => 1 })

    expect do
      described_class.new(config).call
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob)
  end
end
