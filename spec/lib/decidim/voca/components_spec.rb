# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::Components do
  subject(:organization) { create(:organization) }

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  describe ".component_enabled?" do
    it "defaults meetings to enabled when no config exists" do
      expect(described_class.component_enabled?(organization, :meetings)).to be(true)
    end

    it "defaults forms to disabled when no config exists" do
      expect(described_class.component_enabled?(organization, :forms)).to be(false)
    end

    it "defaults awesome map and iframe to disabled when no config exists" do
      expect(described_class.component_enabled?(organization, :awesome_map)).to be(false)
      expect(described_class.component_enabled?(organization, :awesome_iframe)).to be(false)
    end

    it "defaults surveys to enabled when no config exists" do
      expect(described_class.component_enabled?(organization, :surveys)).to be(true)
    end

    it "reflects the toggle config" do
      seed_component_toggle(organization, :elections, enabled: false)

      expect(described_class.component_enabled?(organization, :elections)).to be(false)
    end

    it "returns false when the organization is nil" do
      expect(described_class.component_enabled?(nil, :proposals)).to be(false)
    end
  end

  describe ".enabled?" do
    it "returns false when the gem is not in the bundle" do
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-elections").and_return(false)

      expect(described_class.enabled?(organization, :elections)).to be(false)
    end

    it "returns false when the organization is nil" do
      expect(described_class.enabled?(nil, :proposals)).to be(false)
    end

    it "defaults meetings to enabled when no config exists" do
      expect(described_class.enabled?(organization, :meetings)).to be(true)
    end

    it "defaults forms to disabled when no config exists" do
      expect(described_class.enabled?(organization, :forms)).to be(false)
    end

    it "returns false when explicitly disabled" do
      seed_component_toggle(organization, :elections, enabled: false)

      expect(described_class.enabled?(organization, :elections)).to be(false)
    end

    it "returns true when explicitly enabled" do
      seed_component_toggle(organization, :elections, enabled: true)

      expect(described_class.enabled?(organization, :elections)).to be(true)
    end
  end

  describe ".published_components?" do
    it "is true when the organization has published proposals components" do
      create(:component, organization:, manifest_name: "proposals", published_at: Time.current)

      expect(described_class.published_components?(organization, :proposals)).to be(true)
    end

    it "is false when proposals components are not published" do
      create(:component, organization:, manifest_name: "proposals", published_at: nil)

      expect(described_class.published_components?(organization, :proposals)).to be(false)
    end
  end

  describe ".published_components_count" do
    it "returns the number of published proposals components" do
      create(:component, organization:, manifest_name: "proposals", published_at: Time.current)
      create(:component, organization:, manifest_name: "proposals", published_at: nil)

      expect(described_class.published_components_count(organization, :proposals)).to eq(1)
    end
  end

  describe "javascript config" do
    before do
      Decidim::Voca::Components::SettingsTab.register!
    end

    it "exposes component enabled flags via decidim-toggle" do
      seed_component_toggle(organization, :forms, enabled: true)
      seed_component_toggle(organization, :elections, enabled: false)

      config = Decidim::Toggle.javascript_config_for(organization)

      expect(config).to include(
        "components.forms_enabled" => true,
        "components.elections_enabled" => false,
        "components.meetings_enabled" => true,
        "components.proposals_enabled" => true
      )
    end
  end
end
