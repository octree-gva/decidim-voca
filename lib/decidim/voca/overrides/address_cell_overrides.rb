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
          alias_method :decidim_show, :show
          alias_method :decidim_start_and_end_time, :start_and_end_time
          alias_method :decidim_start_time, :start_time
          alias_method :decidim_end_time, :end_time

          def show
            return render :online_overrides if options[:online]

            render :show_overrides
          end

          def start_and_end_time(format)
            <<~HTML
              #{with_tooltip(l(model.start_time, format: :tooltip)) { start_time(format) }}
              -
              #{with_tooltip(l(model.end_time, format: :tooltip)) { end_time(format) }}
            HTML
          end

          def start_time(format)
            l(model.start_time, format:)
          end

          def end_time(format)
            l(model.end_time, format: "#{format} %Z")
          end
        end
      end
    end
  end
end
