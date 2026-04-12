# frozen_string_literal: true

module Decidim
  module Voca
    # Under minimalistic Deepl, only the organization default locale is authoritative for human
    # input; other locale slots may contain defaults or noise. Core Decidim treats any present
    # locale as "already translated", which skips MT. This prepended module narrows
    # +translated_locales_list+ so only the default locale blocks +pending_locales+.
    module MachineTranslationResourceJobVoca
      # Core passes +I18n.locale+ as +source_locale+; under minimalistic Deepl the authoritative
      # human string lives in the organization default slot only (+website/docs/machine_translation.md+).
      def resource_field_value(previous_changes, field, source_locale)
        source_locale = default_locale(@resource) if voca_minimalistic_pending_locales_mode?
        super
      end

      def translated_locales_list(field)
        if voca_minimalistic_pending_locales_mode?
          dl = default_locale(@resource)
          hash = @resource[field]
          return [] unless hash.is_a?(Hash)

          value = hash[dl].presence || hash[dl.to_sym].presence
          return [] if value.blank?

          [dl]
        else
          super
        end
      end

      private

      def voca_minimalistic_pending_locales_mode?
        return false unless Decidim::Voca.minimalistic_deepl?
        return false unless @resource.respond_to?(:organization)

        org = @resource.organization
        org && org.enable_machine_translations?
      end
    end
  end
end
