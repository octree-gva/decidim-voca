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
        Decidim::CustomUserFields::Customizations.find(:voca_defaults).present?
      end

      def register_voca_defaults!
        Decidim::CustomUserFields.register_customization(:voca_defaults) do |customization|
          add_registration_fields(customization)
          add_fullname_and_birthdate(customization)
          add_firstname(customization)
        end
      end

      def add_registration_fields(customization)
        customization.registration_fields do |set|
          set.add_field :code, type: :text, required: false
          set.add_field :firstname, type: :text, required: false
          set.add_field :lastname, type: :text, required: false
          set.add_field :phone, type: :text, required: false
        end
      end

      def add_fullname_and_birthdate(customization)
        customization.authorization "FULLNAME_AND_BIRTHDATE" do |config|
          config.add_field :first_name, type: :text, required: true, skip_hashing: true
          config.add_field :last_name, type: :text, required: true, skip_hashing: true
          config.add_field :birthdate, type: :date, required: true, not_after: 13.years.ago.to_date.iso8601, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end

      def add_firstname(customization)
        customization.authorization "FIRSTNAME" do |config|
          config.add_field :name, type: :text, required: true, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end
    end
  end
end
