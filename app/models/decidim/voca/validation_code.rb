# frozen_string_literal: true

module Decidim
  module Voca
    class ValidationCode < ApplicationRecord
      self.table_name = "voca_validation_codes"

      belongs_to :organization, class_name: "Decidim::Organization", foreign_key: :decidim_organization_id

      validates :code, presence: true, length: { minimum: 3 }
    end
  end
end
