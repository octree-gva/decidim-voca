# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::ParticipatorySpaces do
  subject(:organization) { create(:organization) }

  describe ".space_enabled?" do
    it "defaults to true when no config exists" do
      expect(described_class.space_enabled?(organization, :initiatives)).to be(true)
    end

    it "reflects the toggle config" do
      seed_participatory_space_toggle(organization, :decidim_initiatives, enabled: false)

      expect(described_class.space_enabled?(organization, :initiatives)).to be(false)
    end
  end

  describe ".enabled?" do
    it "defaults to true when no config exists" do
      expect(described_class.enabled?(organization, :decidim_initiatives)).to be(true)
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
end
