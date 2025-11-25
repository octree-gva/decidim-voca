# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module OrganizationModelOverrides
        extend ActiveSupport::Concern

        included do
          has_many :voca_organization_key_val_configs, class_name: "Decidim::Voca::VocaOrganizationKeyValConfig", foreign_key: :decidim_organization_id, dependent: :destroy

          def voca_external_id
            voca_organization_key_val_configs.find_by(key: "external_id")&.value
          end
        end
      end
    end
  end
end
