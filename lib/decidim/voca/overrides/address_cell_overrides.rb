# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module AddressCellOverrides
        extend ActiveSupport::Concern

        # change start_and_end_time, start_time
        # and end_time to support
        # 12h and 24h time formats via I18n

        included do
          alias_method :decidim_start_time, :start_time
          alias_method :decidim_end_time, :end_time

          def start_time
            l(model.start_time, format: time_format.to_s)
          end

          def end_time
            l(model.end_time, format: "#{time_format} %Z")
          end

          def time_format
            @time_format ||= I18n.t("time.formats.12h_24h")
          end
        end
      end
    end
  end
end
