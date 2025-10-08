# frozen_string_literal: true

module Decidim
  module Voca
    class Configuration
      include ActiveSupport::Configurable

      config_accessor :enable_minimalistic_deepl do
        true
      end

      config_accessor :enable_weglot do
        ::Decidim::Env.new("WEGLOT_API_KEY", "").present?
      end

      config_accessor :enable_next_gen_images do
        true
      end

      config_accessor :weglot_api_key do
        ::Decidim::Env.new("WEGLOT_API_KEY", "")
      end

      config_accessor :enable_weglot_cache do
        false
      end
    end
  end
end
