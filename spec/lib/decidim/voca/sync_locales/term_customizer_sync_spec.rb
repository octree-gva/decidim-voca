# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::TermCustomizerSync do
  before do
    DecidimVocaTermCustomizerSpecSupport.ensure_models!
    stub_dummy_machine_translator
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
  end

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(fr pt),
      default_locale: "fr",
      enable_machine_translations: true
    )
  end
  let(:translation_set) { Decidim::TermCustomizer::TranslationSet.create!(name: { "fr" => "Set" }) }
  let!(:constraint) do
    Decidim::TermCustomizer::Constraint.create!(
      organization:,
      translation_set:
    )
  end

  def create_term!(key:, locale:, value:)
    Decidim::TermCustomizer::Translation.create!(
      translation_set:,
      key:,
      locale:,
      value:
    )
  end

  it "creates missing locale rows from the customized default-locale value" do
    create_term!(key: "decidim.menu.processes", locale: "fr", value: "Processus")

    described_class.new.call

    pt = Decidim::TermCustomizer::Translation.find_by(
      translation_set:,
      key: "decidim.menu.processes",
      locale: "pt"
    )
    expect(pt).to be_present
    expect(pt.value).to eq("pt - Processus")
  end

  it "skips locales that already have a present value" do
    create_term!(key: "decidim.menu.processes", locale: "fr", value: "Processus")
    create_term!(key: "decidim.menu.processes", locale: "pt", value: "Já traduzido")

    described_class.new.call

    pt = Decidim::TermCustomizer::Translation.find_by(
      translation_set:,
      key: "decidim.menu.processes",
      locale: "pt"
    )
    expect(pt.value).to eq("Já traduzido")
  end

  it "does nothing when the default locale value is blank" do
    create_term!(key: "decidim.menu.processes", locale: "fr", value: "")

    expect do
      described_class.new.call
    end.not_to change(Decidim::TermCustomizer::Translation, :count)
  end

  it "prints done/skipped summary when requested" do
    create_term!(key: "decidim.menu.processes", locale: "fr", value: "Processus")

    expect do
      described_class.new.call(print_summary: true)
    end.to output(/done: 1, skipped: 0/).to_stdout
  end
end
