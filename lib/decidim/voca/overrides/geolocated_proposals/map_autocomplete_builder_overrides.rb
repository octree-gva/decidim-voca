# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module MapAutocompleteBuilderOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :voca_geocoding_field_original, :geocoding_field

          def geocoding_field(object_name, method, options = {})
            options[:class] = "" unless options.has_key?(:class)
            options[:class] += " input-group-field"
            field = voca_geocoding_field_original(object_name, method, options)
            template.content_tag(:div, class: "input-group input-group--geocoding") do
              field +
                template.content_tag(:div, class: "input-group-button") do
                  template.link_to(
                    I18n.t("decidim.voca.proposals.find_my_location"),
                    "#javascript-find-my-location",
                    class: "button button__sm button__primary js--use_my_location",
                    data: {}
                  )
                end
            end
          end
        end
      end
    end
  end
end
