# frozen_string_literal: true

module Decidim
  module Voca
    class UserFieldsConfigurator < Decidim::Command
      def call
        return unless user_fields_installed?
        
        Rails.application.config.after_initialize do
          configure_fullname_and_birthdate_authorization_handler!
          configure_name_authorization_handler!
          configure_code_authorization_handler!
        end
      end

      def configure_fullname_and_birthdate_authorization_handler!
        Decidim::CustomUserFields::Verifications.register("FULLNAME_AND_BIRTHDATE") do |config|
          config.add_field :first_name, type: :text, required: true, skip_hashing: true
          config.add_field :last_name, type: :text, required: true, skip_hashing: true
          config.add_field :birthdate, type: :date, required: true, not_after: 13.years.ago.to_date.iso8601, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)      
        end
      end

      def configure_name_authorization_handler!
        Decidim::CustomUserFields::Verifications.register("FIRSTNAME") do |config|
          config.add_field :name, type: :text, required: true, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end

      def configure_code_authorization_handler!
        Decidim::CustomUserFields::Verifications.register("CODE") do |config|
          config.add_field :code, type: :text, required: true, skip_hashing: true
          config.ephemerable!
          config.renewable!(1.day)
        end
      end

      private

      def user_fields_installed?
        Gem.loaded_specs.has_key?("decidim-user_fields")
      end
    end
  end
end
