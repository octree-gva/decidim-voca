# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::ContentBlockSettingSync do
  include ActiveJob::TestHelper

  # Production Lausanne hero ("Image principale et bouton d'action"): welcome_text embeds HTML.
  let(:lausanne_welcome_fr) do
    "Lausanne participe, et vous?<h2>Une plateforme numérique pour imaginer et réaliser ensemble</h2>"
  end

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
  let(:translation_helper) { Class.new { include Decidim::TranslatableAttributes }.new }

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

  # Production homepage hero still showed FR on EN after sync_locales.
  it "machine-translates production hero welcome_text (with embedded HTML) into flat EN" do
    set_jsonb_column(content_block, :settings, { "welcome_text_fr" => lausanne_welcome_fr })

    described_class.new(content_block).call

    content_block.reload
    settings = content_block.read_attribute(:settings)
    expect(settings["welcome_text_en"]).to eq("en - #{lausanne_welcome_fr}")

    I18n.with_locale(:en) do
      expect(translation_helper.translated_attribute(content_block.settings.welcome_text, organization))
        .to eq("en - #{lausanne_welcome_fr}")
    end
  end

  # Production homepage: separate html content-block still showed FR on EN after sync_locales.
  it "machine-translates production html_content into flat EN" do
    html_block = create(:content_block, organization:, scope_name: :homepage, manifest_name: :html)
    html_fr = <<~HTML.strip
      <h2>Découvrez des expériences inspirantes</h2>
      <p><a href="/pages/temoignages">Vers les témoignages</a></p>
    HTML
    set_jsonb_column(html_block, :settings, { "html_content_fr" => html_fr })

    described_class.new(html_block).call

    html_block.reload
    settings = html_block.read_attribute(:settings)
    expect(settings["html_content_fr"]).to eq(html_fr)
    expect(settings["html_content_en"]).to eq("en - #{html_fr}")
    expect(settings).not_to have_key("html_content")

    I18n.with_locale(:en) do
      expect(translation_helper.translated_attribute(html_block.settings.html_content, organization))
        .to eq("en - #{html_fr}")
    end
  end

  # Admin ContentBlockForm#settings.to_h stores nested + flat keys; empty EN must not wipe MT.
  it "keeps EN readable after schema to_h round-trip without re-sync" do
    set_jsonb_column(content_block, :settings, { "welcome_text_fr" => lausanne_welcome_fr })
    described_class.new(content_block).call
    content_block.reload

    bloated = content_block.settings.to_h.deep_stringify_keys
    set_jsonb_column(content_block, :settings, bloated)
    content_block.reload

    expect(content_block.read_attribute(:settings)["welcome_text_en"])
      .to eq("en - #{lausanne_welcome_fr}")
    I18n.with_locale(:en) do
      expect(translation_helper.translated_attribute(content_block.settings.welcome_text, organization))
        .to eq("en - #{lausanne_welcome_fr}")
    end
  end

  it "re-syncs EN when schema to_h left an empty flat EN over a nested source" do
    set_jsonb_column(
      content_block,
      :settings,
      {
        "welcome_text" => { "fr" => lausanne_welcome_fr, "en" => "" },
        "welcome_text_fr" => lausanne_welcome_fr,
        "welcome_text_en" => ""
      }
    )

    described_class.new(content_block).call
    content_block.reload

    expect(content_block.read_attribute(:settings)["welcome_text_en"])
      .to eq("en - #{lausanne_welcome_fr}")
  end

  it "re-translates when non-default flat key still holds the FR source text" do
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
    set_jsonb_column(
      content_block,
      :settings,
      {
        "welcome_text_fr" => lausanne_welcome_fr,
        "welcome_text_en" => lausanne_welcome_fr
      }
    )

    described_class.new(content_block).call
    content_block.reload

    expect(content_block.read_attribute(:settings)["welcome_text_en"])
      .to eq("en - #{lausanne_welcome_fr}")
  end

  it "is a no-op for non-content-blocks" do
    expect { described_class.new(organization).call }.not_to raise_error
  end

  it "is a no-op when settings are nil" do
    set_jsonb_column(content_block, :settings, nil)

    expect { described_class.new(content_block).call }.not_to raise_error
  end
end
