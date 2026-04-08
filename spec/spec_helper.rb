# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
ENV["NODE_ENV"] ||= "test"
ENV["ENGINE_ROOT"] = File.dirname(__dir__)
ENV["MASTER_ID"] = "1234567890"
ENV["MASTER_IP"] = "127.0.0.1"
ENV["DECIDIM_AVAILABLE_LOCALES"] = "en,fr,es,ca"
ENV["DECIDIM_DEFAULT_LOCALE"] = "en"

require "i18n"
# Docker Compose may export a narrower DECIDIM_AVAILABLE_LOCALES; Decidim factories still use ca/es/etc.
requested = ENV["DECIDIM_AVAILABLE_LOCALES"].to_s.split(",").filter_map do |l|
  s = l.strip
  next if s.empty?

  s.to_sym
end
merged = (requested + [:en, :fr, :es, :ca, :uk]).uniq
I18n.available_locales = merged
ENV["DECIDIM_AVAILABLE_LOCALES"] = merged.join(",")
I18n.default_locale = ENV["DECIDIM_DEFAULT_LOCALE"].to_sym

require "decidim/dev"

Decidim::Dev.dummy_app_path = File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require "decidim/dev/test/base_spec_helper"
require "decidim/core/test/factories"
require "decidim/proposals/test/factories"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Dummy app hardcodes Decidim.available_locales in its initializer; merge test locales after boot.
  config.before(:suite) do
    merged = (ENV["DECIDIM_AVAILABLE_LOCALES"].to_s.split(",") + %w(en fr es ca uk))
             .map(&:strip).uniq.reject(&:empty?)
    I18n.available_locales = merged.map(&:to_sym)
    ENV["DECIDIM_AVAILABLE_LOCALES"] = merged.join(",")
    Decidim.configure { |c| c.available_locales = merged }
    Rails.application.config.i18n.available_locales = I18n.available_locales if defined?(Rails.application) && Rails.application
  end

  config.before do
    redis_url = ENV["TRAEFIK_REDIS_URL"] = "redis://localhost:6379/1"
    redis = instance_double(Redis, set: nil, ping: "PONG")
    allow(Redis).to receive(:new).with(url: redis_url).and_return(redis)
  end
end
