# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Fills blank TermCustomizer locale rows from the customized default-locale value.
      # Uses plain +Translation#value+ columns (no machine_translations JSON).
      class TermCustomizerSync
        MODEL_NAME = "Decidim::TermCustomizer::Translation"

        def self.available?
          return false unless defined?(::Decidim::TermCustomizer::Translation)
          return false unless defined?(::Decidim::TermCustomizer::TranslationSet)

          ::Decidim::TermCustomizer::Translation.table_exists? &&
            ::Decidim::TermCustomizer::TranslationSet.table_exists?
        rescue StandardError
          false
        end

        # Yields EnqueueStats per translation key (for Runner tally).
        def each_key_stats
          return enum_for(:each_key_stats) unless block_given?
          return unless self.class.available?
          return unless Decidim.machine_translation_service_klass

          each_set_with_organization do |set, organization|
            next unless organization.enable_machine_translations?

            rows_by_key = set.translations.group_by { |row| row.key.to_s }
            rows_by_key.each do |key, rows|
              yield sync_key!(set, key, rows, organization)
            end
          end
        end

        # Aggregate run for the dedicated rake (prints done/skipped itself when +print_summary:+).
        def call(print_summary: false)
          done = 0
          skipped = 0
          each_key_stats do |stats|
            if stats.enqueued.positive?
              done += 1
            else
              skipped += 1
            end
          end
          $stdout.puts "done: #{done}, skipped: #{skipped}" if print_summary
          { done:, skipped: }
        end

        private

        def each_set_with_organization
          ::Decidim::TermCustomizer::TranslationSet
            .joins(:constraints)
            .includes(:translations, :constraints)
            .distinct
            .find_each do |set|
              organization = set.constraints.filter_map(&:organization).first
              next unless organization

              yield set, organization
            end
        end

        def sync_key!(set, key, rows, organization)
          stats = EnqueueStats.empty
          default = organization.default_locale.to_s
          allowed = organization.available_locales.map(&:to_s)
          by_locale = rows.index_by { |row| row.locale.to_s }
          source_text = by_locale[default]&.value
          return stats if source_text.blank?

          (allowed - [default]).each do |target_locale|
            existing = by_locale[target_locale]
            if existing&.value.present?
              stats.add!(EnqueueStats.new(skipped_existing: 1))
              next
            end

            translated = Decidim::Voca::DeepL::Context.with_organization(organization) do
              MachineTranslation::TranslateString.call(
                text: source_text,
                source_locale: default,
                target_locale:,
                html: false,
                context: "Decidim::TermCustomizer::Translation set=#{set.id} key=#{key}"
              )
            end
            next if translated.nil?

            if existing
              existing.update!(value: translated)
            else
              set.translations.create!(key:, locale: target_locale, value: translated)
            end
            stats.add!(EnqueueStats.new(enqueued: 1))
          end
          stats
        end
      end
    end
  end
end
