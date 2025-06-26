# frozen_string_literal: true

require "decidim/meetings"

module Decidim
  module Voca
    module Overrides
      module MeetingsControllerOverrides
        extend ActiveSupport::Concern

        included do
          # Alias the original mail method
          alias_method :original_meeting, :meeting

          private

          def meeting
            return nil if !params[:id] || params[:id].to_i <= 0

            original_meeting
          end
        end
      end
    end
  end
end
