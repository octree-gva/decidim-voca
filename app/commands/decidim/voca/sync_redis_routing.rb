# frozen_string_literal: true

module Decidim
  module Voca
    # This command get all the available host and subdomains of all organizations
    # and sync them to the redis database, following Traefik routing format.
    # As we can have N servers, we need to sync the routing using unique keys (UUID)
    # to avoid conflicts.
    class SyncRedisRouting < Command
      attr_reader :organization

      def initialize(organization)
        @organization = organization
      end

      def call
        return broadcast(:ok) unless redis?

        ensure_voca_external_id!(organization)
        upsert_routing(organization)
        upsert_common_routing!
        broadcast(:ok)
      end

      private

      def redis?
        raw_connection_url = ENV.fetch("TRAEFIK_REDIS_URL", "redis://traefik-db:6379/1")
        connection_url = begin
          URI.parse(raw_connection_url)
        rescue URI::InvalidURIError
          ""
        end

        connection_url.present? && URI.parse(connection_url).host.present? && Redis.new(url: connection_url).ping == "PONG"
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Can't connect to Redis: #{e.message}")
        false
      end

      def ensure_voca_external_id!(organization)
        organization.voca_external_id || organization.create_voca_external_id!
      end

      def traefik_kv(organization)
        # Will connect router Host(`host`) || HOST(`subdomains`)
        # The service will point to the private ip exposed by Environment Variable `MASTER_IP`
        # SEE https://doc.traefik.io/traefik/reference/routing-configuration/other-providers/kv/
        external_id = organization.voca_external_id
        hosts = [organization.host, *organization.secondary_hosts].select do |host|
          URI.parse("http://#{host}").host.present?
        end
        kv = {
          "traefik/http/routers/#{external_id}/rule" => hosts.map { |host| "Host(`#{host}`)" }.join(" || "),
          "traefik/http/routers/#{external_id}/entrypoints/0" => "websecure",
          "traefik/http/routers/#{external_id}/service" => "service-#{service_id}",
          "traefik/http/routers/#{external_id}/priority" => "100"
        }
        # Skip cert resolver for localhost domains - Traefik will use defaultGeneratedCert
        kv["traefik/http/routers/#{external_id}/tls/certresolver"] = traefik_cert_resolver unless hosts.any? { |host| host.end_with?(".localhost") || host == "localhost" }
        kv
      end

      def service_id
        @service_id ||= ENV.fetch("MASTER_ID")
      end

      def service_url
        @service_url ||= ENV.fetch("MASTER_IP")
      end

      def upsert_routing(organization)
        traefik_kv(organization).each do |key, value|
          redis.set(key, value)
        end
      end

      def upsert_common_routing!
        url = "#{traefik_service_protocol}://#{service_url}:#{traefik_service_port}"
        redis.set("traefik/http/services/service-#{service_id}/loadbalancer/servers/0/url", url)
        redis.set("traefik/http/services/service-#{service_id}/loadbalancer/healthcheck/path", traefik_service_healthcheck_path)
        redis.set("traefik/http/services/service-#{service_id}/loadbalancer/healthcheck/interval", traefik_service_healthcheck_interval)
        redis.set("traefik/http/services/service-#{service_id}/loadbalancer/healthcheck/timeout", traefik_service_healthcheck_timeout)
        redis.set("traefik/http/services/service-#{service_id}/loadbalancer/healthcheck/port", traefik_service_healthcheck_port)
      end

      def traefik_service_healthcheck_port
        @traefik_service_healthcheck_port ||= ENV.fetch("TRAEFIK_SERVICE_HEALTHCHECK_PORT", "8080")
      end

      def traefik_service_healthcheck_path
        @traefik_service_healthcheck_path ||= ENV.fetch("TRAEFIK_SERVICE_HEALTHCHECK_PATH", "/health/live")
      end

      def redis
        @redis ||= Redis.new(url: ENV.fetch("TRAEFIK_REDIS_URL", "redis://localhost:6379/1"))
      end

      def traefik_service_protocol
        @traefik_service_protocol ||= ENV.fetch("TRAEFIK_SERVICE_PROTOCOL", "http")
      end

      def traefik_service_port
        @traefik_service_port ||= ENV.fetch("TRAEFIK_SERVICE_PORT", "8080")
      end

      def traefik_service_healthcheck_interval
        @traefik_service_healthcheck_interval ||= ENV.fetch("TRAEFIK_SERVICE_HEALTHCHECK_INTERVAL", "60s")
      end

      def traefik_service_healthcheck_timeout
        @traefik_service_healthcheck_timeout ||= ENV.fetch("TRAEFIK_SERVICE_HEALTHCHECK_TIMEOUT", "10s")
      end

      def traefik_cert_resolver
        @traefik_cert_resolver ||= ENV.fetch("TRAEFIK_CERT_RESOLVER", "letsencrypt")
      end
    end
  end
end
