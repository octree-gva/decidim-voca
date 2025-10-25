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

      config_accessor :rack_attack do
        {
          enabled: ::Decidim::Env.new("RACK_ATTACK_ENABLED", "true").present?,
          ban_minutes: ::Decidim::Env.new("RACK_ATTACK_BAN_MINUTES", "10").to_i,
          block_system: ::Decidim::Env.new("RACK_ATTACK_BLOCK_SYSTEM", "true").present?,
          fail2ban_paths: ::Decidim::Env.new(
            "RACK_ATTACK_FAIL2BAN_PATHS",
            "/etc/passwd,/wp-admin,/wp-login,/wp-content,/wp-includes,.ht,.git,.log,.lock,.env,.php,.conf,/mifs,LogService"
          ).to_s.split(",").map(&:strip).compact_blank,
          get_conversations_per_minute: ::Decidim::Env.new("RACK_ATTACK_GET_CONVERSATIONS_PER_MINUTE", "100").to_i,
          post_conversations_per_minute: ::Decidim::Env.new("RACK_ATTACK_POST_CONVERSATIONS_PER_MINUTE", "20").to_i,
          post_signup_per_minute: ::Decidim::Env.new("RACK_ATTACK_POST_SIGNUP_PER_MINUTE", "10").to_i,
          post_signin_per_minute: ::Decidim::Env.new("RACK_ATTACK_POST_SIGNIN_PER_MINUTE", "30").to_i,
          post_password_reset_per_minute: ::Decidim::Env.new("RACK_ATTACK_POST_PASSWORD_RESET_PER_MINUTE", "5").to_i,
          post_comments_per_minute: ::Decidim::Env.new("RACK_ATTACK_POST_COMMENTS_PER_MINUTE", "10").to_i,
          api_per_minute: ::Decidim::Env.new("RACK_ATTACK_API_PER_MINUTE", "300").to_i,
        }
      end
    end
  end
end