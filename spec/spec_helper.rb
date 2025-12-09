# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
ENV["NODE_ENV"] ||= "test"
ENV["ENGINE_ROOT"] = File.dirname(__dir__)
ENV["MASTER_ID"] = "1234567890"
ENV["MASTER_IP"] = "127.0.0.1"
ENV["DECIDIM_AVAILABLE_LOCALES"] = "en,fr,es,ca"
ENV["DECIDIM_DEFAULT_LOCALE"] = "en"

require "i18n"
available_locales = ENV["DECIDIM_AVAILABLE_LOCALES"].split(",").map { |locale| locale.strip.to_sym }
I18n.available_locales = available_locales
I18n.default_locale = ENV["DECIDIM_DEFAULT_LOCALE"].to_sym

require "decidim/dev"

Decidim::Dev.dummy_app_path = File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require "decidim/dev/test/base_spec_helper"
require "decidim/core/test/factories"
require "decidim/proposals/test/factories"

RSpec.configure do |config|
  config.before do
    redis_url = ENV["TRAEFIK_REDIS_URL"] = "redis://localhost:6379/1"
    redis = instance_double(Redis, set: nil, ping: "PONG")
    allow(Redis).to receive(:new).with(url: redis_url).and_return(redis)
  end
end
