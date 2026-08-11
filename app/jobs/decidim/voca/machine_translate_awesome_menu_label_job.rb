# frozen_string_literal: true

module Decidim
  module Voca
    # Persists machine translation for one Awesome menu item label (nested JSONB in +value+).
    class MachineTranslateAwesomeMenuLabelJob < Decidim::ApplicationJob
      queue_as :translations

      def perform(awesome_config_id, item_url, target_locale, source_locale)
        return unless Decidim.machine_translation_service_klass
        return unless defined?(Decidim::DecidimAwesome::AwesomeConfig)

        config = Decidim::DecidimAwesome::AwesomeConfig.find_by(id: awesome_config_id)
        return unless config

        source_text = extract_source_text(config, item_url, source_locale)
        return if source_text.blank?

        persist_machine_translation(config, item_url, target_locale, source_locale, source_text)
      end

      private

      def extract_source_text(config, item_url, source_locale)
        item = find_item(config.value, item_url)
        return unless item

        label = item["label"]
        return unless label.is_a?(Hash)

        label[source_locale.to_s].presence || label[source_locale.to_sym].presence
      end

      def persist_machine_translation(config, item_url, target_locale, source_locale, source_text)
        context = "Decidim::DecidimAwesome::AwesomeConfig id=#{config.id} url=#{item_url}"
        translated = MachineTranslation::TranslateString.call(
          text: source_text,
          source_locale:,
          target_locale:,
          html: false,
          context:
        )
        return if translated.nil?

        config.with_lock do
          merge_translation_into_value(config, item_url, target_locale, translated)
        end
      end

      def merge_translation_into_value(config, item_url, target_locale, translated)
        items = AwesomeMenuLabels.menu_items(config.reload.value)
        item = items.find { |i| i["url"].to_s == item_url.to_s }
        return unless item

        label = item["label"]
        return unless label.is_a?(Hash)

        label["machine_translations"] ||= {}
        label["machine_translations"][target_locale.to_s] = translated
        # rubocop:disable Rails/SkipsModelValidations -- nested JSONB merge must not re-run after_save MT callbacks
        config.update_column(:value, items)
        # rubocop:enable Rails/SkipsModelValidations
      end

      def find_item(value, item_url)
        AwesomeMenuLabels.menu_items(value).find { |i| i["url"].to_s == item_url.to_s }
      end
    end
  end
end
