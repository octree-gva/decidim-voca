# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class OtelErrorSubscriber
        def report(error, handled:, severity:, context:, source: nil)
          return unless defined?(::OpenTelemetry)

          span = ::OpenTelemetry::Trace.current_span
          
          # Create a span if none exists (e.g., background jobs, rake tasks)
          if span.nil? || !span.recording?
            tracer = ::OpenTelemetry.tracer_provider.tracer("decidim-voca-error")
            span = tracer.start_span("error.report")
            created_span = true
          else
            created_span = false
          end

          begin
            span.record_exception(error)
            span.set_attribute("error.handled", handled)
            span.set_attribute("error.severity", severity.to_s)
            
            # Extract source from context or parameter
            error_source = source || (context.is_a?(Hash) ? context[:source] : nil)
            span.set_attribute("error.source", error_source.to_s) if error_source

            env = extract_env(context)
            if env
              set_user_attributes(env, span)
              set_organization_attributes(env, span)
              set_participatory_space_attributes(env, span)
              set_component_attributes(env, span)
            end

            span.status = ::OpenTelemetry::Trace::Status.error(error.to_s) unless handled
          ensure
            span.finish if created_span
          end
        end

        private

        def extract_env(context)
          return context[:request].env if context.is_a?(Hash) && context[:request]&.respond_to?(:env)

          request = ActionDispatch::Request.current if defined?(ActionDispatch::Request)
          request&.env
        end

        def set_user_attributes(env, span)
          return unless (user = env["warden"]&.user)

          span.set_attribute("enduser.id", user.id.to_s)
        end

        def set_organization_attributes(env, span)
          return unless (org = env["decidim.current_organization"])

          span.set_attribute("decidim.organization.id", org.id.to_s)
          span.set_attribute("decidim.organization.slug", org.slug.to_s) if org.respond_to?(:slug)
        end

        def set_participatory_space_attributes(env, span)
          return unless (space = env["decidim.current_participatory_space"])

          span.set_attribute("decidim.participatory_space.id", space.id.to_s)
          span.set_attribute("decidim.participatory_space.type", space.class.name)
          span.set_attribute("decidim.participatory_space.slug", space.slug.to_s) if space.respond_to?(:slug)
        end

        def set_component_attributes(env, span)
          return unless (component = env["decidim.current_component"])

          span.set_attribute("decidim.component.id", component.id.to_s)
          span.set_attribute("decidim.component.manifest", component.manifest_name.to_s) if component.respond_to?(:manifest_name)
        end
      end
    end
  end
end

