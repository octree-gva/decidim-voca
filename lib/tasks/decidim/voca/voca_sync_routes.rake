# frozen_string_literal: true

namespace :decidim do
  namespace :voca do
    desc "Sync routes to Redis"
    task sync_routes: :environment do
      organizations = Decidim::Organization.all
      organizations.each do |organization|
        Decidim::Voca::SyncRedisRouting.new(organization).call
      end
      prev_format = ENV.fetch("FORMAT", nil)
      ENV["FORMAT"] = "traefik"
      Rake::Task["decidim:voca:routes"].invoke
      ENV["FORMAT"] = prev_format
    end
  end
end
