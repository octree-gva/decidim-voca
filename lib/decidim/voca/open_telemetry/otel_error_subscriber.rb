# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class OtelErrorSubscriber
        def report(error, handled:, severity:, context:, source: nil)
          return unless defined?(::OpenTelemetry)

          current_span = ::OpenTelemetry::Trace.current_span
          
          # Create a span if none exists (e.g., background jobs, rake tasks)
          if current_span.nil? || !current_span.recording?
            tracer = ::OpenTelemetry.tracer_provider.tracer("decidim-voca-error")
            span = tracer.start_span("error.report")
            created_span = true
          else
            span = current_span
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
            else
              # Try to extract from controller context if available
              extract_from_controller_context(context, span)
            end

            span.status = ::OpenTelemetry::Trace::Status.error(error.to_s) unless handled
          ensure
            span.finish if created_span
          end
        end

        private

        def extract_env(context)
          # Try to get env from context[:request]
          if context.is_a?(Hash) && context[:request]&.respond_to?(:env)
            return context[:request].env
          end

          # Try to get env from context[:env] directly
          if context.is_a?(Hash) && context[:env].is_a?(Hash)
            return context[:env]
          end

          # Try to get current request from ActionDispatch::Request.current
          if defined?(ActionDispatch::Request)
            begin
              request = ActionDispatch::Request.current
              return request.env if request&.respond_to?(:env)
            rescue StandardError
              # ActionDispatch::Request.current might not be available
            end
          end

          # Try to get request from Thread.current (Rails pattern)
          if (request = Thread.current[:request])&.respond_to?(:env)
            return request.env
          end

          nil
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

        def extract_from_controller_context(context, span)
          return unless context.is_a?(Hash)

          # Try to get request from controller
          controller = context[:controller] || context[:controller_class]
          if controller&.respond_to?(:request)
            request = controller.request
            env = request.env if request&.respond_to?(:env)
            if env
              set_user_attributes(env, span)
              set_organization_attributes(env, span)
              set_participatory_space_attributes(env, span)
              set_component_attributes(env, span)
              return
            end
          end

          # Try to get user directly from context
          if (user = context[:user] || context[:current_user])
            span.set_attribute("enduser.id", user.id.to_s) if user.respond_to?(:id)
          end

          # Try to get organization directly from context
          if (org = context[:organization] || context[:current_organization])
            span.set_attribute("decidim.organization.id", org.id.to_s) if org.respond_to?(:id)
            span.set_attribute("decidim.organization.slug", org.slug.to_s) if org.respond_to?(:slug)
          end
        end
      end
    end
  end
end

