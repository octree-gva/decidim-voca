# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + enqueues MT for translated keys under +ContentBlock#settings+.
      class ContentBlockSettingSync
        def initialize(record)
          @record = record
        end

        def call
          return unless @record.is_a?(Decidim::ContentBlock)

          keys = Decidim::Voca::ContentBlockSettingManifest.translated_keys(@record.manifest)
          return if keys.empty?

          context = LocaleContext.for(@record)
          settings = @record.read_attribute(:settings).deep_dup.deep_stringify_keys
          Decidim::Voca::ContentBlockSettingManifest.coalesce_flat_keys!(
            settings,
            keys,
            context.allowed_locales
          )

          changed = false
          keys.each do |key|
            raw = settings[key]
            next unless raw.is_a?(Hash)

            stringy = FieldHashNormalizer.deep_stringify(raw)
            normalized = FieldHashNormalizer.call(raw, context)
            if normalized != stringy
              settings[key] = normalized
              changed = true
            end
            enqueue_for_key(key, normalized, context)
          end

          # Always persist coalesced flat→nested even when normalizer was a no-op.
          original = FieldHashNormalizer.deep_stringify(@record.read_attribute(:settings) || {})
          changed ||= settings != original
          return unless changed

          UpdateColumnWithoutCallbacks.call(@record, :settings, settings)
        end

        private

        def enqueue_for_key(key, normalized, context)
          return unless Decidim.machine_translation_service_klass
          return unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return if source_text.blank?

          ComponentSettingPendingLocales.for(normalized, context.organization).each do |target_locale|
            html = rich_text_content_block_setting?(key)
            Decidim::Voca::MachineTranslateContentBlockSettingJob
              .set(wait: Decidim.config.machine_translation_delay)
              .perform_later(@record.id, key, target_locale, default, html:)
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
