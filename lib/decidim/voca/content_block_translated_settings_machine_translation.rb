# frozen_string_literal: true

module Decidim
  module Voca
    # Enqueues {MachineTranslateContentBlockSettingJob} when translated settings change.
    module ContentBlockTranslatedSettingsMachineTranslation
      extend ActiveSupport::Concern

      included do
        # Use after_save (not after_commit) so +saved_changes+ is present; nested MT persists
        # via +update_column+ and does not re-fire these callbacks.
        after_create :enqueue_content_block_translated_settings_machine_translation
        after_update :enqueue_content_block_translated_settings_machine_translation
      end

      def enqueue_content_block_translated_settings_machine_translation
        return unless enqueue_content_block_translated_settings_mt_prerequisites?

        change = saved_changes["settings"] || saved_changes[:settings]
        return if change.blank?

        org = organization
        keys = ContentBlockSettingManifest.translated_keys(manifest)
        return if keys.empty?

        locales = org.available_locales.map(&:to_s)
        old_s = extract_settings(change[0], keys, locales)
        new_s = extract_settings(change[1], keys, locales)

        keys.each do |key|
          enqueue_setting_if_default_locale_changed(key, old_s, new_s, org)
        end
      end

      private

      def enqueue_content_block_translated_settings_mt_prerequisites?
        saved_change_to_settings? &&
          Decidim.machine_translation_service_klass &&
          organization&.enable_machine_translations?
      end

      def extract_settings(raw, keys, locales)
        return {} if raw.blank?

        hash =
          if raw.is_a?(Hash)
            raw
          elsif raw.respond_to?(:to_h)
            raw.to_h
          else
            {}
          end

        settings = hash.deep_stringify_keys.deep_dup
        ContentBlockSettingManifest.coalesce_flat_keys!(settings, keys, locales)
        settings
      end

      def enqueue_setting_if_default_locale_changed(key, old_s, new_s, org)
        old_h = old_s[key]
        new_h = new_s[key]
        return unless new_h.is_a?(Hash)
        return unless setting_default_locale_changed?(old_h, new_h, org.default_locale.to_s)

        schedule_setting_jobs(key, new_h, org)
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
        html = rich_text_content_block_setting?(key)

        pending.each do |target|
          MachineTranslateContentBlockSettingJob
            .set(wait: Decidim.config.machine_translation_delay)
            .perform_later(id, key, target, default, html:)
        end
      end

      def rich_text_content_block_setting?(key)
        attr = manifest.settings.attributes[key.to_sym]
        return false unless attr
        return false unless attr.type == :text

        attr.editor?({}) == true
      rescue StandardError
        false
      end
    end
  end
end
