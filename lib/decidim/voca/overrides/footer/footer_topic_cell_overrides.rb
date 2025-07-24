# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module Footer
        module FooterTopicCellOverrides
          extend ActiveSupport::Concern

          included do
            alias_method :voca_show_original, :show
            def show
              return if topics.blank?

              render :show_overrides
            end
          end
        end
      end
    end
  end
end
