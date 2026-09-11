# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe UserFieldsConfigurator do
      before { described_class.call }

      it "registers the voca default registration fields" do
        expect(registration_field_names).to include(
          :voca_defaults_code,
          :voca_defaults_firstname,
          :voca_defaults_lastname,
          :voca_defaults_phone
        )
      end

      it "registers the existing authorization handlers" do
        expect(verification_handler_names).to include("fullname_and_birthdate", "firstname")
      end

      it "does not register a code authorization handler" do
        expect(verification_handler_names).not_to include("code")
      end

      it "keeps authorization handler field names unchanged" do
        field_sets = Decidim::CustomUserFields::Verifications.verification_classes.map do |handler_class|
          handler_class.decidim_custom_fields.map(&:name)
        end
        expect(field_sets).to include([:first_name, :last_name, :birthdate])
      end

      it "registers fields once when called repeatedly" do
        described_class.call
        described_class.call

        expect(registration_field_names.count { |name| name == :voca_defaults_code }).to eq(1)
      end

      def registration_field_names
        Decidim::CustomUserFields.custom_fields.map(&:name)
      end

      def verification_handler_names
        Decidim::CustomUserFields::Verifications.verification_classes.map do |handler_class|
          handler_class.name.demodulize.underscore
        end
      end
    end
  end
end
