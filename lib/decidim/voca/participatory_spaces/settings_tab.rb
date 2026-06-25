# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class SettingsTab
        def self.register!
          require "decidim/form"
          require "decidim/command"
          require "decidim/toggle/module_config_form"
          require "decidim/toggle/expose_attributes_to_js"
          require_relative "forms"

          Decidim::Toggle.settings_tabs :organization_settings do |tabs|
            registry = Decidim::Toggle::SettingsTabRegistry.find(:organization_settings)

            JS_TOGGLE_FORMS.each do |module_name, form_class|
              registry.register_form_tab(
                module_name,
                form_class,
                Decidim::Toggle::UpdateModuleConfigCommand,
                module_name:
              )
            end

            tabs.add_tab :participatory_spaces,
                         I18n.t("decidim.voca.admin.participatory_spaces.tab"),
                         form: ConfigForm,
                         command: UpdateConfigCommand,
                         position: 12
          end
        end
      end
    end
  end
end
