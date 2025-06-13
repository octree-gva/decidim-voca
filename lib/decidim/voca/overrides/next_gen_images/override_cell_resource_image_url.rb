# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      def self.override_cell_resource_image_url(attachment_name)
        Module.new do
          extend ActiveSupport::Concern

          included do
            alias_method :decidim_voca_resource_image_url, :resource_image_url
            define_method :variants_for do |uploader|
              uploader.variants.sort { |variant_a, _variant_b| variant_a.first.to_s.ends_with?("webp") ? 0 : 1 }.to_h
            end
            define_method :resource_image_url do
              uploader = model.attached_uploader(attachment_name.to_sym)
              variants_for(uploader).map do |variant, _variant_options|
                uploader.variant_url(variant)
              end
            end
          end
        end
      end
    end
  end
end
