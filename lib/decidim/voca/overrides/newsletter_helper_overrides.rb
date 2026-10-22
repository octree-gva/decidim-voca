# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module NewsletterHelperOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :original_transform_image_urls, :transform_image_urls

          def transform_image_urls(content, host)
            return content if host.blank?

            content.scan(/src\s*=\s*"([^"]*)"/).each do |src|
              url = src.first

              next if url.start_with?("http://", "https://", "//")

              root_url = decidim.root_url(host:)[0..-2]
              src_replaced = "#{root_url}#{src.first}"
              content = content.gsub(/src\s*=\s*"([^"]*#{src.first})"/, %(src="#{src_replaced}"))
            end
            content
          end
        end
      end
    end
  end
end
