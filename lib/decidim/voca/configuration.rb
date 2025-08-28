module Decidim
  module Voca
    class Configuration
      include ActiveSupport::Configurable

      config_accessor :enable_weglot do
        ENV.fetch("WEGLOT_API_KEY", "").present?
      end

      config_accessor :enable_next_gen_images do
        true
      end

      config_accessor :weglot_api_key do
        ENV.fetch("WEGLOT_API_KEY", "")
      end
  
      

    end
  end
end