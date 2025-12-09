# frozen_string_literal: true

module Decidim
  module Voca
    module Deepl
      module DeeplFormBuilderOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :voca_original_translated, :translated
          ##
          # Rewrite of the translated method to avoid passing value to fields
          # translated by machine translation.
          #
          def translated(type, name, options = {})
            return translated_one_locale(type, name, locales.first, options.merge(label: (options[:label] || label_for(name)))) if locales.count == 1

            safe_join [
              label_tabs_tag(name, options),
              tabs_content_tag(type, name, options)
            ]
          end

          private

          def organization_context
            # deserialize the global id to get the organization
            @organization_context ||= GlobalID::Locator.locate(Decidim::Voca::DeeplContext.organization)
          end

          def tabs_content_tag(type, name, options = {})
            tabs_id = sanitized_tabs_id(name, options)
            hashtaggable = options.delete(:hashtaggable)
            default_locale = organization_context&.default_locale || ::Decidim.default_locale
            content_tag(:div, class: "tabs-content", data: { tabs_content: tabs_id }) do
              locales.each_with_index.inject("".html_safe) do |string, (locale, index)|
                options_for_field = options.deep_dup
                # If locale is not the default locale, value should be empty
                # to let machine translation do its job
                options_for_field[:value] = "".html_safe if locale.to_s != default_locale.to_s
                tab_content_id = "#{tabs_id}-#{name}-panel-#{index}"
                options_for_field[:"data-machine-tranlated"] = locale.to_s != default_locale.to_s
                string + content_tag(:div, class: tab_element_class_for("panel", index), id: tab_content_id, "aria-hidden": tab_attr_aria_hidden_for(index)) do
                  if hashtaggable
                    hashtaggable_text_field(type, name, locale, options_for_field.merge(label: false))
                  elsif type.to_sym == :editor
                    send(type, name_with_locale(name, locale), options_for_field.merge(label: false, hashtaggable:))
                  else
                    send(type, name_with_locale(name, locale), options_for_field.merge(label: false))
                  end
                end
              end
            end
          end

          def sanitized_tabs_id(name, options = {})
            sanitize_tabs_selector(options[:tabs_id] || "#{object_name}-#{name}-tabs")
          end

          def label_tabs_tag(name, options = {})
            tabs_id = sanitized_tabs_id(name, options)

            content_tag(:div, class: "label--tabs", "data-machine-translated": true) do
              field_label = label_i18n(name, options[:label] || label_for(name), required: options[:required])

              language_selector = "".html_safe
              language_selector = create_language_selector(locales, tabs_id, name) if options[:label] != false

              safe_join [field_label, language_selector]
            end
          end
        end
      end
    end
  end
end
