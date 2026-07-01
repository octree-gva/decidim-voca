# frozen_string_literal: true

module Decidim
  module Voca
    module Components
      class ConfigForm < Decidim::Form
        include Decidim::Toggle::TabForm
        include Decidim::Toggle::ModuleConfigForm
        include Decidim::Toggle::ExposeAttributesToJs

        self.module_config_name = MODULE_NAME

        mimic :organization

        COMPONENTS.each_key do |component|
          attribute :"#{component}_enabled", :boolean, default: COMPONENTS.fetch(component).fetch(:default_enabled, false)
        end

        expose_to_javascript(*COMPONENTS.keys.map { |component| :"#{component}_enabled" })

        validate :cannot_disable_components_with_published_instances

        info :management_callout_html

        def management_callout_html
          installed_gems = Components.installed_components.values.pluck(:gem).uniq
          missing_gems = Components.missing_components.values.pluck(:gem).uniq

          not_installed =
            if installed_gems.any?
              I18n.t(
                "decidim.voca.admin.components.not_installed_modules_html",
                missing: missing_gems.join(", ")
              )
            else
              I18n.t(
                "decidim.voca.admin.components.all_modules_missing_html",
                missing: missing_gems.join(", ")
              )
            end

          I18n.t(
            "decidim.voca.admin.components.management_callout_html",
            installed: installed_gems.join(", "),
            not_installed:
          )
        end

        def attribute_disabled?(attribute)
          attribute = attribute.to_sym
          component = attribute.to_s.delete_suffix("_enabled").to_sym
          return false unless COMPONENTS.has_key?(component)

          !Decidim::Toggle.gem_present?(COMPONENTS.fetch(component)[:gem])
        end

        private

        def cannot_disable_components_with_published_instances
          return if current_organization.blank?

          Components.installed_components.each_key do |component|
            next if public_send(:"#{component}_enabled")
            next unless Components.published_components?(current_organization, component)

            errors.add(
              :"#{component}_enabled",
              I18n.t(
                "decidim.voca.admin.components.cannot_disable_with_published",
                component_name: Components.published_component_label(component)
              )
            )
          end
        end
      end
    end
  end
end
