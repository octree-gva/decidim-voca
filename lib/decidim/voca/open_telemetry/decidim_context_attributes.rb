# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      module DecidimContextAttributes
        def set_user_attributes(env, target)
          warden = env["warden"]
          return unless warden

          user = warden.authenticate(scope: :user)
          return unless user

          set_attribute(target, "enduser.id", user.id.to_s)
          set_attribute(target, "enduser.nickname", user.nickname.to_s)
        end

        def set_organization_attributes(env, target)
          org = env["decidim.current_organization"]
          return unless org

          set_attribute(target, "decidim.organization.id", org.id.to_s)
          set_attribute(target, "decidim.organization.slug", org.slug.to_s) if org.respond_to?(:slug)
          set_attribute(target, "service.instance.id", org.host.to_s) if org.respond_to?(:host) && org.host.present?
        end

        def set_participatory_space_attributes(env, target)
          space = env["decidim.current_participatory_space"]
          return unless space

          set_attribute(target, "decidim.participatory_space.id", space.id.to_s)
          set_attribute(target, "decidim.participatory_space.type", space.class.name)
          set_attribute(target, "decidim.participatory_space.slug", space.slug.to_s) if space.respond_to?(:slug)
        end

        def set_component_attributes(env, target)
          component = env["decidim.current_component"]
          return unless component

          set_attribute(target, "decidim.component.id", component.id.to_s)
          set_attribute(target, "decidim.component.manifest", component.manifest_name.to_s) if component.respond_to?(:manifest_name)
        end

        private

        def set_attribute(target, key, value)
          if target.respond_to?(:set_attribute)
            target.set_attribute(key, value)
          elsif target.is_a?(Hash)
            target[key] = value
          else
            raise ArgumentError, "Target must respond to set_attribute or be a Hash"
          end
        end
      end
    end
  end
end
