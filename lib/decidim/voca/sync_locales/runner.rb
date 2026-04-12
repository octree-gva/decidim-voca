# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Eager-loads models, discovers TranslatableResource classes, normalizes each field.
      class Runner
        def call
          Rails.application.eager_load!
          translatable_models.each do |model|
            process_model(model)
          end
        end

        private

        def fields_for(model)
          @fields ||= {}
          @fields[model] ||= Array(model.translatable_fields_list).compact.map(&:to_s)
        end

        def translatable_models
          ActiveRecord::Base.descendants.select do |cls|
            next false if cls.name.blank?
            next false unless cls.include?(Decidim::TranslatableResource)

            fields_for(cls).present?
          end
        end

        def process_model(model)
          fields = fields_for(model)
          return if fields.empty?

          Rails.logger.debug { "Processing model: #{model.name}" }
          model.unscoped.find_each do |record|
            process_record(record, fields)
          end
          Rails.logger.debug { "[DONE][#{model.unscoped.count} records]" }
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
    end
  end
end
