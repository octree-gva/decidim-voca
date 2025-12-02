# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe SyncRedisRouting do
      let(:organization) do
        create(
          :organization,
          host: "decidim.example.org",
          available_locales: I18n.available_locales,
          secondary_hosts:
        ).tap do |org|
          org.voca_organization_key_val_configs
             .find_or_initialize_by(key: "external_id")
             .update!(value: external_id)
        end
      end
      let(:external_id) { "router-123" }
      let(:secondary_hosts) { ["mirror.example.org"] }
      let(:redis) { instance_double(Redis, set: nil, ping: "PONG") }
      let(:service_id) { "service-42" }
      let(:service_url) { "10.0.0.5" }
      let(:service_protocol) { "https" }
      let(:service_port) { "8443" }
      let(:health_interval) { "30s" }
      let(:health_timeout) { "5s" }
      let(:cert_resolver) { "letsencrypt" }
      let(:redis_url) { "redis://redis.internal:6379/7" }

      before do
        # Organization callbacks trigger this command via `.call`, which would
        # pollute our Redis double. Stub the class method so we can exercise the
        # instance under test in isolation.
        ENV["TRAEFIK_REDIS_URL"] = redis_url
        ENV["MASTER_ID"] = service_id
        ENV["MASTER_IP"] = service_url
        ENV["TRAEFIK_SERVICE_PROTOCOL"] = service_protocol
        ENV["TRAEFIK_SERVICE_PORT"] = service_port
        ENV["TRAEFIK_SERVICE_HEALTHCHECK_INTERVAL"] = health_interval
        ENV["TRAEFIK_SERVICE_HEALTHCHECK_TIMEOUT"] = health_timeout
        ENV["TRAEFIK_CERT_RESOLVER"] = cert_resolver
        allow(Redis).to receive(:new).with(url: redis_url).and_return(redis)
        allow(organization).to receive(:create_voca_external_id!).and_call_original
      end

      describe "#call" do
        it "broadcasts ok" do
          expect { described_class.call(organization) }.to broadcast(:ok)
        end

        it "syncs router and service configuration in redis" do
          described_class.call(organization)

          hosts = ["decidim.example.org", *secondary_hosts]
          router_prefix = "traefik/http/routers/#{external_id}"
          service_prefix = "traefik/http/services/service-#{service_id}"

          expect(redis).to have_received(:set).with(
            "#{router_prefix}/rule",
            hosts.map { |host| "Host(`#{host}`)" }.join(" || ")
          )
          expect(redis).to have_received(:set).with("#{router_prefix}/entrypoints/0", "websecure")
          expect(redis).to have_received(:set).with("#{router_prefix}/service", "service-#{service_id}")
          expect(redis).to have_received(:set).with("#{router_prefix}/priority", "100")
          expect(redis).to have_received(:set).with("#{router_prefix}/tls/certresolver", cert_resolver)

          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/servers/0/url", "#{service_protocol}://#{service_url}:#{service_port}").at_least(:once)
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/path", "/health/live").at_least(:once)
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/interval", health_interval).at_least(:once)
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/timeout", health_timeout).at_least(:once)
        end

        context "when the organization is missing a voca external id" do
          before { organization.voca_organization_key_val_configs.destroy_all }

          it "generates a new identifier" do
            expect do
              described_class.call(organization)
            end.to change(organization, :voca_external_id).from(nil).to(a_string_matching(/^[0-9a-f-]{36}$/))
          end
        end

        context "when hosts include localhost domains" do
          let(:secondary_hosts) { ["mirror.localhost"] }

          it "skips configuring the cert resolver" do
            described_class.call(organization)

            router_prefix = "traefik/http/routers/#{external_id}"
            expect(redis).not_to have_received(:set).with("#{router_prefix}/tls/certresolver", anything)
          end
        end
      end
    end
  end
end
