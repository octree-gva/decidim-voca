# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::Runner do
  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:participatory_process) { create(:participatory_process, organization:) }
  let!(:component) { create(:component, participatory_space: participatory_process, name: { "en" => "Hello" }) }

  before do
    allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Voca::DeepL::MachineTranslator)
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
    allow(Decidim::Voca::DeepL::MachineTranslator).to receive(:new).and_return(
      instance_double(Decidim::Voca::DeepL::MachineTranslator, translate: true)
    )
    allow(Decidim::Voca::DeepL::Context).to receive(:with_organization).and_yield
  end

  it "raises for an unknown model_name" do
    expect do
      described_class.new(model_name: "Decidim::Nope").call
    end.to raise_error(ArgumentError, /list_translatable_models/)
  end

  it "prints done/skipped summary and only processes the given model" do
    expect do
      described_class.new(model_name: "Decidim::Component").call
    end.to output(
      satisfy("filtered Component summary") do |text|
        text.include?("Processing model: Decidim::Component") &&
          text.match?(/done: \d+, skipped: \d+/) &&
          text.exclude?("Decidim::ContentBlock")
      end
    ).to_stdout
  end

  it "routes Decidim::TermCustomizer::Translation to TermCustomizerSync only" do
    DecidimVocaTermCustomizerSpecSupport.ensure_models!
    allow(Decidim::Voca::SyncLocales::TermCustomizerSync).to receive(:available?).and_return(true)
    syncer = instance_double(Decidim::Voca::SyncLocales::TermCustomizerSync)
    allow(Decidim::Voca::SyncLocales::TermCustomizerSync).to receive(:new).and_return(syncer)
    allow(syncer).to receive(:each_key_stats)

    expect do
      described_class.new(model_name: "Decidim::TermCustomizer::Translation").call
    end.to output(
      satisfy("TermCustomizer-only output") do |text|
        text.include?("Processing model: Decidim::TermCustomizer::Translation") &&
          text.exclude?("Processing model: Decidim::Component")
      end
    ).to_stdout

    expect(syncer).to have_received(:each_key_stats)
  end
end
