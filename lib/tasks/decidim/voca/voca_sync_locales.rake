# frozen_string_literal: true

namespace :decidim do
  namespace :voca do
    desc <<~DESC.chomp
      Normalize translatable JSON fields and enqueue machine translation for missing locales
      (skips locales that already have machine_translations). Rebuilds search before and after.
      Optional MODEL: rails decidim:voca:sync_locales[Decidim::Attachment]
    DESC
    task :sync_locales, [:model_name] => :environment do |_t, args|
      Decidim::Voca::SyncLocales.call(model_name: args[:model_name].presence)
    end

    desc "List ActiveRecord models that sync_locales can process (TranslatableResource with fields)."
    task list_translatable_models: :environment do
      Decidim::Voca::SyncLocales.translatable_model_names.each do |name|
        puts name
      end
    end
  end
end
