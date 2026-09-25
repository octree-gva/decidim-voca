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
          return EnqueueStats.empty unless @record.is_a?(Decidim::ContentBlock)

          keys = Decidim::Voca::ContentBlockSettingManifest.translated_keys(@record.manifest)
          return EnqueueStats.empty if keys.empty?

          context = LocaleContext.for(@record)
          settings = (@record.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
          Decidim::Voca::ContentBlockSettingManifest.coalesce_flat_keys!(
            settings,
            keys,
            context.allowed_locales
          )

          stats = EnqueueStats.empty
          keys.each do |key|
            raw = settings[key]
            next unless raw.is_a?(Hash)

            normalized = FieldHashNormalizer.call(raw, context)
            stats.add!(translate_pending_inline!(key, normalized, context))
            settings[key] = normalized
          end

          Decidim::Voca::ContentBlockSettingManifest.expand_to_flat_keys!(settings, keys)
          original = FieldHashNormalizer.deep_stringify(@record.read_attribute(:settings) || {})
          UpdateColumnWithoutCallbacks.call(@record, :settings, settings) if settings != original
          stats
        end

        private

        def translate_pending_inline!(key, normalized, context)
          stats = EnqueueStats.empty
          return stats unless Decidim.machine_translation_service_klass
          return stats unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return stats if source_text.blank?

          html = rich_text_content_block_setting?(key)
          org = context.organization
          ComponentSettingPendingLocales.gaps(normalized, org).each do |target_locale|
            if ComponentSettingPendingLocales.machine_translated?(normalized, target_locale)
              stats.add!(EnqueueStats.new(skipped_existing: 1))
              next
            end

            translated = Decidim::Voca::DeepL::Context.with_organization(org) do
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
            stats.add!(EnqueueStats.new(enqueued: 1))
          end
          stats
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
