# frozen_string_literal: true

deepl_api_key = ENV.fetch("DECIDIM_DEEPL_API_KEY", "")
if deepl_api_key.present?
  require "deepl"
  DeepL.configure do |config|
    config.auth_key = deepl_api_key
    config.host = ENV.fetch("DECIDIM_DEEPL_HOST", "https://api.deepl.com")
    config.version = ENV.fetch("DECIDIM_DEEPL_VERSION", "v2")
  end
end
