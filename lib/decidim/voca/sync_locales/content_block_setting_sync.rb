# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + machine-translates translated keys under +ContentBlock#settings+.
      # Persists Decidim flat keys (+welcome_text_fr+ / +html_content_en+) for cells/admin.
      class ContentBlockSettingSync
        def initialize(record)
          @record = record
        end

        def call
          return EnqueueStats.empty unless syncable?

          context = LocaleContext.for(@record)
          settings = coalesce_settings(context)
          stats = sync_translated_keys!(settings, context)
          persist_settings!(settings)
          stats
        end

        private

        def syncable?
          @record.is_a?(Decidim::ContentBlock) && keys.any?
        end

        def keys
          @keys ||= Decidim::Voca::ContentBlockSettingManifest.translated_keys(@record.manifest)
        end

        def coalesce_settings(context)
          settings = (@record.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
          Decidim::Voca::ContentBlockSettingManifest.coalesce_flat_keys!(
            settings,
            keys,
            context.allowed_locales
          )
          settings
        end

        def sync_translated_keys!(settings, context)
          stats = EnqueueStats.empty
          keys.each { |key| stats.add!(sync_one_key!(settings, key, context)) }
          Decidim::Voca::ContentBlockSettingManifest.expand_to_flat_keys!(settings, keys)
          stats
        end

        def sync_one_key!(settings, key, context)
          raw = settings[key]
          return EnqueueStats.empty unless raw.is_a?(Hash)

          normalized = FieldHashNormalizer.call(raw, context)
          settings[key] = normalized
          translate_pending_inline!(key, normalized, context)
        end

        def persist_settings!(settings)
          original = FieldHashNormalizer.deep_stringify(@record.read_attribute(:settings) || {})
          UpdateColumnWithoutCallbacks.call(@record, :settings, settings) if settings != original
        end

        def translate_pending_inline!(key, normalized, context)
          stats = EnqueueStats.empty
          return stats unless can_translate?(context, normalized)

          opts = translation_opts(key, normalized, context)
          ComponentSettingPendingLocales.gaps(normalized, opts[:org]).each do |target|
            stats.add!(fill_target!(normalized, target, opts))
          end
          stats
        end

        def translation_opts(key, normalized, context)
          source = normalized.stringify_keys[context.default_locale]
          {
            source:,
            default: context.default_locale,
            org: context.organization,
            key:,
            html: rich_text_content_block_setting?(key, source)
          }
        end

        def can_translate?(context, normalized)
          Decidim.machine_translation_service_klass &&
            context.enable_machine_translations? &&
            normalized.stringify_keys[context.default_locale].present?
        end

        def fill_target!(normalized, target, opts)
          return EnqueueStats.new(skipped_existing: 1) if ComponentSettingPendingLocales.machine_translated?(normalized, target, opts[:default])

          translated = translate_setting(opts, target)
          return EnqueueStats.empty if translated.nil?

          (normalized["machine_translations"] ||= {})[target] = translated
          EnqueueStats.new(enqueued: 1)
        end

        def translate_setting(opts, target)
          Decidim::Voca::DeepL::Context.with_organization(opts[:org]) do
            MachineTranslation::TranslateString.call(
              text: opts[:source],
              source_locale: opts[:default],
              target_locale: target,
              html: opts[:html],
              context: "Decidim::ContentBlock id=#{@record.id} setting=#{opts[:key]}"
            )
          end
        end

        def rich_text_content_block_setting?(key, source = nil)
          return true if key.to_s == "html_content"
          return true if html_markup?(source)

          attr = @record.manifest.settings.attributes[key.to_sym]
          return false unless attr&.type == :text

          attr.editor?({}) == true
        rescue StandardError
          false
        end

        def html_markup?(text)
          text.to_s.match?(/<[a-z][\s\S]*>/i)
        end
      end
    end
  end
end
