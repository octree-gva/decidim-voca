# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      def self.override_for_has_one_attached(attachment_name, uploader_class)
        variants = uploader_class.variants
        Module.new do
          extend ActiveSupport::Concern

          included do
            has_one_attached attachment_name do |attachable|
              webp_options = {
                convert: :webp,
                format: :webp,
                saver: { subsample_mode: "on", strip: true, interlace: true, quality: 80 },
                quality: 80
              }
              unless variants.has_key? :webp
                variants.filter { |variant_name| variant_name != :default }.each do |variant_name, variant_options|
                  attachable.variant "#{variant_name}_webp".to_sym, variant_options.merge(webp_options)
                end
                attachable.variant :webp, webp_options
              end
              sorted_variants = attachable.variants.sort { |variant_a, _variant_b| variant_a.first.to_s.ends_with?("webp") ? 0 : 1 }.to_h
              uploader_class.set_variants { sorted_variants }
              attachable
            end
          end
        end
      end
    end
  end
end
