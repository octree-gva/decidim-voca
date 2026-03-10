# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module CardMetadataCellOverrides
        extend ActiveSupport::Concern

        # change start_date_item to support
        # 12h and 24h time formats via I18n

        included do
          alias_method :decidim_start_date_item, :start_date_item

          def start_date_item
            return if dates_blank?

            {
              text: I18n.l(start_date, format: I18n.t("time.formats.12h_24h")),
              icon: "time-line"
            }
          end
        end
      end
    end
  end
end
