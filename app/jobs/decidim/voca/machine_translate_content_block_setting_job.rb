# frozen_string_literal: true

module Decidim
  module Voca
    # Persists machine translation for a single translated content-block setting.
    # Writes Decidim-canonical flat keys (+welcome_text_en+) so front/admin resolve EN.
    class MachineTranslateContentBlockSettingJob < Decidim::ApplicationJob
      queue_as :translations

      # @param html [Boolean] rich text (+true+) vs plain (+false+)
      def perform(content_block_id, setting_key, target_locale, source_locale, html: false)
        return unless Decidim.machine_translation_service_klass

        content_block = Decidim::ContentBlock.find_by(id: content_block_id)
        return unless content_block

        source_text = extract_source_text(content_block, setting_key, source_locale)
        return if source_text.blank?

        translated = translate_text(
          source_text,
          source_locale,
          target_locale,
          html,
          "Decidim::ContentBlock id=#{content_block.id} setting=#{setting_key}"
        )
        return if translated.nil?

        content_block.with_lock do
          merge_translation_into_settings(content_block, setting_key, target_locale, source_locale, translated)
        end
      end

      private

      def extract_source_text(content_block, setting_key, source_locale)
        settings = (content_block.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
        keys = [setting_key.to_s]
        locales = content_block.organization.available_locales.map(&:to_s)
        ContentBlockSettingManifest.coalesce_flat_keys!(settings, keys, locales)

        field = settings[setting_key.to_s]
        return unless field.is_a?(Hash)

        field[source_locale.to_s].presence || field[source_locale.to_sym].presence
      end

      def translate_text(source_text, source_locale, target_locale, html, context)
        MachineTranslation::TranslateString.call(
          text: source_text,
          source_locale:,
          target_locale:,
          html:,
          context:
        )
      end

      def merge_translation_into_settings(content_block, setting_key, target_locale, source_locale, translated)
        fresh = (content_block.reload.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
        keys = [setting_key.to_s]
        locales = content_block.organization.available_locales.map(&:to_s)
        ContentBlockSettingManifest.coalesce_flat_keys!(fresh, keys, locales)

        field = fresh[setting_key.to_s]
        return unless field.is_a?(Hash)

        field["machine_translations"] ||= {}
        field["machine_translations"][target_locale.to_s] = translated
        # Keep human source at the default locale root for expand.
        field[source_locale.to_s] ||= extract_source_from_field(field, source_locale)

        ContentBlockSettingManifest.expand_to_flat_keys!(fresh, keys)
        UpdateColumnWithoutCallbacks.call(content_block, :settings, fresh)
      end

      def extract_source_from_field(field, source_locale)
        field[source_locale.to_s].presence || field[source_locale.to_sym].presence
      end
    end
  end
end
