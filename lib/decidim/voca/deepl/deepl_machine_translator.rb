# frozen_string_literal: true

# Use +Gem.loaded_specs+ here: this file is required from +decidim/voca.rb+ before +module Decidim::Voca+
# defines +deepl_installed?+.
if Gem.loaded_specs.has_key?("deepl-rb")
  require "deepl"
  require "active_support"
  require_relative "../machine_translation/translate_string"

  module Decidim
    module Voca
      class DeeplMachineTranslator
        attr_reader :text, :source_locale, :target_locale, :resource, :field_name

        include Decidim::TranslatableAttributes

        def initialize(resource, field_name, text, target_locale, source_locale)
          @resource = resource
          @field_name = field_name
          @text = text
          @target_locale = target_locale
          @source_locale = source_locale
        end

        def translate
          return if text.blank?

          translation = MachineTranslation::TranslateString.call(
            text:,
            source_locale:,
            target_locale:,
            html: true,
            context: deepl_context
          )
          return if translation.nil?

          Decidim::MachineTranslationSaveJob.perform_later(
            resource,
            field_name,
            target_locale,
            translation
          )
        end

        private

        def deepl_context
          base = Decidim::Voca::DeeplContext.deepl_context
          "This is a text for a #{resource.class.name.demodulize.titleize} #{name_context}, field #{field_name}. #{base}"
        end

        def name_context
          return "" if field_name == "title"
          return ", named #{translated_attribute(resource.title)}" if resource.respond_to?(:title)
          return ", named #{translated_attribute(resource.name)}" if resource.respond_to?(:name)

          ""
        end
      end
    end
  end
end
