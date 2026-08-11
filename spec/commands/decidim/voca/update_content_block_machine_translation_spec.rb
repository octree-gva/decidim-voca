# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Admin::ContentBlocks::UpdateContentBlock do
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
  let(:form) do
    instance_double(
      Decidim::Admin::ContentBlockForm,
      invalid?: false,
      settings: { "welcome_text_en" => "Nyon city", "welcome_text_fr" => "" },
      images: {}
    )
  end

  before do
    Decidim::Voca::DeepL::EngineConfig.apply_mergeable_fields!
    stub_dummy_machine_translator
    set_jsonb_column(content_block, :settings, { "welcome_text_en" => "old hero", "welcome_text_fr" => "" })
    clear_enqueued_jobs
  end

  it "enqueues content-block MT when welcome_text default locale changes via admin command" do
    expect do
      described_class.call(form, content_block, :homepage)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob).with(
      content_block.id,
      "welcome_text",
      "fr",
      "en",
      html: false
    )
  end

  it "persists machine_translations after the job runs" do
    perform_enqueued_jobs do
      described_class.call(form, content_block, :homepage)
    end

    content_block.reload
    nested = content_block.read_attribute(:settings)["welcome_text"]
    expect(nested["en"]).to eq("Nyon city")
    expect(nested.dig("machine_translations", "fr")).to eq("fr - Nyon city")
  end
end
