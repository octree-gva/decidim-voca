# frozen_string_literal: true

require "spec_helper"
require File.expand_path("../../../../db/migrate/20260908114000_enable_voca_defaults_user_fields_customization", __dir__)

describe EnableVocaDefaultsUserFieldsCustomization do
  subject(:migration) { described_class.new }

  def voca_defaults_enabled?(organization)
    record = Decidim::Toggle::OrganizationModuleConfig.find_by(
      decidim_organization_id: organization.id,
      module_name: "custom_user_fields"
    )
    record&.config&.[]("voca_defaults_enabled")
  end

  describe "#up" do
    it "enables voca_defaults for every organization" do
      org_a = create(:organization)
      org_b = create(:organization)

      migration.up

      expect(voca_defaults_enabled?(org_a)).to be(true)
      expect(voca_defaults_enabled?(org_b)).to be(true)
    end

    it "does not leak config across organizations" do
      org_a = create(:organization)
      org_b = create(:organization)

      migration.up
      Decidim::Toggle.save_config!(org_a, "custom_user_fields", { "voca_defaults_enabled" => false })

      expect(voca_defaults_enabled?(org_a)).to be(false)
      expect(voca_defaults_enabled?(org_b)).to be(true)
    end

    it "is a no-op when the toggle config table is missing" do
      allow(migration.connection).to receive(:table_exists?).and_call_original
      allow(migration.connection).to receive(:table_exists?)
        .with("decidim_toggle_organization_module_configs")
        .and_return(false)

      expect(Decidim::Toggle).not_to receive(:save_config!)
      expect { migration.up }.not_to raise_error
    end
  end
end
