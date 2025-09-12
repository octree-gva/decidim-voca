# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module System
        module SystemOrganizationUpdateForm
          extend ActiveSupport::Concern

          included do
            alias_method :original_validate_organization_name_presence, :validate_organization_name_presence

            private

            def validate_organization_name_presence
              base_query = persisted? ? Decidim::Organization.where.not(id:).all : Decidim::Organization.all

              organization_names = []

              base_query.pluck(:name).each do |value|
                organization_names += value.except("machine_translations").values
                organization_names += value.fetch("machine_translations", {}).values
              end

              organization_names = organization_names.map(&:downcase).compact_blank

              name.each do |language, value|
                next if value.is_a?(Hash)

                errors.add("name_#{language.gsub("-", "__")}", :taken) if organization_names.include?(value.downcase)
              end
            end
          end
        end
      end
    end
  end
end
