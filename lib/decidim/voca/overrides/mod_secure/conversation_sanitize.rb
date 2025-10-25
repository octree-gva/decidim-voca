module Decidim
  module Voca
    module Overrides
      module ConversationSanitize
        extend ActiveSupport::Concern

        included do |base|
          include ::Decidim::SanitizeHelper
          if respond_to?(:before_validation)
            # When included in a ActiveRecord
            before_validation :voca_sanitize_body 
          elsif respond_to?(:validate)
            # When included in ActiveModel
            validate :voca_sanitize_body
          end

          private 

          def voca_sanitize_body
            self.body = decidim_sanitize(body, strip_tags: true) unless body.empty?
          end
        end
      end
    end
  end
end