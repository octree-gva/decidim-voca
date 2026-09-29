# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + machine-translates translated keys under +ContentBlock#settings+.
      # Translates inline (like {MachineTranslationEnqueuer}) and persists Decidim flat keys
      # (+welcome_text_fr+ / +welcome_text_en+) so EN is populated after +sync_locales+.
      class ContentBlockSettingSync
        def initialize(record)
          @record = record
        end

        def call
          return unless @record.is_a?(Decidim::ContentBlock)

          keys = Decidim::Voca::ContentBlockSettingManifest.translated_keys(@record.manifest)
          return if keys.empty?

          context = LocaleContext.for(@record)
          settings = (@record.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
          Decidim::Voca::ContentBlockSettingManifest.coalesce_flat_keys!(
            settings,
            keys,
            context.allowed_locales
          )

          keys.each do |key|
            raw = settings[key]
            next unless raw.is_a?(Hash)

            normalized = FieldHashNormalizer.call(raw, context)
            translate_pending_inline!(key, normalized, context)
            settings[key] = normalized
          end

          Decidim::Voca::ContentBlockSettingManifest.expand_to_flat_keys!(settings, keys)
          original = FieldHashNormalizer.deep_stringify(@record.read_attribute(:settings) || {})
          return if settings == original

          UpdateColumnWithoutCallbacks.call(@record, :settings, settings)
        end

        private

        def translate_pending_inline!(key, normalized, context)
          return unless Decidim.machine_translation_service_klass
          return unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return if source_text.blank?

          html = rich_text_content_block_setting?(key)
          ComponentSettingPendingLocales.for(normalized, context.organization).each do |target_locale|
            next if normalized.dig("machine_translations", target_locale).present?

            translated = Decidim::Voca::DeepL::Context.with_organization(context.organization) do
              MachineTranslation::TranslateString.call(
                text: source_text,
                source_locale: default,
                target_locale:,
                html:,
                context: "Decidim::ContentBlock id=#{@record.id} setting=#{key}"
              )
            end
            next if translated.nil?

            normalized["machine_translations"] ||= {}
            normalized["machine_translations"][target_locale] = translated
          end
        end

        def rich_text_content_block_setting?(key)
          attr = @record.manifest.settings.attributes[key.to_sym]
          return false unless attr
          return false unless attr.type == :text

          attr.editor?({}) == true
        rescue StandardError
          false
        end
      end
    end
  end
end
