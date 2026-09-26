# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Normalizes + enqueues MT for translated global keys under +Component#settings+.
      class ComponentSettingSync
        def initialize(record)
          @record = record
        end

        def call
          return EnqueueStats.empty unless @record.is_a?(Decidim::Component)

          keys = Decidim::Voca::ComponentSettingManifest.translated_global_keys(@record.manifest)
          return EnqueueStats.empty if keys.empty?

          settings = (@record.read_attribute(:settings) || {}).deep_dup.deep_stringify_keys
          global = settings["global"] ||= {}
          changed = false
          context = LocaleContext.for(@record)
          stats = EnqueueStats.empty

          keys.each do |key|
            raw = global[key]
            next unless raw.is_a?(Hash)

            stringy = FieldHashNormalizer.deep_stringify(raw)
            normalized = FieldHashNormalizer.call(raw, context)
            if normalized != stringy
              global[key] = normalized
              changed = true
            end
            stats.add!(enqueue_for_key(key, normalized, context))
          end

          UpdateColumnWithoutCallbacks.call(@record, :settings, settings) if changed
          stats
        end

        private

        def enqueue_for_key(key, normalized, context)
          stats = EnqueueStats.empty
          return stats unless Decidim.machine_translation_service_klass
          return stats unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return stats if source_text.blank?

          org = context.organization
          ComponentSettingPendingLocales.gaps(normalized, org).each do |target_locale|
            if ComponentSettingPendingLocales.machine_translated?(normalized, target_locale, default)
              stats.add!(EnqueueStats.new(skipped_existing: 1))
              next
            end

            html = rich_text_component_setting?(key)
            Decidim::Voca::MachineTranslateComponentSettingJob
              .set(wait: Decidim.config.machine_translation_delay)
              .perform_later(@record.id, key, target_locale, default, html:)
            stats.add!(EnqueueStats.new(enqueued: 1))
          end
          stats
        end

        def rich_text_component_setting?(key)
          attr = @record.manifest.settings(:global).attributes[key.to_sym]
          return true unless attr
          return false unless attr.type == :text

          ctx = { component: @record, participatory_space: @record.participatory_space }
          attr.editor?(ctx) == true
        rescue StandardError
          true
        end
      end
    end
  end
end
