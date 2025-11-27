require "spec_helper"

module Decidim
  module Voca
    describe SyncRedisRouting do
      subject(:command) { described_class.new(organization) }

      let(:organization) do
        create(
          :organization,
          host: "decidim.example.org",
          secondary_hosts: secondary_hosts,
          voca_external_id: external_id
        )
      end
      let(:external_id) { "router-123" }
      let(:secondary_hosts) { ["mirror.example.org"] }
      let(:redis) { instance_double(Redis, set: nil) }
      let(:service_id) { "service-42" }
      let(:service_url) { "10.0.0.5" }
      let(:service_protocol) { "https" }
      let(:service_port) { "8443" }
      let(:health_interval) { "30s" }
      let(:health_timeout) { "5s" }
      let(:cert_resolver) { "letsencrypt" }
      let(:redis_url) { "redis://redis.internal:6379/7" }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("MASTER_ID").and_return(service_id)
        allow(ENV).to receive(:fetch).with("MASTER_IP").and_return(service_url)
        allow(ENV).to receive(:fetch).with("TRAEFIK_REDIS_URL", "redis://localhost:6379/1").and_return(redis_url)
        allow(ENV).to receive(:fetch).with("TRAEFIK_SERVICE_PROTOCOL", "http").and_return(service_protocol)
        allow(ENV).to receive(:fetch).with("TRAEFIK_SERVICE_PORT", "8080").and_return(service_port)
        allow(ENV).to receive(:fetch).with("TRAEFIK_SERVICE_HEALTHCHECK_INTERVAL", "10s").and_return(health_interval)
        allow(ENV).to receive(:fetch).with("TRAEFIK_SERVICE_HEALTHCHECK_TIMEOUT", "10s").and_return(health_timeout)
        allow(ENV).to receive(:fetch).with("TRAEFIK_CERT_RESOLVER", "selfsigned").and_return(cert_resolver)
        allow(Redis).to receive(:new).with(url: redis_url).and_return(redis)
      end

      describe "#call" do
        it "broadcasts ok" do
          expect { command.call }.to broadcast(:ok)
        end

        it "syncs router and service configuration in redis" do
          command.call

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

          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/servers/0/url", "#{service_protocol}://#{service_url}:#{service_port}")
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/path", "/health/live")
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/interval", health_interval)
          expect(redis).to have_received(:set).with("#{service_prefix}/loadbalancer/healthcheck/timeout", health_timeout)
        end

        context "when the organization is missing a voca external id" do
          before { organization.update!(voca_external_id: nil) }

          it "generates a new identifier" do
            expect(organization).to receive(:create_voca_external_id!).and_call_original

            command.call
          end
        end

        context "when hosts include localhost domains" do
          let(:secondary_hosts) { ["mirror.localhost"] }

          it "skips configuring the cert resolver" do
            command.call

            router_prefix = "traefik/http/routers/#{external_id}"
            expect(redis).not_to have_received(:set).with("#{router_prefix}/tls/certresolver", anything)
          end
        end
      end
    end
  end
end


