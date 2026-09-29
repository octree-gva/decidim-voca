# frozen_string_literal: true

module Decidim
  module Voca
    # Enqueues {MachineTranslateAwesomeMenuLabelJob} when Awesome menu item labels change.
    module AwesomeMenuLabelMachineTranslation
      extend ActiveSupport::Concern

      included do
        after_create :enqueue_awesome_menu_label_machine_translation
        after_update :enqueue_awesome_menu_label_machine_translation
      end

      def enqueue_awesome_menu_label_machine_translation
        return unless enqueue_awesome_menu_label_mt_prerequisites?

        change = saved_changes["value"] || saved_changes[:value]
        return if change.blank?

        org = organization
        default = org.default_locale.to_s
        old_items = menu_items_from(change[0])
        new_items = menu_items_from(change[1])

        new_items.each { |item| enqueue_item_if_default_locale_changed(item, old_items, default, org) }
      end

      private

      def enqueue_awesome_menu_label_mt_prerequisites?
        saved_change_to_value? &&
          AwesomeMenuLabels.menu_config_value?(value) &&
          Decidim.machine_translation_service_klass &&
          organization&.enable_machine_translations?
      end

      def menu_items_from(raw)
        AwesomeMenuLabels.menu_items(raw)
      end

      def enqueue_item_if_default_locale_changed(item, old_items, default, org)
        url = item["url"].to_s
        return if url.blank?

        new_label = item["label"]
        return unless new_label.is_a?(Hash)

        old_item = old_items.find { |i| i["url"].to_s == url }
        old_label = old_item.is_a?(Hash) ? old_item["label"] : nil
        return unless label_default_locale_changed?(old_label, new_label, default)

        schedule_label_jobs(url, new_label, org)
      end

      def label_default_locale_changed?(old_h, new_h, default)
        old_h = old_h.deep_stringify_keys if old_h.is_a?(Hash)
        new_h = new_h.deep_stringify_keys
        old_v = old_h.is_a?(Hash) ? old_h[default] : nil
        new_v = new_h[default]
        old_v != new_v
      end

      def schedule_label_jobs(item_url, field_hash, org)
        default = org.default_locale.to_s
        ComponentSettingPendingLocales.for(field_hash, org).each do |target|
          MachineTranslateAwesomeMenuLabelJob
            .set(wait: Decidim.config.machine_translation_delay)
            .perform_later(id, item_url, target, default)
        end
      end
    end
  end
end
