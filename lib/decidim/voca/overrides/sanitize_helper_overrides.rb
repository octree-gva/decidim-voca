# frozen_string_literal: true

require "decidim/meetings"

module Decidim
  module Voca
    module Overrides
      module SanitizeHelperOverrides
        extend ActiveSupport::Concern

        included do
          # Alias the original mail method
          alias_method :original_content_handle_locale, :content_handle_locale
          alias_method :original_render_sanitized_content, :render_sanitized_content

          private

          # Overrides it to include Decidim::ContentRenderers::BlobRenderer in the
          # renderer to properly render files and images in the Meetings show view.
          def content_handle_locale(body, all_locales, extras, links, strip_tags)
            handle_locales(body, all_locales) do |content|
              content = strip_tags(sanitize_text(content)) if strip_tags

              renderer = Decidim::ContentRenderers::HashtagRenderer.new(content)
              content = renderer.render(links:, extras:).html_safe

              content = Decidim::ContentRenderers::LinkRenderer.new(content).render if links

              content = Decidim::ContentRenderers::BlobRenderer.new(content).render.html_safe

              content
            end
          end

          # Overrides it to render safe content in the the Meetings show view.
          def render_sanitized_content(resource, method, presenter_class: nil)
            content = present(resource, presenter_class:).send(method, links: true, strip_tags: !try(:safe_content?))

            return decidim_sanitize_editor_admin(content, {}) if try(:safe_content_admin?)

            try(:safe_content?) ? content : decidim_sanitize(content, {})
          end
        end
      end
    end
  end
end
