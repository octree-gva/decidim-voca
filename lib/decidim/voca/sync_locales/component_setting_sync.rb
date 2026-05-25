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
          return unless @record.is_a?(Decidim::Component)

          keys = Decidim::Voca::ComponentSettingManifest.translated_global_keys(@record.manifest)
          return if keys.empty?

          settings = @record.read_attribute(:settings).deep_dup.deep_stringify_keys
          global = settings["global"] ||= {}
          changed = false
          context = LocaleContext.for(@record)

          keys.each do |key|
            raw = global[key]
            next unless raw.is_a?(Hash)

            stringy = FieldHashNormalizer.deep_stringify(raw)
            normalized = FieldHashNormalizer.call(raw, context)
            if normalized != stringy
              global[key] = normalized
              changed = true
            end
            enqueue_for_key(key, normalized, context)
          end

          return unless changed

          # rubocop:disable Rails/SkipsModelValidations
          @record.update_column(:settings, settings)
          # rubocop:enable Rails/SkipsModelValidations
        end

        private

        def enqueue_for_key(key, normalized, context)
          return unless Decidim.machine_translation_service_klass
          return unless context.enable_machine_translations?

          default = context.default_locale
          source_text = normalized.stringify_keys[default]
          return if source_text.blank?

          ComponentSettingPendingLocales.for(normalized, context.organization).each do |target_locale|
            html = rich_text_component_setting?(key)
            Decidim::Voca::MachineTranslateComponentSettingJob
              .set(wait: Decidim.config.machine_translation_delay)
              .perform_later(@record.id, key, target_locale, default, html:)
          end
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
