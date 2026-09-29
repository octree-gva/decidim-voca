# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::ContentBlockSettingSync do
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
  let(:content_block) { create(:content_block, organization:, scope_name: :homepage, manifest_name: :hero) }

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "populates flat welcome_text_en from FR human source during sync" do
    set_jsonb_column(
      content_block,
      :settings,
      { "welcome_text_fr" => "votre ville, vos idées, vos projets !" }
    )

    described_class.new(content_block).call

    content_block.reload
    settings = content_block.read_attribute(:settings)
    expect(settings["welcome_text_fr"]).to eq("votre ville, vos idées, vos projets !")
    expect(settings["welcome_text_en"]).to eq("en - votre ville, vos idées, vos projets !")
    expect(settings).not_to have_key("welcome_text")
  end

  it "is a no-op for non-content-blocks" do
    expect { described_class.new(organization).call }.not_to raise_error
  end

  it "is a no-op when settings are nil" do
    set_jsonb_column(content_block, :settings, nil)

    expect { described_class.new(content_block).call }.not_to raise_error
  end
end
