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

        field = component.read_attribute(:settings).deep_dup.deep_stringify_keys.dig("global", setting_key.to_s)
        return unless field.is_a?(Hash)

        source_text = field[source_locale.to_s].presence || field[source_locale.to_sym].presence
        return if source_text.blank?

        context = "Decidim::Component id=#{component_id} setting=#{setting_key}"
        translated = MachineTranslation::TranslateString.call(
          text: source_text,
          source_locale: source_locale,
          target_locale: target_locale,
          html: html,
          context: context
        )
        return if translated.nil?

        component.with_lock do
          fresh = component.reload.read_attribute(:settings).deep_dup.deep_stringify_keys
          fg = fresh["global"] ||= {}
          f = fg[setting_key.to_s]
          if f.is_a?(Hash)
            f["machine_translations"] ||= {}
            f["machine_translations"][target_locale.to_s] = translated
            component.update_column(:settings, fresh)
          end
        end
      end
    end
  end
end
