# frozen_string_literal: true

module Decidim
  module Voca
    # Enqueues {MachineTranslateComponentSettingJob} when translated global settings change.
    module ComponentTranslatedSettingsMachineTranslation
      extend ActiveSupport::Concern

      included do
        # Use after_save callbacks (not after_commit) so +saved_changes+ is present; nested MT persists
        # via +update_column+ and does not re-fire these callbacks.
        after_create :enqueue_component_translated_settings_machine_translation
        after_update :enqueue_component_translated_settings_machine_translation
      end

      def enqueue_component_translated_settings_machine_translation
        return unless saved_change_to_settings?
        return unless Decidim.machine_translation_service_klass

        org = organization
        return unless org&.enable_machine_translations?

        change = saved_changes["settings"] || saved_changes[:settings]
        return if change.blank?

        old_s, new_s = change
        old_g = extract_global(old_s)
        new_g = extract_global(new_s)

        ComponentSettingManifest.translated_global_keys(manifest).each do |key|
          old_h = old_g[key]
          new_h = new_g[key]
          next unless new_h.is_a?(Hash)

          next unless setting_default_locale_changed?(old_h, new_h, org.default_locale.to_s)

          schedule_setting_jobs(key, new_h, org)
        end
      end

      private

      def extract_global(settings)
        return {} if settings.blank?

        settings.deep_stringify_keys["global"].presence || {}
      end

      def setting_default_locale_changed?(old_h, new_h, default)
        old_h = old_h.deep_stringify_keys if old_h.is_a?(Hash)
        new_h = new_h.deep_stringify_keys
        old_v = old_h.is_a?(Hash) ? old_h[default] : nil
        new_v = new_h[default]
        old_v != new_v
      end

      def schedule_setting_jobs(key, field_hash, org)
        default = org.default_locale.to_s
        pending = ComponentSettingPendingLocales.for(field_hash, org)
        html = rich_text_component_setting?(key)

        pending.each do |target|
          MachineTranslateComponentSettingJob
            .set(wait: Decidim.config.machine_translation_delay)
            .perform_later(id, key, target, default, html: html)
        end
      end

      def rich_text_component_setting?(key)
        attr = manifest.settings(:global).attributes[key.to_sym]
        return true unless attr
        return false unless attr.type == :text

        ctx = { component: self, participatory_space: participatory_space }
        attr.editor?(ctx) == true
      rescue StandardError
        true
      end
    end
  end
end
