# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module OrganizationModelOverrides
        extend ActiveSupport::Concern

        included do
          has_many :voca_organization_key_val_configs, class_name: "Decidim::Voca::VocaOrganizationKeyValConfig", foreign_key: :decidim_organization_id, dependent: :destroy
          after_create :create_voca_external_id!

          def voca_external_id
            voca_organization_key_val_configs.find_by(key: "external_id")&.value
          end

          def create_voca_external_id!
            voca_organization_key_val_configs.find_or_create_by(key: "external_id") do |config|
              config.value = SecureRandom.uuid
            end
          end
        end
      end
    end
  end
end
