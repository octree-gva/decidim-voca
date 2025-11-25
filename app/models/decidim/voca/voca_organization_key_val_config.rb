module Decidim
  module Voca
    class VocaOrganizationKeyValConfig < ApplicationRecord
      self.table_name = "voca_organization_key_val_configs"

      belongs_to :organization, foreign_key: :decidim_organization_id, class_name: "Decidim::Organization"
    end
  end
end 