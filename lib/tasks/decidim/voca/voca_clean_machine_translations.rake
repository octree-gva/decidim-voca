# frozen_string_literal: true

require "csv"
require "faker"
require "decidim/core"
namespace :decidim do
  namespace :voca do
    desc <<~DESC
      Remove all translation strings that are not in default locale and
      not in machine translation. Will loop over every ActiveRecord availables.#{" "}
      This task do NOT call MachineTranslationFieldsJob ever.

      Set DRY_RUN=1 to perform no writes and print a semicolon-separated CSV to stdout:
      model;field;value (field JSON before alteration). Redirect, e.g. DRY_RUN=1 bin/rake ... > tmp/out.csv
    DESC
    task clean_machine_translations: :environment do
      Rails.application.eager_load!

      dry_run = ENV["DRY_RUN"].to_s == "1"
      $stdout.puts CSV.generate_line(%w(model field value), col_sep: ";") if dry_run

      # For each active record class that includes Decidim::TranslatableResource
      # check their @translatable_fields (class instance variable)
      # And then loop for each language on records that define locales that are not the default locale

      Decidim::Organization.all.each do |current_organization|
        # SKIP if not machine translation
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
          # Locales are saved in a jsonb field
          translatable_fields = cls.instance_variable_get(:@translatable_fields)
          next if translatable_fields.empty?

          translatable_fields.each do |field|
            # Find records that define the locale
            other_locales.each do |other_locale|
              cls.where.not(field => nil).where.not(field => { other_locale => nil }).each do |record|
                organization = record.try(:organization)
                # If can not get the organization, we can not be sure we are deleting the right thing
                if organization.nil? || organization.id != current_organization.id
                  warn_records << record
                  next
                end
                current_value = record.send(field)
                if dry_run
                  value_json = current_value.respond_to?(:as_json) ? current_value.as_json.to_json : current_value.to_json
                  $stdout.puts CSV.generate_line([cls.name, field.to_s, value_json], col_sep: ";")
                  next
                end
                # remove all the locale fields that are not default or machine translated
                current_value.delete_if do |key, _value|
                  other_locales.include?(key)
                end
                record.send("#{field}=", current_value)
                record.save!
              end
            end
          end
        end

        Decidim::Component.find_each do |record|
          organization = record.try(:organization)
          if organization.nil? || organization.id != current_organization.id
            warn_records << record
            next
          end

          keys = Decidim::Voca::ComponentSettingManifest.translated_global_keys(record.manifest)
          next if keys.empty?

          settings = record.read_attribute(:settings).deep_dup.deep_stringify_keys
          global = settings["global"] ||= {}
          touched = false

          keys.each do |key|
            current_value = global[key]
            next unless current_value.is_a?(Hash)

            key_touched = false
            other_locales.each do |other_locale|
              next unless current_value.has_key?(other_locale)

              if dry_run
                value_json = current_value.respond_to?(:as_json) ? current_value.as_json.to_json : current_value.to_json
                $stdout.puts CSV.generate_line(
                  [Decidim::Component.name, "settings[#{key}]", value_json],
                  col_sep: ";"
                )
                next
              end

              current_value.delete(other_locale)
              key_touched = true
            end
            touched ||= key_touched
            global[key] = current_value
          end

          next if dry_run || !touched

          # rubocop:disable Rails/SkipsModelValidations
          record.update_column(:settings, settings)
          # rubocop:enable Rails/SkipsModelValidations
        end
      end
    end
  end
end
