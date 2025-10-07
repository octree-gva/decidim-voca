# frozen_string_literal: true

namespace :decidim_voca do
  namespace :install do
    def decidim_voca_install_good_job
      puts "Decidim Voca: Installing good_job..."
      Rails::Generators.invoke("good_job:install")
    end
    desc "Copy migrations from decidim_voca and dependancies to application "
    task migrations: :environment do
      # Run the original install:migrations task
      Rake::Task["decidim_voca:install:migrations"].invoke

      puts "Decidim Voca: Running additional Voca setup commands..."

      # Add your custom commands here
      begin
        decidim_voca_install_good_job

        puts "Decidim Voca: migration files copied successfully"
      rescue StandardError => e
        puts "Decidim Voca: migration files copy failed: #{e.message}"
      end
    end
  end
end

# Alternative: Enhance the existing task if it exists
if Rake::Task.task_defined?("decidim_voca:install:migrations")
  Rake::Task["decidim_voca:install:migrations"].enhance do
    puts "Running Voca post-installation hooks..."

    begin
      # Add any commands that should run after migration installation
      # Example: Clear caches, restart services, etc.
      Rails.cache.clear if defined?(Rails.cache)

      puts "Voca post-installation hooks completed"
    rescue StandardError => e
      puts "Warning: Voca post-installation hooks failed: #{e.message}"
    end
  end
end
