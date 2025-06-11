# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module DecidimViewModel
        extend ActiveSupport::Concern
        included do
          include ::NextGenImages::ViewHelpers
        end
      end
    end
  end
end
