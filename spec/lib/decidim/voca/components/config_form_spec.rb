# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::Components::ConfigForm do
  let(:organization) { create(:organization) }

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  describe "module name" do
    it "matches the toggle registration" do
      expect(described_class.module_config_name).to eq(
        Decidim::Voca::Components::MODULE_NAME
      )
    end
  end

  describe "labels" do
    it "uses decidim_toggle.system.components scope for attribute names" do
      expect(described_class.human_attribute_name(:meetings_enabled)).to eq(
        I18n.t("decidim_toggle.system.components.meetings_enabled")
      )
      expect(described_class.human_attribute_name(:forms_enabled)).to eq(
        I18n.t("decidim_toggle.system.components.forms_enabled")
      )
    end
  end

  describe ".from_model" do
    it "loads enabled flags for installed components" do
      seed_component_toggle(organization, :debates, enabled: false)

      form = described_class.from_model(organization)

      expect(form.meetings_enabled).to be(true)
      expect(form.debates_enabled).to be(false)
    end
  end

  describe "disabling components with published instances" do
    it "is invalid when disabling proposals while published proposals components exist" do
      create(:component, organization:, manifest_name: "proposals", published_at: Time.current)

      form = described_class.from_params(
        organization: { proposals_enabled: "0", meetings_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).not_to be_valid
      expect(form.errors[:proposals_enabled]).to include(
        match(/cannot disable this component while published/i)
      )
    end

    it "is valid when disabling proposals with no published proposals components" do
      form = described_class.from_params(
        organization: { proposals_enabled: "0", meetings_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).to be_valid
    end

    it "is valid when keeping proposals enabled with published proposals components" do
      create(:component, organization:, manifest_name: "proposals", published_at: Time.current)

      form = described_class.from_params(
        organization: { proposals_enabled: "1", meetings_enabled: "1" }
      ).with_context(current_organization: organization)

      expect(form).to be_valid
    end
  end

  describe "#management_callout_html" do
    it "describes installed and missing gems as html" do
      %w(
        decidim-meetings decidim-blogs decidim-budgets decidim-proposals
        decidim-pages decidim-debates decidim-accountability decidim-sortitions
        decidim-decidim_awesome decidim-surveys
      ).each do |gem|
        allow(Decidim::Toggle).to receive(:gem_present?).with(gem).and_return(true)
      end
      %w(decidim-only_forms decidim-participatory_documents decidim-collaborative_texts decidim-elections).each do |gem|
        allow(Decidim::Toggle).to receive(:gem_present?).with(gem).and_return(false)
      end

      form = described_class.from_model(organization)
      html = form.management_callout_html

      expect(html).to include("<h4>Manage components</h4>")
      expect(html).to include(
        "<code>decidim-meetings, decidim-blogs, decidim-budgets, decidim-proposals, " \
        "decidim-pages, decidim-debates, decidim-accountability, decidim-sortitions, " \
        "decidim-decidim_awesome, decidim-surveys</code>"
      )
      expect(html).to include("<code>decidim-only_forms, decidim-participatory_documents, decidim-collaborative_texts, decidim-elections</code> are not installed")
      expect(html).to include("<strong>Note</strong>")
    end
  end

  describe "#attribute_disabled?" do
    it "is true when the component gem is not in the bundle" do
      allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-elections").and_return(false)

      form = described_class.from_model(organization)

      expect(form.attribute_disabled?(:elections_enabled)).to be(true)
      expect(form.attribute_disabled?(:meetings_enabled)).to be(false)
    end

    it "disables awesome toggles when decidim-decidim_awesome is not installed" do
      allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
      allow(Decidim::Toggle).to receive(:gem_present?).with("decidim-decidim_awesome").and_return(false)

      form = described_class.from_model(organization)

      expect(form.attribute_disabled?(:awesome_map_enabled)).to be(true)
      expect(form.attribute_disabled?(:awesome_iframe_enabled)).to be(true)
    end
  end

  describe ".from_params" do
    it "reads nested organization params and treats unchecked boxes as false" do
      form = described_class.from_params(
        organization: {
          meetings_enabled: "1",
          proposals_enabled: "0"
        }
      )

      expect(form.meetings_enabled).to be(true)
      expect(form.proposals_enabled).to be(false)
    end
  end
end
