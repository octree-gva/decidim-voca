# frozen_string_literal: true

require "csv"

module Decidim
  module Voca
    module SyncLocales
      module TranslatableModels
        private

        def fields_for(model)
          @fields ||= {}
          @fields[model] ||= Array(model.translatable_fields_list).compact.map(&:to_s)
        end

        def translatable_models
          ActiveRecord::Base.descendants.select do |cls|
            next false if cls.name.blank?
            next false if cls.name.start_with?("Decidim::Dev::")
            next false if cls.abstract_class?
            next false unless cls.table_exists?
            next false unless cls.include?(Decidim::TranslatableResource)

            fields_for(cls).present?
          end
        end
      end

      # Eager-loads models, discovers TranslatableResource classes, normalizes each field.
      class Runner
        include TranslatableModels

        def call
          Rails.application.eager_load!
          translatable_models.each do |model|
            process_model(model)
          end
        end

        def process_model(model)
          fields = fields_for(model)
          return if fields.empty?

          $stdout.puts "Processing model: #{model.name}"
          model.unscoped.find_each do |record|
            process_record(record, fields)
          end
          $stdout.puts "[DONE][#{model.unscoped.count} records]"
        end

        def process_record(record, fields)
          fields.each do |field|
            raw = record.read_attribute(field)
            next unless raw.is_a?(Hash)

            context = LocaleContext.for(record)
            stringy = FieldHashNormalizer.deep_stringify(raw)
            normalized = FieldHashNormalizer.call(raw, context)
            # Bulk sync: bypass validations/callbacks (same intent as data migration tasks).
            # rubocop:disable Rails/SkipsModelValidations
            record.update_column(field, normalized) if normalized != stringy
            # rubocop:enable Rails/SkipsModelValidations
            MachineTranslationEnqueuer.new(record, field, context, normalized).call
          end

          ComponentSettingSync.new(record).call if record.is_a?(Decidim::Component)
        end
      end

      # Cleans translatable JSON hashes:
      # - removes locale roots that are no longer allowed
      # - prunes stale `machine_translations` entries in minimalistic Deepl mode
      class CleanMachineTranslationsRunner
        include TranslatableModels

        def initialize(dry_run:)
          @dry_run = dry_run
        end

        def call
          Rails.application.eager_load!

          translatable_models.each do |model|
            clean_model(model)
          end

          clean_component_settings
        end

        private

        def clean_model(model)
          fields = fields_for(model)
          return if fields.empty?

          model.unscoped.find_each do |record|
            context = LocaleContext.for(record)
            clean_record(record, context, model.name, fields)
          rescue Decidim::Voca::SyncLocales::MissingOrganizationContextError => e
            warn e.message
          end
        end

        def clean_record(record, context, model_name, fields)
          updated_columns = cleaned_columns(record, context, model_name, fields)
          return if @dry_run
          return if updated_columns.empty?

          # Maintenance task: avoid model validations/callbacks (especially important for
          # complex JSONB translation fields).
          # rubocop:disable Rails/SkipsModelValidations
          record.update_columns(updated_columns)
          # rubocop:enable Rails/SkipsModelValidations
        end

        def clean_component_settings
          Decidim::Component.unscoped.find_each do |record|
            global_keys = Decidim::Voca::ComponentSettingManifest.translated_global_keys(record.manifest)
            process_step_keys = Decidim::Voca::ComponentSettingManifest.translated_process_step_keys(record.manifest)
            next if global_keys.empty? && process_step_keys.empty?

            context = LocaleContext.for(record)
            clean_component_settings_record(record, context, global_keys, process_step_keys)
          rescue Decidim::Voca::SyncLocales::MissingOrganizationContextError => e
            warn e.message
          end
        end

        def clean_component_settings_record(record, context, global_keys, process_step_keys)
          settings = record.read_attribute(:settings).deep_dup.deep_stringify_keys
          touched = clean_global_settings!(settings, context, global_keys)
          touched ||= clean_step_settings!(settings, context, process_step_keys)

          return if @dry_run
          return unless touched

          # rubocop:disable Rails/SkipsModelValidations
          record.update_column(:settings, settings)
          # rubocop:enable Rails/SkipsModelValidations
        end

        def clean_global_settings!(settings, context, global_keys)
          global = settings["global"] ||= {}
          global_keys.any? do |key|
            clean_translated_setting_hash!(global, key, "settings[#{key}]", context)
          end
        end

        def clean_step_settings!(settings, context, process_step_keys)
          step_container = settings["step"] ||= {}
          return false unless step_container.is_a?(Hash)

          process_step_keys.any? do |step_key|
            clean_step_entries!(step_container, step_key, context)
          end
        end

        def clean_step_entries!(step_container, step_key, context)
          step_container.any? do |step_id, step_settings|
            next false unless step_settings.is_a?(Hash)

            clean_translated_setting_hash!(step_settings, step_key, step_csv_path(step_id, step_key), context)
          end
        end

        def step_csv_path(step_id, step_key)
          "settings[step][#{step_id}][#{step_key}]"
        end

        def clean_translated_setting_hash!(container, key, csv_field_path, context)
          current_value = container[key]
          return false unless current_value.is_a?(Hash)

          original_value = current_value.deep_dup
          clean_setting_value!(current_value, context)
          return false if current_value == original_value

          preview_component_setting(csv_field_path, original_value) if @dry_run
          container[key] = current_value
          !@dry_run
        end

        def clean_setting_value!(current_value, context)
          locale = context.default_locale
          other_locales = context.allowed_locales - [locale]
          return cleanup_non_minimalistic_hash!(current_value, other_locales) unless minimalistic_cleanup?(context)

          cleanup_hash!(current_value, locale, other_locales)
        end

        def preview_component_setting(csv_field_path, original_value)
          value_json = original_value.respond_to?(:as_json) ? original_value.as_json.to_json : original_value.to_json
          $stdout.puts CSV.generate_line([Decidim::Component.name, csv_field_path, value_json], col_sep: ";")
        end

        def promote_default_locale!(value, locale)
          mt_hash = machine_translations_hash(value)
          return unless value[locale].blank? && mt_hash&.[](locale).present?

          value[locale] = mt_hash.delete(locale)
        end

        def cleaned_columns(record, context, model_name, fields)
          fields.each_with_object({}) do |field, columns|
            original = record.send(field)
            next unless original.is_a?(Hash)
            next preview_field(model_name, field, original) if @dry_run

            cleaned = cleaned_value(original, context)
            columns[field.to_sym] = cleaned if cleaned != original
          end
        end

        def preview_field(model_name, field, value)
          json = value.respond_to?(:as_json) ? value.as_json.to_json : value.to_json
          $stdout.puts CSV.generate_line([model_name, field.to_s, json], col_sep: ";")
        end

        def cleaned_value(value, context)
          current_value = value.deep_dup
          locale = context.default_locale
          other_locales = context.allowed_locales - [locale]
          return cleanup_non_minimalistic_hash!(current_value, other_locales) unless minimalistic_cleanup?(context)

          cleanup_hash!(current_value, locale, other_locales)
        end

        def minimalistic_cleanup?(context)
          Decidim::Voca.minimalistic_deepl? && context.enable_machine_translations?
        end

        def cleanup_hash!(current_value, locale, other_locales)
          promote_default_locale!(current_value, locale)
          current_value.delete_if { |key, _value| kept_key?(key, locale) }
          prune_machine_translations!(current_value, other_locales)
          current_value
        end

        def cleanup_non_minimalistic_hash!(current_value, other_locales)
          other_locales.each { |other_locale| current_value.delete(other_locale) }
          current_value
        end

        def kept_key?(key, locale)
          key_str = key.to_s
          key_str != locale && key_str != "machine_translations"
        end

        def prune_machine_translations!(value, other_locales)
          mt_hash = machine_translations_hash(value)
          mt_hash&.delete_if { |key, _value| other_locales.exclude?(key.to_s) }
        end

        def machine_translations_hash(value)
          hash = value["machine_translations"] || value[:machine_translations]
          hash if hash.is_a?(Hash)
        end
      end
    end
  end
end
