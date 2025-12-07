# frozen_string_literal: true

require "faker"
require "decidim/core"
namespace :decidim do
  namespace :voca do
    desc <<~DESC
      Remove all translation strings that are not in default locale and#{" "}
      not in machine translation.
      Will loop over every ActiveRecord availables
    DESC
    task clean_machine_translations: :environment do
      Rails.application.eager_load!

      # For each active record class that includes Decidim::TranslatableResource
      # check their @translatable_fields (class instance variable)
      # And then loop for each language on records that define locales that are not the default locale

      Decidim::Organization.all.each do |current_organization|
        next unless current_organization.enable_machine_translations?

        warn_records = []
        locale = current_organization.default_locale
        other_locales = Decidim.available_locales - [locale]
        decidim_models = ActiveRecord::Base.descendants.map do |cls|
          next nil if cls.name.nil? # abstract classes registered during tests
          next nil if cls.abstract_class? || !cls.name.match?(/^Decidim::/)

          cls
        end.compact_blank
        translatable_models = decidim_models.filter { |cls| cls.include?(Decidim::TranslatableResource) }

        translatable_models.each do |cls|
          begin
            next unless cls.table_exists?
          rescue ActiveRecord::StatementInvalid => e
            warn "Skipping #{cls.name}: #{e.message}"
            next
          end

          # Locales are saved in a jsonb field
          translatable_fields = cls.instance_variable_get(:@translatable_fields)
          next if translatable_fields.empty?

          translatable_fields.each do |field|
            # Find records that have incomplete translations, and trigger translation job
            current_organization.available_locales.each do |available_locale|
              next if available_locale == locale

              field_quoted = cls.connection.quote_column_name(field)
              locale_quoted = cls.connection.quote(available_locale)
              condition = "(#{field_quoted}->>#{locale_quoted} IS NULL OR #{field_quoted}->>#{locale_quoted} = '')"
              cls.where.not(field => nil).where(condition).count
              cls.where.not(field => nil).where(condition).each do |record|
                organization = record.try(:organization)
                # If can not get the organization, we can not be sure we are deleting the right thing
                next if organization.nil? || organization.id != current_organization.id

                puts "Triggering translation job for #{cls.name}.#{field} in #{available_locale}"
                field_value = record.send(field)
                source_text = field_value[locale.to_s] if field_value.is_a?(Hash)
                if source_text.blank?
                  # set machine translation to empty string
                  record.send("#{field}=", "")
                  record.save!
                  next
                end

                translator =  Decidim.config.machine_translation_service.constantize.new(
                  record,
                  field,
                  source_text,
                  available_locale,
                  locale
                )
                translator.translate
              end
            end
            # Find records that define the locale
            other_locales.each do |other_locale|
              cls.where.not(field => nil).where.not("#{cls.connection.quote_column_name(field)}->>? IS NULL", other_locale).each do |record|
                organization = record.try(:organization)
                # If can not get the organization, we can not be sure we are deleting the right thing
                if organization.nil? || organization.id != current_organization.id
                  warn_records << record
                  next
                end
                current_value = record.send(field)
                # remove all the locale fields that are not default or machine translated
                current_value.delete_if do |key, _value|
                  other_locales.include?(key)
                end
                record.send("#{field}=", current_value)
                record.save!
              end
            rescue ActiveRecord::StatementInvalid => e
              warn "Error processing #{cls.name}.#{field} for locale #{other_locale}: #{e.message}"
              next
            end
          end
        end
      end
    end
  end
end
