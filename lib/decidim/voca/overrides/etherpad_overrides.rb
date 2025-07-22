# frozen_string_literal: true

require "decidim/meetings"

module Decidim
  module Voca
    module Overrides
      module EtherpadOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_etherpad_original_resolve, :resolve

          def resolve(path, params = {})
            decidim_etherpad_original_resolve(path, params)
          rescue StandardError => e
            Rails.logger.error("Error getting pad data: #{e.message}")
            { readOnlyID: nil, text: nil }
          end
        end
      end
    end
  end
end
