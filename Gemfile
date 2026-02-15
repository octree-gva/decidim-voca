# frozen_string_literal: true

source "https://rubygems.org"

base_path = "./"
base_path = "../../" if File.basename(__dir__) == "decidim_dummy_app"
base_path = "../" if File.basename(__dir__) == "development_app"

require_relative "#{base_path}lib/decidim/voca/version"

DECIDIM_VERSION = "~> 0.29.6"

gem "activerecord-postgis-adapter"
gem "bootsnap", "~> 1.4"
gem "decidim", DECIDIM_VERSION
gem "decidim-decidim_awesome", "~> 0.12.3"
gem "decidim-voca", path: base_path
gem "deepl-rb"
gem "deface", ">= 1.8.1"
gem "good_job", "~> 4.5.1"
gem "next_gen_images", git: "https://github.com/froger/next_gen_images", branch: "chore/rails-7.0"
gem "puma", ">= 6.3.1"
gem "uglifier", "~> 4.1"

group :development, :test do
  gem "brakeman", "~> 6.1"
  gem "byebug", "~> 11.0", platform: :mri
  gem "decidim-dev", DECIDIM_VERSION
  gem "parallel_tests", "~> 4.2"
end

group :test do
  gem "capybara", "~> 3.24"
  gem "rspec-rails", "~> 6.0"
  gem "rubocop-faker"
end

group :development do
  gem "letter_opener_web", "~> 2.0"
  gem "listen", "~> 3.1"
  gem "web-console", "~> 4.2"
end

gem "concurrent-ruby", "= 1.3.4"
gem "decidim-telemetry",
    git: "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry",
    tag: "v0.0.3"

gem "decidim-ephemeral_participation",
    git: "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-ephemeral_participation",
    tag: "v0.0.6"

gem "decidim-user_fields",
    git: "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-user_fields",
    tag: "v0.1.4"

gem "opentelemetry-exporter-otlp"
gem "opentelemetry-exporter-otlp-logs"
gem "opentelemetry-instrumentation-all"
gem "opentelemetry-logs-sdk"
gem "opentelemetry-sdk"
