# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ImageTagOverrides
        extend ActiveSupport::Concern
        included do
          alias_method :decidim_voca_image_tag, :image_tag

          # Override rails image_tag to use picture tags if source is an array
          def image_tag(source, options = {})
            return decidim_voca_image_tag(source, options) unless Decidim::Voca.next_gen_images?

            if source.is_a?(Array)
              source_sanitized = source.filter { |item| item }
              return "" if source_sanitized.empty?
              picture_tag(source_sanitized, image: options)
  
            else
              decidim_voca_image_tag(source, options)
            end
          end
        end
      end
    end
  end
end
