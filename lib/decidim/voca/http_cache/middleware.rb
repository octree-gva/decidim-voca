module Decidim
  module Voca
    module HttpCache
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)
          return @app.call(env) unless public_request?(request) ||  session_open?(request)
          # Check if http_cache key is present in cache
          cache_key = http_cache_key(request)
          cache_hit = Rails.cache.exist?(cache_key)
          if cache_hit && !expires_now?(request)
            cached_body = Rails.cache.read(cache_key)
            return [200, { 'X-Cache-Hit' => '1' }, [cached_body]]
          end
          status, headers, response = @app.call(env)
          headers['X-Cache-Miss'] = 1
          body = content_for_cache(response)
          Rails.cache.write(cache_key, body, expires_in: 1.hour)
          return [status, headers, response]
        end

        private


        def expires_now?(request)
          request.params["skip-cache"] == "true"
        end

        def content_for_cache(response)
          body = ''
          response.each { |part| body << part }
          body
        end

        def http_cache_key(request)
          "http_cache:#{request.fullpath}"        
        end

        def public_request?(request)
          request.get? && !request.xhr? && !request.parseable_data? 
        end

        def session_open?(request)
          # Check warden config to check if any registred strategy have authenticated a user.
          auth_strategies = request.env['warden'].config[:default_strategies].filter { |strategy, config| config.include?(:database_authenticatable) }.keys
          auth_strategies.any? { |strategy| request.env['warden'].user(strategy) }
        end
      end
    end
  end
end
