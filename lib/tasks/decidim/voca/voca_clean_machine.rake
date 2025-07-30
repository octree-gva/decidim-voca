# frozen_string_literal: true

require "faker"
require "decidim/core"
namespace :decidim do
  namespace :voca do
    desc <<~DESC
      Remove all translation strings that are not in default locale and 
      not in machine translation.
      Will loop over every ActiveRecord availables
    DESC
    task clean_machine_translations: :environment do
      Rails.application.eager_load!

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
        end.select(&:present?)
        translatable_models = decidim_models.filter {|cls| cls.include?(Decidim::TranslatableResource)}

        translatable_models.each do |cls|
          # Locales are saved in a jsonb field 
          translatable_fields = cls.instance_variable_get(:@translatable_fields)
          next if translatable_fields.empty?

          translatable_fields.each do |field|
            # Find records that define the locale
            other_locales.each do |other_locale|
              cls.where.not(field => nil).where.not(field => {other_locale => nil}).each do |record|
                organization = record.try(:organization)
                # If can not get the organization, we can not be sure we are deleting the right thing
                if organization.nil? || organization.id != current_organization.id
                  warn_records << record
                  next
                end
                current_value = record.send(field)
                # remove all the locale fields that are not default or machine translated
                current_value.delete_if do |key, value|
                  other_locales.include?(key)
                end
                record.send("#{field}=", current_value)
                record.save!
              end
            end
          end
        end
      end
    end
  end
end