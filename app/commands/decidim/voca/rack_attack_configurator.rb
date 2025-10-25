# frozen_string_literal: true

module Decidim
  module Voca
    ##
    # Configures Rack::Attack for Decidim Voca
    # If you want to test it in development, create a file tmp/caching-dev.txt
    class RackAttackConfigurator < Decidim::Command
      def call
        return unless defined?(Rack::Attack)

        Rack::Attack.clear_configuration
        enable_rack_attack!
        return broadcast(:ok) unless rack_attack_enabled?

        check_preconditions!
        setup_safelist!
        protect_system!
        protect_fail2ban!
        protect_conversations!
        protect_signup!
        protect_signin!
        protect_password_reset!
        protect_api!
        protect_comments!
        configure_throttles!
        configure_allow2ban!
        broadcast(:ok)
      rescue StandardError => e
        broadcast(:invalid, e.message)
      end

      private

      def check_preconditions!
        preconditions_met = [
          Rails.application.config.action_controller.perform_caching == true,
          Rails.application.config.cache_store.present?,
          Rails.application.config.cache_store != :null_store,
        ].all?
        return if preconditions_met
        raise "Rack::Attack preconditions not met. Rack::Attack will not work."
      end

      def ban_minutes
        @ban_minutes ||= config[:ban_minutes].present? && config[:ban_minutes].to_i.positive? ? config[:ban_minutes].to_i : 0
      end

      def configure_throttles!
        return if ban_minutes.zero?
        Rack::Attack.throttled_response_retry_after_header = true
        Rack::Attack.throttled_response = lambda do |env|
          match_data = env["rack.attack.match_data"]
          now = match_data[:epoch_time]

          headers = {
            "RateLimit-Limit" => match_data[:limit].to_s,
            "RateLimit-Remaining" => "0",
            "RateLimit-Reset" => (now + ban_minutes.minutes.to_i).to_s
          }

          [429, headers, ["Try again later\n"]]
        end
      end

      def configure_allow2ban!
        return if ban_minutes.zero?
        Rack::Attack.blocklisted_responder = lambda do |rack_request|
          request = ActionDispatch::Request.new(rack_request.env)
          controller = ApplicationController.new
          controller.request = request
          controller.response = ActionDispatch::Response.new
          rendered_content =  I18n.with_locale(I18n.default_locale) do
            controller.render_to_string(
              partial: 'decidim/voca/rack_attack/blocked',
              layout: false
            )
          end
          [ 403, {}, [rendered_content]]
        end
      end

      def config
        @config ||= Decidim::Voca.configuration.rack_attack
      end

      ##
      # Throttle API requests
      # max 300 requests per minute per IP
      def protect_api!
        return unless config[:api_per_minute].positive?

        Rack::Attack.throttle("api", limit: config[:api_per_minute], period: 1.minute) do |request|
          request.ip if request.post? && request.path.start_with?("/api")
        end
      end

      ##
      # Ban on too many signup requests
      # max 10 requests per minute per IP
      def protect_signup!
        return unless config[:post_signup_per_minute].positive?

        Rack::Attack.blocklist("post signup allow2ban") do |request|
          Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:post_signup_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
            request.ip if request.post? && request.path.start_with?("/users")
          end
        end
      end

      ##
      # Ban on too many signin requests
      # max 30 requests per minute per IP
      def protect_signin!
        return unless config[:post_signin_per_minute].positive?

        Rack::Attack.blocklist("post signin allow2ban") do |request|
          Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:post_signin_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
          # Resistent to ip changes: you can not signin more than x per minute per email
            request.params[:user][:email].to_s.downcase.gsub(/\s+/, "") if request.post? && request.path.start_with?("/users/sign_in")
          end
        end
      end

      ##
      # Ban on too many password reset requests
      # max 5 requests per minute per IP
      def protect_password_reset!
        return unless config[:post_password_reset_per_minute].positive?

        Rack::Attack.blocklist("post password reset allow2ban") do |request|
          Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:post_password_reset_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
            # Resistent to ip changes: you can not reset password more than x per minute per email
            request.params[:user][:email].to_s.downcase.gsub(/\s+/, "") if request.post? && request.path.start_with?("/users/password")
          end
        end
      end

      ##
      # Ban on too many comment creation/edition requests
      # max 10 requests per minute per IP
      def protect_comments!
        return unless config[:post_comments_per_minute].positive?
        Rack::Attack.blocklist("post comments allow2ban") do |request|
          Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:post_comments_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
            request.ip if (request.post? || request.put?) && request.path.start_with?("/comments")
          end
        end
      end

      ##
      # Add a throtlle over /conversations routes
      # on POST&PUT requests: max 10 requests per minute per IP
      # on GET requests: max 100 requests per minute per IP
      def protect_conversations!
        if config[:post_conversations_per_minute].positive?
          Rack::Attack.blocklist("post conversations allow2ban") do |request|
            Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:post_conversations_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
              request.ip if (request.post? || request.put?) && request.path.start_with?("/conversations")
            end
          end
        end
        if config[:get_conversations_per_minute].positive?
          Rack::Attack.blocklist("get conversations allow2ban") do |request|
            Rack::Attack::Allow2Ban.filter(request.ip,  maxretry: config[:get_conversations_per_minute], findtime: 1.minute, bantime: ban_minutes.minutes.to_i) do |req|
              request.ip if request.get? && request.path.start_with?("/conversations")
            end
          end
        end
      end

      ##
      # Define a list of IPS that are not protected by Rack::Attack
      def setup_safelist!
        return if safelist_ips.empty?

        Rack::Attack.safelist_ip(white_ip)
      end

      ##
      # Block all access to system, but the Decidim.system_accesslist_ips
      def protect_system!
        return unless protect_system?

        Rack::Attack.blocklist("block all access to system") do |request|
          # Requests are blocked if the return value is truthy
          if request.path.start_with?("/system")
            !(Decidim.system_accesslist_ips.any? &&
                Decidim.system_accesslist_ips.map { |ip_address| IPAddr.new(ip_address).include?(IPAddr.new(request.ip)) }.any?)
          end
        end
      end

      ##
      # Enable/Disabled Rack::Attack
      def enable_rack_attack!
        Rack::Attack.enabled = rack_attack_enabled?
      end

      ##
      # Block all access to strange routes
      # fail2ban strategies
      def protect_fail2ban!
        Rack::Attack.blocklist("fail2ban") do |req|
          # `filter` returns truthy value if request fails, or if it's from a previously banned IP
          # so the request is blocked
          Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour.to_i) do
            # The count for the IP is incremented if the return value is truthy
            CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
              forbidden_paths.any? { |path| req.path.include?(path) }
          end
        end
      end

      def rack_attack_enabled?
        config[:enabled]
      end

      def safelist_ips
        @safelist_ips ||= ENV.fetch("SAFELIST_IPS", "").split(",").map(&:strip)
      end

      def protect_system?
        config[:block_system]
      end

      def forbidden_paths
        config[:fail2ban_paths]
      end
    end
  end
end