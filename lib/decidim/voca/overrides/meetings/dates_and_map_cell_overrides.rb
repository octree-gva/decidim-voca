# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module Meetings
        module DatesAndMapCellOverrides
          extend ActiveSupport::Concern

          included do
            alias_method :voca_show_original, :show
            def show
              render :show_overrides
            end
          end
        end
      end
    end
  end
end
