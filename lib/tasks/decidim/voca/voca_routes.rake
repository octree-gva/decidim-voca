# frozen_string_literal: true

## Read the redis instance and give all the routes registered with:
## router.host => service url route
def redis
  @redis ||= Redis.new(url: ENV.fetch("TRAEFIK_REDIS_URL", "redis://localhost:6379/1"))
end
def redis?
  connection_url = ENV.fetch("TRAEFIK_REDIS_URL", "redis://localhost:6379/1").present?
  connection_url.present? && Redis.new(url: connection_url).ping == "PONG"
end
def print_routes_jsonl
  return unless redis?
  router_keys = redis.keys("traefik/http/routers/*/rule")
  router_keys.each do |rule_key|
    matches = rule_key.match(%r{traefik/http/routers/([^/]+)/rule})
    next unless matches

    router_id = matches[1]
    rule = redis.get(rule_key)
    service_key = "traefik/http/routers/#{router_id}/service"
    service_name = redis.get(service_key)
    next unless service_name

    service_url_key = "traefik/http/services/#{service_name}/loadbalancer/servers/0/url"
    service_url = redis.get(service_url_key)
    next unless service_url

    hosts = rule.scan(/Host\(`([^`]+)`\)/).flatten
    hosts.each do |host|
      puts "\"#{host}\": \"#{service_url}\""
    end
  end
end

def print_routes_traefik
  return unless redis?
  router_keys = redis.keys("traefik/http/*")
  traefik_config = {}
  router_keys.each do |rule_key|
    config_key = rule_key.split("/")
    value = redis.get(rule_key)
    next unless value

    current = traefik_config
    config_key[0..-2].each { |key| current = (current[key] ||= {}) }
    current[config_key.last] = value
  end
  puts JSON.pretty_generate(traefik_config)
end

namespace :decidim do
  namespace :voca do
    desc "Print available routes in central Redis instance"
    task routes: :environment do
      format = ENV.fetch("FORMAT", "jsonl")
      puts "Redis is not available for traefik routing" unless redis?
      print_routes_jsonl if format == "jsonl"
      print_routes_traefik if format == "traefik"
    end
  end
end
