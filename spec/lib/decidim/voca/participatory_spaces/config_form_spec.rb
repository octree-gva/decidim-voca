# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::ParticipatorySpaces::ConfigForm do
  let(:organization) { create(:organization) }

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  describe ".from_model" do
    it "loads enabled flags for installed spaces" do
      seed_participatory_space_toggle(organization, :decidim_assemblies, enabled: false)

      form = described_class.from_model(organization)

      expect(form.participatory_processes_enabled).to be(true)
      expect(form.assemblies_enabled).to be(false)
    end
  end

  describe "disabling spaces with published content" do
    before do
      require "decidim/assemblies/test/factories"
    end

    it "is invalid when disabling assemblies while published assemblies exist" do
      create(:assembly, organization:, published_at: Time.current)

      form = described_class.from_params(
        organization: { assemblies_enabled: "0", participatory_processes_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).not_to be_valid
      expect(form.errors[:assemblies_enabled]).to include(
        match(/cannot disable this space while published assemblies exist/i)
      )
    end

    it "is valid when disabling assemblies with no published assemblies" do
      form = described_class.from_params(
        organization: { assemblies_enabled: "0", participatory_processes_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).to be_valid
    end

    it "is valid when keeping assemblies enabled with published assemblies" do
      create(:assembly, organization:, published_at: Time.current)

      form = described_class.from_params(
        organization: { assemblies_enabled: "1", participatory_processes_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).to be_valid
    end
  end

  describe "#management_callout_html" do
    it "describes installed and missing gems as html" do
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-initiatives").and_return(false)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-conferences").and_return(false)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-participatory_processes").and_return(true)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-assemblies").and_return(true)

      form = described_class.from_model(organization)
      html = form.management_callout_html

      expect(html).to include("<h4>Manage participatory spaces</h4>")
      expect(html).to include("<code>decidim-participatory_processes, decidim-assemblies</code>")
      expect(html).to include("<code>decidim-initiatives, decidim-conferences</code> are not installed")
      expect(html).to include("<strong>Note</strong>")
    end
  end

  describe "#attribute_disabled?" do
    it "is true when the participatory space gem is not in the bundle" do
      allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-conferences").and_return(false)

      form = described_class.from_model(organization)

      expect(form.attribute_disabled?(:conferences_enabled)).to be(true)
      expect(form.attribute_disabled?(:assemblies_enabled)).to be(false)
    end
  end

  describe ".from_params" do
    it "reads nested organization params and treats unchecked boxes as false" do
      form = described_class.from_params(
        organization: {
          participatory_processes_enabled: "1",
          assemblies_enabled: "0"
        }
      )

      expect(form.participatory_processes_enabled).to be(true)
      expect(form.assemblies_enabled).to be(false)
    end
  end
end
