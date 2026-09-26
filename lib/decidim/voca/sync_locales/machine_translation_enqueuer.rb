# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Enqueue DeepL MachineTranslator for pending locales; skip locales that already have MT.
      class MachineTranslationEnqueuer
        attr_accessor :record, :field_name, :context, :normalized_field_hash

        def initialize(record, field_name, context, normalized_field_hash)
          @record = record
          @field_name = field_name.to_s
          @context = context
          @normalized_field_hash = normalized_field_hash
        end

        def call
          return EnqueueStats.empty unless Decidim.machine_translation_service_klass == Decidim::Voca::DeepL::MachineTranslator
          return EnqueueStats.empty unless context.enable_machine_translations?

          default = context.default_locale
          field_hash = normalized_field_hash.stringify_keys
          source_text = field_hash[default]
          return EnqueueStats.empty if source_text.blank?

          stats = EnqueueStats.empty
          gap_locales.each do |target_locale|
            if already_machine_translated?(target_locale)
              stats.add!(EnqueueStats.new(skipped_existing: 1))
            else
              translate_field(source_text, target_locale, default)
              stats.add!(EnqueueStats.new(enqueued: 1))
            end
          end
          stats
        end

        def translate_field(source_text, target_locale, source_locale)
          Decidim::Voca::DeepL::Context.with_organization(context.organization) do
            Decidim::Voca::DeepL::MachineTranslator.new(
              record,
              field_name,
              source_text,
              target_locale,
              source_locale
            ).translate
          end
        end

        private

        # Current human-filled locales, excluding machine translations.
        def translated_locales
          field_hash = normalized_field_hash.stringify_keys
          field_hash.except("machine_translations").each_with_object([]) do |(locale, value), list|
            list << locale if value.present?
          end
        end

        # Locales without a human value (candidates for MT, including already-MT'd).
        def gap_locales
          context.allowed_locales - translated_locales
        end

        # Locales that still need a DeepL call.
        def pending_locales
          gap_locales.reject { |locale| already_machine_translated?(locale) }
        end

        def already_machine_translated?(locale)
          ComponentSettingPendingLocales.machine_translated?(
            normalized_field_hash,
            locale,
            context.default_locale
          )
        end
      end
    end
  end
end
