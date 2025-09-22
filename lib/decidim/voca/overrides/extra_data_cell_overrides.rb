# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ExtraDataCellOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_original_extra_data_items, :extra_data_items

          def extra_data_items
            [dates_item, step_item, group_item].compact
          end
        end
      end
    end
  end
end
