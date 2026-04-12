# frozen_string_literal: true

namespace :decidim do
  namespace :voca do
    desc "Normalize translatable JSON fields (machine_translations + locale roots) and enqueue machine translation jobs; rebuilds search index before and after."
    task sync_locales: :environment do
      Decidim::Voca::SyncLocales.call
    end
  end
end
