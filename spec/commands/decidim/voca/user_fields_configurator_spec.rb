# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe UserFieldsConfigurator do
      subject(:customization) { Decidim::CustomUserFields::Customizations.find(:voca_defaults) }

      before { described_class.call }

      it "registers the voca_defaults customization" do
        expect(customization).to be_present
      end

      it "registers prefixed registration field names" do
        expect(customization.fields.map(&:name)).to contain_exactly(
          :voca_defaults_code,
          :voca_defaults_firstname,
          :voca_defaults_lastname,
          :voca_defaults_phone
        )
      end

      it "nests the existing authorization handlers" do
        expect(customization.workflow_handlers).to contain_exactly("fullname_and_birthdate", "firstname")
      end

      it "does not register a code authorization handler" do
        expect(customization.workflow_handlers).not_to include("code")
      end

      # ponytail: no extended_data remap — prior configurator registered handlers only, never production code/firstname keys.

      it "registers the toggle enabled flag" do
        expect(
          Decidim::CustomUserFields::Admin::CustomizationsConfigForm.attribute_types
        ).to have_key("voca_defaults_enabled")
      end

      it "keeps authorization handler field names unchanged" do
        field_sets = Decidim::CustomUserFields::Verifications.verification_classes.map do |handler_class|
          handler_class.decidim_custom_fields.map(&:name)
        end
        expect(field_sets).to include([:first_name, :last_name, :birthdate])
      end

      it "leaves the customization disabled until toggle config is saved" do
        organization = create(:organization)

        expect(Decidim::CustomUserFields::RegistrationFields.enabled_customization_names(organization))
          .not_to include("voca_defaults")
      end

      it "enables the customization per organization via toggle config" do
        enabled_org = create(:organization)
        other_org = create(:organization)
        Decidim::Toggle.save_config!(enabled_org, :custom_user_fields, { "voca_defaults_enabled" => true })

        expect(Decidim::CustomUserFields::RegistrationFields.enabled_customization_names(enabled_org))
          .to include("voca_defaults")
        expect(Decidim::CustomUserFields::RegistrationFields.enabled_customization_names(other_org))
          .not_to include("voca_defaults")
      end
    end
  end
end
