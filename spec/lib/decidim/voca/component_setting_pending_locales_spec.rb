# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::ComponentSettingPendingLocales do
  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr es),
      default_locale: "en",
      enable_machine_translations: true
    )
  end

  before do
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
  end

  it "omits locales that already have machine_translations" do
    hash = {
      "en" => "Hello",
      "machine_translations" => { "fr" => "Bonjour" }
    }

    expect(described_class.for(hash, organization)).to eq(%w(es))
    expect(described_class.gaps(hash, organization)).to match_array(%w(fr es))
  end

  it "returns empty when default locale source is blank" do
    hash = { "en" => "", "machine_translations" => { "fr" => "x" } }
    expect(described_class.for(hash, organization)).to eq([])
  end
end
