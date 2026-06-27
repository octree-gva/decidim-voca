# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::ParticipatorySpaces do
  subject(:organization) { create(:organization) }

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  describe ".space_enabled?" do
    it "defaults participatory processes to enabled when no config exists" do
      expect(described_class.space_enabled?(organization, :participatory_processes)).to be(true)
    end

    it "defaults initiatives to disabled when no config exists" do
      expect(described_class.space_enabled?(organization, :initiatives)).to be(false)
    end

    it "reflects the toggle config" do
      seed_participatory_space_toggle(organization, :decidim_initiatives, enabled: false)

      expect(described_class.space_enabled?(organization, :initiatives)).to be(false)
    end

    it "returns false when the organization is nil" do
      expect(described_class.space_enabled?(nil, :assemblies)).to be(false)
    end
  end

  describe ".enabled?" do
    it "returns false when the gem is not in the bundle" do
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-initiatives").and_return(false)

      expect(described_class.enabled?(organization, :decidim_initiatives)).to be(false)
    end

    it "returns false when the organization is nil" do
      expect(described_class.enabled?(nil, :decidim_assemblies)).to be(false)
    end

    it "defaults participatory processes to enabled when no config exists" do
      expect(described_class.enabled?(organization, :decidim_participatory_processes)).to be(true)
    end

    it "defaults initiatives to disabled when no config exists" do
      expect(described_class.enabled?(organization, :decidim_initiatives)).to be(false)
    end

    it "returns false when explicitly disabled" do
      seed_participatory_space_toggle(organization, :decidim_initiatives, enabled: false)

      expect(described_class.enabled?(organization, :decidim_initiatives)).to be(false)
    end

    it "returns true when explicitly enabled" do
      seed_participatory_space_toggle(organization, :decidim_initiatives, enabled: true)

      expect(described_class.enabled?(organization, :decidim_initiatives)).to be(true)
    end
  end

  describe ".published_spaces?" do
    before do
      require "decidim/assemblies/test/factories"
    end

    it "is true when the organization has published assemblies" do
      create(:assembly, organization:, published_at: Time.current)

      expect(described_class.published_spaces?(organization, :assemblies)).to be(true)
    end

    it "is false when assemblies are not published" do
      create(:assembly, organization:, published_at: nil)

      expect(described_class.published_spaces?(organization, :assemblies)).to be(false)
    end
  end

  describe ".published_spaces_count" do
    before do
      require "decidim/assemblies/test/factories"
    end

    it "returns the number of published assemblies" do
      create(:assembly, organization:, published_at: Time.current)
      create(:assembly, organization:, published_at: nil)

      expect(described_class.published_spaces_count(organization, :assemblies)).to eq(1)
    end
  end

  describe "javascript config" do
    before do
      Decidim::Voca::ParticipatorySpaces::SettingsTab.register!
    end

    it "exposes space enabled flags via decidim-toggle" do
      seed_participatory_space_toggle(organization, :initiatives, enabled: false)
      seed_participatory_space_toggle(organization, :conferences, enabled: true)

      config = Decidim::Toggle.javascript_config_for(organization)

      expect(config).to include(
        "spaces.initiatives_enabled" => false,
        "spaces.conferences_enabled" => true,
        "spaces.participatory_processes_enabled" => true,
        "spaces.assemblies_enabled" => true
      )
    end
  end
end
