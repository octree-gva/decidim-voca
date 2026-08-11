# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::ContentBlockTranslatedSettingsMachineTranslation do
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
    Decidim::Voca::DeepL::EngineConfig.apply_mergeable_fields!
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "enqueues MachineTranslateContentBlockSettingJob when default locale welcome_text changes" do
    # rubocop:disable Rails/SkipsModelValidations -- nested settings fixture
    content_block.update_column(:settings, { "welcome_text" => { "en" => "first" } })
    # rubocop:enable Rails/SkipsModelValidations

    expect do
      content_block.assign_attributes(settings: { "welcome_text" => { "en" => "second" } })
      content_block.save!(validate: false)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob).with(
      content_block.id,
      "welcome_text",
      "fr",
      "en",
      html: false
    )
  end

  it "enqueues when admin-style flat welcome_text_en changes" do
    # rubocop:disable Rails/SkipsModelValidations -- flat admin fixture
    content_block.update_column(:settings, { "welcome_text_en" => "first", "welcome_text_fr" => "" })
    # rubocop:enable Rails/SkipsModelValidations

    expect do
      content_block.assign_attributes(settings: { "welcome_text_en" => "second", "welcome_text_fr" => "" })
      content_block.save!(validate: false)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob).with(
      content_block.id,
      "welcome_text",
      "fr",
      "en",
      html: false
    )
  end

  it "does not enqueue when machine translation service is unset" do
    allow(Decidim).to receive(:machine_translation_service_klass).and_return(nil)
    # rubocop:disable Rails/SkipsModelValidations -- nested settings fixture
    content_block.update_column(:settings, { "welcome_text" => { "en" => "first" } })
    # rubocop:enable Rails/SkipsModelValidations

    expect do
      content_block.assign_attributes(settings: { "welcome_text" => { "en" => "second" } })
      content_block.save!(validate: false)
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateContentBlockSettingJob)
  end
end
