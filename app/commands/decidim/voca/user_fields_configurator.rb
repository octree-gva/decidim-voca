# frozen_string_literal: true

module Decidim
  module Voca
    class UserFieldsConfigurator < Decidim::Command
      def call
        return unless user_fields_installed?
        return if already_registered?

        register_voca_defaults!
      end

      private

      def user_fields_installed?
        Gem.loaded_specs.has_key?("decidim-user_fields")
      end

      def already_registered?
        Decidim::CustomUserFields.custom_fields.any? do |field|
          field.name == :voca_defaults_code
        end
      end

      def register_voca_defaults!
        add_registration_fields
        add_fullname_and_birthdate
        add_firstname
      end

      def add_registration_fields
        Decidim::CustomUserFields.configure do |config|
          config.add_field :voca_defaults_code, type: :text, required: false
          config.add_field :voca_defaults_firstname, type: :text, required: false
          config.add_field :voca_defaults_lastname, type: :text, required: false
          config.add_field :voca_defaults_phone, type: :text, required: false
        end
      end

      def add_fullname_and_birthdate
        Decidim::CustomUserFields::Verifications.register("FULLNAME_AND_BIRTHDATE") do |config|
          config.add_field :first_name, type: :text, required: true, skip_hashing: true
          config.add_field :last_name, type: :text, required: true, skip_hashing: true
          config.add_field :birthdate, type: :date, required: true, not_after: 13.years.ago.to_date.iso8601, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end

      def add_firstname
        Decidim::CustomUserFields::Verifications.register("FIRSTNAME") do |config|
          config.add_field :name, type: :text, required: true, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end
    end
  end
end
