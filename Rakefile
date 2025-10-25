# frozen_string_literal: true

require "decidim/dev/common_rake"

def install_module(path)
  Dir.chdir(path) do
    system("bundle exec rails decidim_voca:install:migrations")
    # Check for deepl, activerecord-postgis-adapter, good_job, next_gen_images, deface
    # If are not in Gemfile, add them
    system("bundle add deepl-rb") unless Gem.loaded_specs.has_key?("deepl-rb")
    system("bundle add activerecord-postgis-adapter") unless Gem.loaded_specs.has_key?("activerecord-postgis-adapter")
    system("bundle add good_job") unless Gem.loaded_specs.has_key?("good_job")
    system("bundle add next_gen_images") unless Gem.loaded_specs.has_key?("next_gen_images")
    system("bundle add deface") unless Gem.loaded_specs.has_key?("deface")
    system("bundle add decidim-decidim_awesome #{Decidim::Voca.compat_decidim_awesome_version}") unless Gem.loaded_specs.has_key?("decidim-decidim_awesome")
    system( "bundle add decidim-telemetry --git https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry --ref #{Decidim::Voca.compat_decidim_telemetry_version}") unless Gem.loaded_specs.has_key?("decidim-telemetry")
    system("bundle exec rails decidim:update")
  end
end

def seed_db(path)
  Dir.chdir(path) do
    system("bundle exec rails db:seed")
  end
end

desc "Prepare for testing"
task :prepare_tests do
  # Remove previous existing db, and recreate one.
  disable_docker_compose = ENV.fetch("DISABLED_DOCKER_COMPOSE", "false") == "true"
  unless disable_docker_compose
    system("docker-compose -f docker-compose.yml down -v --remove-orphans")
    system("docker-compose -f docker-compose.yml up -d ")
  end
  ENV["RAILS_ENV"] = "development"
  common_db_config = {
    "adapter" => "postgis",
    "encoding" => "unicode",
    "host" => ENV.fetch("DATABASE_HOST", "spam-signal-pg"),
    "port" => ENV.fetch("DATABASE_PORT", "5432").to_i,
    "username" => ENV.fetch("DATABASE_USERNAME", "decidim"),
    "password" => ENV.fetch("DATABASE_PASSWORD", "pleaseChangeMe"),
    "database" => "#{base_app_name}_test_app"
  }

  database_yml = {
    "test" => common_db_config,
    "development" => common_db_config
  }

  config_file = File.expand_path("spec/decidim_dummy_app/config/database.yml", __dir__)
  File.open(config_file, "w") { |f| YAML.dump(database_yml, f) }

  Dir.chdir("spec/decidim_dummy_app") do
    system("bundle exec rails db:drop")
    system("bundle exec rails db:create")
    system("bundle exec rails db:migrate")
  end
end

desc "Generates a dummy app for testing"
task :test_app do
  Bundler.with_original_env do
    generate_decidim_app(
      "spec/decidim_dummy_app",
      "--app_name",
      "#{base_app_name}_test_app",
      "--path",
      "../..",
      "--skip_spring",
      "--demo",
      "--force_ssl",
      "false",
      "--locales",
      "en,fr,es"
    )
  end
  install_module("spec/decidim_dummy_app")
  Rake::Task["prepare_tests"].invoke
end

desc "Generates a development app"
task :development_app do
  Bundler.with_original_env do
    generate_decidim_app(
      "development_app",
      "--app_name",
      "#{base_app_name}_development_app",
      "--path",
      "..",
      "--recreate_db",
      "--demo"
    )
  end
end
