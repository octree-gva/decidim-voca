# frozen_string_literal: true

require "decidim/voca/sync_locales"

namespace :decidim do
  namespace :voca do
    desc "Lint Decidim records: verify LocaleContext can resolve organization (logs failures to tmp/YYYYMMDD_relation_lint.log)"
    task relation_lint: :environment do
      Decidim::Voca::SyncLocales::RelationLintRunner.new.call
    end
  end
end
