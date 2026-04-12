# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Rule 1: enqueue MachineTranslationFieldsJob for pending locales (same delay as TranslatableResource).
      class MachineTranslationEnqueuer
        def initialize(record, field_name, context, normalized_field_hash)
          @record = record
          @field_name = field_name.to_s
          @context = context
          @normalized_field_hash = normalized_field_hash
        end

        def call
          return unless Decidim.machine_translation_service_klass
          return unless @context.enable_machine_translations?

          default = @context.default_locale
          field_hash = @normalized_field_hash.stringify_keys
          source_text = field_hash[default]
          return if source_text.blank?

          pending_locales.each do |target_locale|
            Decidim::MachineTranslationFieldsJob
              .set(wait: Decidim.config.machine_translation_delay)
              .perform_later(
                @record,
                @field_name,
                source_text,
                target_locale,
                default
              )
          end
        end

        private

        # Current human-filled locales, excluding machine translations.
        def translated_locales
          field_hash = @normalized_field_hash.stringify_keys
          field_hash.except("machine_translations").each_with_object([]) do |(locale, value), list|
            list << locale if value.present?
          end
        end

        # Locales that are not human-filled, and therefore need to be machine translated.
        def pending_locales
          @context.allowed_locales - translated_locales
        end
      end
    end
  end
end
