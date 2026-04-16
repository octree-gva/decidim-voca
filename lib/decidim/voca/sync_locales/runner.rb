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
          locale = context.default_locale
          other_locales = context.allowed_locales - [locale]
          minimalistic_cleanup = Decidim::Voca.minimalistic_deepl? && context.enable_machine_translations?

          touched = false
          updated_columns = {}

          fields.each do |field|
            current_value = record.send(field)
            next unless current_value.is_a?(Hash)

            original_value = current_value.deep_dup

            if @dry_run
              value_json = current_value.respond_to?(:as_json) ? current_value.as_json.to_json : current_value.to_json
              $stdout.puts CSV.generate_line([model_name, field.to_s, value_json], col_sep: ";")
              next
            end

            # In minimalistic Deepl mode, non-default locale roots are placeholders.
            # Cleanup should remove them even when the locale is no longer part of `available_locales`,
            # and also prune stale entries inside `machine_translations`.
            if minimalistic_cleanup
              current_value.delete_if do |key, _value|
                key_str = key.to_s
                key_str != locale && key_str != "machine_translations"
              end

              mt_hash = current_value["machine_translations"] || current_value[:machine_translations]
              if mt_hash.is_a?(Hash)
                mt_hash.delete_if { |k, _v| !other_locales.include?(k.to_s) }
              end
            else
              # Remove all non-default locale roots, but keep whatever lives under `machine_translations`.
              current_value.delete_if do |key, _value|
                other_locales.include?(key.to_s)
              end
            end

            next if current_value == original_value

            touched = true
            updated_columns[field.to_sym] = current_value
          end

          return if @dry_run
          return unless touched

          # Maintenance task: avoid model validations/callbacks (especially important for
          # complex JSONB translation fields).
          record.update_columns(updated_columns)
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
          locale = context.default_locale
          other_locales = context.allowed_locales - [locale]
          minimalistic_cleanup = Decidim::Voca.minimalistic_deepl? && context.enable_machine_translations?

          settings = record.read_attribute(:settings).deep_dup.deep_stringify_keys
          global = settings["global"] ||= {}
          touched = false

          clean_translated_setting_hash = lambda do |container, key, csv_field_path|
            current_value = container[key]
            return unless current_value.is_a?(Hash)

            original_value = current_value.deep_dup

            if minimalistic_cleanup
              current_value.delete_if do |setting_key, _value|
                setting_key_str = setting_key.to_s
                setting_key_str != locale && setting_key_str != "machine_translations"
              end

              mt_hash = current_value["machine_translations"] || current_value[:machine_translations]
              if mt_hash.is_a?(Hash)
                mt_hash.delete_if { |k, _v| !other_locales.include?(k.to_s) }
              end
            else
              # Non-minimalistic mode keeps machine translations; just remove locale roots
              # that are no longer human-filled.
              other_locales.each { |other_locale| current_value.delete(other_locale) }
            end

            return if current_value == original_value

            if @dry_run
              value_json = original_value.respond_to?(:as_json) ? original_value.as_json.to_json : original_value.to_json
              $stdout.puts CSV.generate_line(
                [Decidim::Component.name, csv_field_path, value_json],
                col_sep: ";"
              )
            else
              touched = true
            end

            container[key] = current_value
          end

          global_keys.each do |key|
            clean_translated_setting_hash.call(global, key, "settings[#{key}]")
          end

          step_container = settings["step"] ||= {}
          return if @dry_run && process_step_keys.empty?

          process_step_keys.each do |step_key|
            next unless step_container.is_a?(Hash)
            step_container.each do |step_id, step_settings|
              next unless step_settings.is_a?(Hash)

              clean_translated_setting_hash.call(
                step_settings,
                step_key,
                    "settings[step][#{step_id}][#{step_key}]"
              )
            end
          end

          return if @dry_run
          return unless touched

          # rubocop:disable Rails/SkipsModelValidations
          record.update_column(:settings, settings)
          # rubocop:enable Rails/SkipsModelValidations
        end
      end
    end
  end
end
