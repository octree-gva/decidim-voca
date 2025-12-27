# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      class OtelDecidimContext
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
          end

          @app.call(env)
        end

        private

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

