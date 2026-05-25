# frozen_string_literal: true

require_relative "machine_translation_human_source"

module Decidim
  module Voca
    # Under minimalistic Deepl, core Decidim treats any present locale as "already translated",
    # which skips MT. This prepended module narrows +translated_locales_list+ so only the
    # organization default blocks +pending_locales+ when the default slot has human text.
    #
    # When the default slot is empty but another locale has content (typical participant UI in
    # a non-default language), we delegate +translated_locales_list+ to core and resolve
    # +resource_field_value+ from the job's +source_locale+ (+I18n.locale+) or the first filled
    # locale in +organization.available_locales+ order — see +MachineTranslationHumanSource+.
    module MachineTranslationResourceJobVoca
      def resource_field_value(previous_changes, field, source_locale)
        if voca_minimalistic_pending_locales_mode?
          values = previous_changes[field]
          new_value = values&.last
          if new_value.is_a?(Hash) && @resource.respond_to?(:organization) && @resource.organization
            org = @resource.organization
            dl = default_locale(@resource)
            if new_value.stringify_keys[dl].presence
              source_locale = dl
            else
              resolved = MachineTranslationHumanSource.authoring_locale(org, new_value, source_locale)
              source_locale = resolved if resolved.present?
            end
          end
        end
        super
      end

      def translated_locales_list(field)
        if voca_minimalistic_pending_locales_mode?
          dl = default_locale(@resource)
          hash = @resource[field]
          return super unless hash.is_a?(Hash)

          value = hash[dl].presence || hash[dl.to_sym].presence
          return super if value.blank?

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
