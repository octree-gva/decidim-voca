# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + enqueues MT for Awesome menu item +label+ locale hashes.
      class AwesomeMenuLabelSync
        def initialize(record)
          @record = record
        end

        def call
          return unless defined?(Decidim::DecidimAwesome::AwesomeConfig)
          return unless @record.is_a?(Decidim::DecidimAwesome::AwesomeConfig)
          return unless AwesomeMenuLabels.menu_config_value?(@record.value)

          context = LocaleContext.for(@record)
          items = AwesomeMenuLabels.menu_items(@record.value)
          changed = false

          items.each do |item|
            raw = item["label"]
            stringy = FieldHashNormalizer.deep_stringify(raw)
            normalized = FieldHashNormalizer.call(raw, context)
            if normalized != stringy
              item["label"] = normalized
              changed = true
            end
            enqueue_for_item(item["url"], normalized, context)
          end

          return unless changed

          # rubocop:disable Rails/SkipsModelValidations
          @record.update_column(:value, items)
          # rubocop:enable Rails/SkipsModelValidations
        end

        private

        def enqueue_for_item(item_url, normalized, context)
          return unless Decidim.machine_translation_service_klass
          return unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return if source_text.blank?

          ComponentSettingPendingLocales.for(normalized, context.organization).each do |target_locale|
            Decidim::Voca::MachineTranslateAwesomeMenuLabelJob
              .set(wait: Decidim.config.machine_translation_delay)
              .perform_later(@record.id, item_url, target_locale, default)
          end
        end
      end
    end
  end
end
