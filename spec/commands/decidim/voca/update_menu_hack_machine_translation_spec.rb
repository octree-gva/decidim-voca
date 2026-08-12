# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::DecidimAwesome::Admin::UpdateMenuHack do
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
  let(:awesome_config) do
    create(
      :awesome_config,
      organization:,
      var: "menu",
      value: [
        {
          "url" => "/",
          "label" => { "fr" => "Accueil", "en" => "" },
          "position" => 1,
          "visibility" => "default",
          "target" => ""
        }
      ]
    )
  end
  let(:form) do
    Decidim::DecidimAwesome::Admin::MenuForm.from_params(
      url: "/",
      position: 1,
      visibility: "default",
      target: "",
      raw_label_fr: "Démarches participatives",
      raw_label_en: ""
    ).with_context(current_organization: organization)
  end

  before do
    Decidim::Voca::DeepL::EngineConfig.apply_mergeable_fields!
    stub_dummy_machine_translator
    awesome_config
    clear_enqueued_jobs
  end

  it "enqueues awesome menu label MT when default locale label changes via UpdateMenuHack" do
    expect do
      described_class.call(form, :menu)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateAwesomeMenuLabelJob).with(
      awesome_config.id,
      "/",
      "en",
      "fr"
    )
  end

  it "persists machine_translations after the job runs" do
    perform_enqueued_jobs do
      described_class.call(form, :menu)
    end

    awesome_config.reload
    label = awesome_config.value.find { |i| i["url"] == "/" }["label"]
    expect(label["fr"]).to eq("Démarches participatives")
    expect(label.dig("machine_translations", "en")).to eq("en - Démarches participatives")
  end
end
