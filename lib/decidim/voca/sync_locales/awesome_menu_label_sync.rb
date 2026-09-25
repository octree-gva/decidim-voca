# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + machine-translates Awesome menu item +label+ hashes inline
      # (like {MachineTranslationEnqueuer} / {ContentBlockSettingSync}) so
      # +machine_translations+ is populated during +sync_locales+ without workers.
      class AwesomeMenuLabelSync
        def initialize(record)
          @record = record
        end

        def call
          return EnqueueStats.empty unless syncable?

          context = LocaleContext.for(@record)
          value = FieldHashNormalizer.deep_stringify(@record.value).deep_dup
          return EnqueueStats.empty unless value.is_a?(Array)

          stats = EnqueueStats.empty
          changed = false
          value.each do |item|
            next unless syncable_item?(item)

            item_changed, item_stats = sync_item_label!(item, context)
            changed = true if item_changed
            stats.add!(item_stats)
          end

          UpdateColumnWithoutCallbacks.call(@record, :value, value) if changed
          stats
        end

        private

        def syncable?
          defined?(Decidim::DecidimAwesome::AwesomeConfig) &&
            @record.is_a?(Decidim::DecidimAwesome::AwesomeConfig) &&
            AwesomeMenuLabels.menu_config_value?(@record.value)
        end

        def syncable_item?(item)
          item.is_a?(Hash) && item["label"].is_a?(Hash) && item["url"].present?
        end

        def sync_item_label!(item, context)
          raw = item["label"]
          stringy = FieldHashNormalizer.deep_stringify(raw)
          normalized = FieldHashNormalizer.call(raw, context)
          stats = translate_pending_inline!(item["url"], normalized, context)
          return [false, stats] if normalized == stringy

          item["label"] = normalized
          [true, stats]
        end

        def translate_pending_inline!(item_url, normalized, context)
          stats = EnqueueStats.empty
          return stats unless Decidim.machine_translation_service_klass
          return stats unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return stats if source_text.blank?

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
                html: false,
                context: "Decidim::DecidimAwesome::AwesomeConfig id=#{@record.id} url=#{item_url}"
              )
            end
            next if translated.nil?

            normalized["machine_translations"] ||= {}
            normalized["machine_translations"][target_locale] = translated
            stats.add!(EnqueueStats.new(enqueued: 1))
          end
          stats
        end
      end
    end
  end
end
