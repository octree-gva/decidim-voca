# frozen_string_literal: true

require "decidim/dev/common_rake"

# Stable name regardless of mount path (/home/module in Docker vs repo dir on host).
def base_app_name
  "decidim_voca"
end

def wait_for_postgres!(timeout: 60)
  return unless ENV["CI"] == "1" || ENV.fetch("DISABLED_DOCKER_COMPOSE", "false") == "true"

  host = ENV.fetch("DATABASE_HOST", "postgres")
  port = ENV.fetch("DATABASE_PORT", "5432").to_i
  require "socket"
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
  loop do
    TCPSocket.new(host, port).close
    return
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    raise "PostgreSQL not reachable at #{host}:#{port} after #{timeout}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

    sleep 1
  end
end

def ensure_postgres_database!(db_name)
  require "pg"
  host = ENV.fetch("DATABASE_HOST", "postgres")
  port = ENV.fetch("DATABASE_PORT", "5432").to_i
  user = ENV.fetch("DATABASE_USERNAME", "decidim")
  password = ENV.fetch("DATABASE_PASSWORD", "pleaseChangeMe")

  conn = PG.connect(host:, port:, user:, password:, dbname: "postgres")
  exists = conn.exec_params("SELECT 1 FROM pg_database WHERE datname = $1", [db_name]).ntuples.positive?
  conn.exec("CREATE DATABASE #{PG::Connection.quote_ident(db_name)}") unless exists
ensure
  conn&.close
end

# Decidim's InstallGenerator boots Rails before recreate_db; default database name is <app_name>_development.
def ensure_generator_databases!
  wait_for_postgres!
  ensure_postgres_database!("#{base_app_name}_test_app_development")
end

def install_module(path)
  Dir.chdir(path) do
    sh "bundle exec rails decidim_voca:install:migrations"
    # Check for deepl, activerecord-postgis-adapter, good_job, next_gen_images, deface
    # If are not in Gemfile, add them
    sh "bundle add deepl-rb" unless Gem.loaded_specs.has_key?("deepl-rb")
    sh "bundle add activerecord-postgis-adapter" unless Gem.loaded_specs.has_key?("activerecord-postgis-adapter")
    sh "bundle add good_job" unless Gem.loaded_specs.has_key?("good_job")
    sh "bundle add next_gen_images" unless Gem.loaded_specs.has_key?("next_gen_images")
    sh "bundle add deface" unless Gem.loaded_specs.has_key?("deface")
    sh "bundle add decidim-decidim_awesome #{Decidim::Voca.compat_decidim_awesome_version}" unless Gem.loaded_specs.has_key?("decidim-decidim_awesome")
    unless Gem.loaded_specs.has_key?("decidim-telemetry")
      sh "bundle add decidim-telemetry --git https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry --ref #{Decidim::Voca.compat_decidim_telemetry_version}"
    end
    sh "bundle exec rails decidim:update"
    sh "bundle exec rails decidim:voca:webpacker:install"
    sh "bundle exec rails db:migrate"
  end
end

def seed_db(path)
  Dir.chdir(path) do
    system("bundle exec rails db:seed")
  end
end

desc "Prepare for testing"
task :prepare_tests do
  wait_for_postgres!
  disable_docker_compose = ENV.fetch("DISABLED_DOCKER_COMPOSE", "true") == "true"
  unless disable_docker_compose
    system("docker-compose -f docker-compose.yml down -v --remove-orphans")
    system("docker-compose -f docker-compose.yml up -d ")
  end
  ENV["RAILS_ENV"] = "development"
  common_db_config = {
    "adapter" => "postgis",
    "encoding" => "unicode",
    "host" => ENV.fetch("DATABASE_HOST", "voca-pg"),
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

  dummy_app = File.expand_path("spec/decidim_dummy_app", __dir__)
  Dir.chdir(dummy_app) do
    # Fresh CI has no DB yet; do not abort test_app when drop fails.
    sh "bundle exec rails db:drop || true"
    sh "bundle exec rails db:create db:migrate"
  end
end

desc "Generates a dummy app for testing"
task :test_app do
  ensure_generator_databases!

  Bundler.with_original_env do
    generate_decidim_app(
      "spec/decidim_dummy_app",
      "--app_name",
      "#{base_app_name}_test_app",
      "--path",
      "../..",
      "--skip_spring",
      "--skip_webpack_install",
      "--recreate_db",
      "--force_ssl",
      "false",
      "--locales",
      "en,fr,es"
    )
  end
  # DB must exist before install_module runs `rails decidim:update` (CI: postgres service).
  Rake::Task["prepare_tests"].reenable
  Rake::Task["prepare_tests"].invoke
  install_module("spec/decidim_dummy_app")
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
