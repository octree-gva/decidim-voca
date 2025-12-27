# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class OtelDecidimContext
        include DecidimContextAttributes
        def initialize(app)
          @app = app
        end

        def call(env)
          span = ::OpenTelemetry::Trace.current_span

          if span&.recording?
            set_user_attributes(env, span)
            set_organization_attributes(env, span)
            set_participatory_space_attributes(env, span)
            set_component_attributes(env, span)
          else
            Rails.logger.debug("[OpenTelemetry] No active span for request: #{env['PATH_INFO']}")
          end

          @app.call(env)
        rescue StandardError => e
          if defined?(Rails.error)
            Rails.error.report(e, handled: false, severity: :error, context: { request: ActionDispatch::Request.new(env), source: "middleware" })
          end
          raise
        end

      end
    end
  end
end

