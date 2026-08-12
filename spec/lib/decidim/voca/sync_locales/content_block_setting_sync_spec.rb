# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::ContentBlockSettingSync do
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
  let(:content_block) { create(:content_block, organization:, scope_name: :homepage, manifest_name: :hero) }

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "enqueues MachineTranslateContentBlockSettingJob for pending locales" do
    set_jsonb_column(content_block, :settings, { "welcome_text" => { "en" => "Hello" } })

    expect do
      described_class.new(content_block).call
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob).with(
      content_block.id,
      "welcome_text",
      "fr",
      "en",
      html: false
    )
  end

  it "coalesces flat keys then enqueues" do
    set_jsonb_column(content_block, :settings, { "welcome_text_en" => "Bonjour flat" })

    expect do
      described_class.new(content_block).call
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob)

    content_block.reload
    expect(content_block.read_attribute(:settings)["welcome_text"]["en"]).to eq("Bonjour flat")
  end

  it "is a no-op for non-content-blocks" do
    expect do
      described_class.new(organization).call
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob)
  end

  it "is a no-op when settings are nil" do
    set_jsonb_column(content_block, :settings, nil)

    expect do
      described_class.new(content_block).call
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob)
  end
end
