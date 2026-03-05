# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ResourcePresenterOverrides
        extend ActiveSupport::Concern

        included do
          # Alias the original mail method
          alias_method :original_editor_locales, :editor_locales

          private

          # Prepares the HTML content for the editors with the correct tags included
          # to identify the hashtags and mentions.
          # Overrides it to include Decidim::ContentRenderers::BlobRenderer in the
          # renderer array to properly render files and images in the Meetings editor.
          def editor_locales(data, all_locales, extras: true)
            data = original_editor_locales(data, all_locales, extras:)
            handle_locales(data, all_locales) do |content|
              renderer = Decidim::ContentRenderers::BlobRenderer.new(content)
              renderer.render(links: false, editor: true, extras:).html_safe
            end
          end
        end
      end
    end
  end
end
