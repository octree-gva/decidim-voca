# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      module RequestEnv
        module_function

        def from_current
          req = current_request
          return from_request_object(req) if req

          from_request_object(Thread.current[:request])
        end

        def from_context(context)
          return from_request_object(context[:request]) if context.is_a?(Hash) && context[:request].respond_to?(:env)
          return context[:env] if context.is_a?(Hash) && context[:env].is_a?(Hash)

          from_current
        end

        def from_request_object(request)
          return nil unless request.respond_to?(:env)

          request.env
        end

        def current_request
          ActionDispatch::Request.current if defined?(ActionDispatch::Request)
        rescue StandardError
          nil
        end
      end
    end
  end
end
