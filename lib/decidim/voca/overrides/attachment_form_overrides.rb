# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module AttachmentFormOverrides
        extend ActiveSupport::Concern

        included do
          if Object.const_defined?("ActiveModel::Validations::UrlValidator")
            _validators[:link].reject! { |v| v.is_a?(ActiveModel::Validations::UrlValidator) }

            _validate_callbacks.each do |callback|
              skip_callback(:validate, callback.filter) if callback.filter.is_a?(ActiveModel::Validations::UrlValidator)
            end

            validates_with ::UrlValidator, attributes: [:link]
          end
        end
      end
    end
  end
end
