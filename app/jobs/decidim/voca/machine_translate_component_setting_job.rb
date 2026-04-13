# frozen_string_literal: true

module Decidim
  module Voca
    # Persists machine translation for a single translated global component setting (nested JSONB).
    class MachineTranslateComponentSettingJob < Decidim::ApplicationJob
      queue_as :translations

      # @param html [Boolean] rich text (+true+) vs plain (+false+)
      def perform(component_id, setting_key, target_locale, source_locale, html: true)
        return unless Decidim.machine_translation_service_klass

        component = Decidim::Component.find_by(id: component_id)
        return unless component

        source_text = extract_source_text(component, setting_key, source_locale)
        return if source_text.blank?

        persist_machine_translation(component, setting_key, target_locale, source_locale, source_text, html)
      end

      private

      def extract_source_text(component, setting_key, source_locale)
        field = component.read_attribute(:settings).deep_dup.deep_stringify_keys.dig("global", setting_key.to_s)
        return unless field.is_a?(Hash)

        field[source_locale.to_s].presence || field[source_locale.to_sym].presence
      end

      # rubocop:disable Metrics/ParameterLists -- mirrors #perform arguments split for complexity
      def persist_machine_translation(component, setting_key, target_locale, source_locale, source_text, html)
        context = "Decidim::Component id=#{component.id} setting=#{setting_key}"
        translated = MachineTranslation::TranslateString.call(
          text: source_text,
          source_locale:,
          target_locale:,
          html:,
          context:
        )
        return if translated.nil?

        component.with_lock do
          merge_translation_into_settings(component, setting_key, target_locale, translated)
        end
      end
      # rubocop:enable Metrics/ParameterLists

      def merge_translation_into_settings(component, setting_key, target_locale, translated)
        fresh = component.reload.read_attribute(:settings).deep_dup.deep_stringify_keys
        fg = fresh["global"] ||= {}
        f = fg[setting_key.to_s]
        return unless f.is_a?(Hash)

        f["machine_translations"] ||= {}
        f["machine_translations"][target_locale.to_s] = translated
        # rubocop:disable Rails/SkipsModelValidations -- nested JSONB merge must not re-run after_save MT callbacks
        component.update_column(:settings, fresh)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end
end
