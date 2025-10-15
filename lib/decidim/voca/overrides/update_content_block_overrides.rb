# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module UpdateContentBlockOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_update_content_block_images, :update_content_block_images

          def update_content_block_images
            content_block.manifest.images.each do |image_config|
              image_name = image_config[:name]

              if form.images[image_name]
                content_block.images_container.send("#{image_name}=", form.images[image_name])
              elsif form.images["remove_#{image_name}".to_sym]
                content_block.images_container.send("#{image_name}=", nil)
              end
            end
          end
        end
      end
    end
  end
end
