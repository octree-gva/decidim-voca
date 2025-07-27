# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module Footer
        module FooterMenuPresenter
          extend ActiveSupport::Concern

          included do
            alias_method :voca_render_original, :render
            def render
              content_tag(:nav, :role => "navigation", "aria-label" => @options[:label]) do
                safe_join([content_tag(:h2, @options[:label], class: "h4 mb-4"), render_menu])
              end
            end
          end
        end
      end
    end
  end
end
