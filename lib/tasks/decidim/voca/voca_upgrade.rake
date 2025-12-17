# frozen_string_literal: true

# Hook into the main Decidim tasks so this module is installed alongside the
# core assets and migrations.
if Rake::Task.task_defined?("decidim:shakapacker:install")
  Rake::Task["decidim:shakapacker:install"].enhance do
    Rake::Task["decidim_voca:webpacker:install"].invoke if Rake::Task.task_defined?("decidim_voca:webpacker:install")
  end
end

Rake::Task["decidim:choose_target_plugins"].enhance do
  ENV["FROM"] = "#{ENV.fetch("FROM", nil)},decidim_voca" unless ENV["FROM"].to_s.include?("decidim_voca")
end
Rake::Task["decidim:upgrade"].enhance do
  Rake::Task["decidim_voca:install:migrations"].invoke if Rake::Task.task_defined?("decidim_voca:install:migrations")
  Rake::Task["decidim:voca:webpacker:upgrade"].invoke if Rake::Task.task_defined?("decidim:voca:webpacker:upgrade")
  Rake::Task["decidim:voca:sync_routes"].invoke if Rake::Task.task_defined?("decidim:voca:sync_routes")
end
