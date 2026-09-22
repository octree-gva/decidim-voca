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
          return unless syncable?

          context = LocaleContext.for(@record)
          value = FieldHashNormalizer.deep_stringify(@record.value).deep_dup
          return unless value.is_a?(Array)

          changed = sync_items!(value, context)
          return unless changed

          UpdateColumnWithoutCallbacks.call(@record, :value, value)
        end

        private

        def syncable?
          defined?(Decidim::DecidimAwesome::AwesomeConfig) &&
            @record.is_a?(Decidim::DecidimAwesome::AwesomeConfig) &&
            AwesomeMenuLabels.menu_config_value?(@record.value)
        end

        def sync_items!(value, context)
          changed = false
          value.each do |item|
            next unless syncable_item?(item)

            changed = true if sync_item_label!(item, context)
          end
          changed
        end

        def syncable_item?(item)
          item.is_a?(Hash) && item["label"].is_a?(Hash) && item["url"].present?
        end

        def sync_item_label!(item, context)
          raw = item["label"]
          stringy = FieldHashNormalizer.deep_stringify(raw)
          normalized = FieldHashNormalizer.call(raw, context)
          translate_pending_inline!(item["url"], normalized, context)
          return false if normalized == stringy

          item["label"] = normalized
          true
        end

        def translate_pending_inline!(item_url, normalized, context)
          return unless Decidim.machine_translation_service_klass
          return unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return if source_text.blank?

          ComponentSettingPendingLocales.for(normalized, context.organization).each do |target_locale|
            next if normalized.dig("machine_translations", target_locale).present?

            translated = Decidim::Voca::DeepL::Context.with_organization(context.organization) do
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
          end
        end
      end
    end
  end
end
