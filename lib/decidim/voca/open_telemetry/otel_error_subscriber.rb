# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class OtelErrorSubscriber
        include DecidimContextAttributes

        def report(error, handled:, severity:, context:, source: nil)
          span, created_span = span_for_report
          return unless span

          begin
            record_error_on_span(span, error, report_options(error, handled:, severity:, context:, source:))
            set_context_attributes(span, context)
            span.status = ::OpenTelemetry::Trace::Status.error(error.to_s) unless handled
          rescue StandardError => e
            warn("[OpenTelemetry] Failed to report error: #{e.class} - #{e.message}") if ENV["OTEL_DEBUG"]
          ensure
            span.finish if created_span
          end
        end

        private

        def span_for_report
          current_span = ::OpenTelemetry::Trace.current_span
          if current_span.nil? || !current_span.recording?
            tracer = ::OpenTelemetry.tracer_provider.tracer("decidim-voca-error")
            [tracer.start_span("error.report"), true]
          else
            [current_span, false]
          end
        end

        def report_options(error, handled:, severity:, context:, source:)
          { error:, handled:, severity:, context:, source: }
        end

        def record_error_on_span(span, error, opts)
          span.record_exception(error)
          span.set_attribute("error.handled", opts[:handled])
          span.set_attribute("error.severity", opts[:severity].to_s)
          error_source = opts[:source] || (opts[:context].is_a?(Hash) ? opts[:context][:source] : nil)
          span.set_attribute("error.source", error_source.to_s) if error_source
        end

        def set_context_attributes(span, context)
          env = extract_env(context)
          if env
            set_user_attributes(env, span)
            set_organization_attributes(env, span)
            set_participatory_space_attributes(env, span)
            set_component_attributes(env, span)
          else
            extract_from_controller_context(context, span)
          end
        end

        def extract_env(context)
          # Try to get env from context[:request]
          return context[:request].env if context.is_a?(Hash) && context[:request].respond_to?(:env)

          # Try to get env from context[:env] directly
          return context[:env] if context.is_a?(Hash) && context[:env].is_a?(Hash)

          # Try to get current request from ActionDispatch::Request.current
          begin
            request = ActionDispatch::Request.current
            return request.env if request.respond_to?(:env)
          rescue StandardError
            # ActionDispatch::Request.current might not be available
          end

          # Try to get request from Thread.current (Rails pattern)
          request = Thread.current[:request]
          return request.env if request.respond_to?(:env)

          nil
        end

        def extract_from_controller_context(context, span)
          return unless context.is_a?(Hash)

          return if set_attributes_from_controller_request(context, span)

          set_user_from_context(context, span)
          set_organization_from_context(context, span)
        end

        def set_attributes_from_controller_request(context, span)
          controller = context[:controller] || context[:controller_class]
          return false unless controller.respond_to?(:request)

          request = controller.request
          env = request.respond_to?(:env) ? request.env : nil
          return false unless env

          set_user_attributes(env, span)
          set_organization_attributes(env, span)
          set_participatory_space_attributes(env, span)
          set_component_attributes(env, span)
          true
        end

        def set_user_from_context(context, span)
          user = context[:user] || context[:current_user]
          return unless user.respond_to?(:id)

          span.set_attribute("enduser.id", user.id.to_s)
        end

        def set_organization_from_context(context, span)
          org = context[:organization] || context[:current_organization]
          return unless org

          span.set_attribute("decidim.organization.id", org.id.to_s) if org.respond_to?(:id)
          span.set_attribute("decidim.organization.slug", org.slug.to_s) if org.respond_to?(:slug)
        end
      end
    end
  end
end
