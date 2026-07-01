# frozen_string_literal: true

module Decidim
  module Voca
    module Components
      class SettingsTab
        def self.register!
          Decidim::Toggle.settings_tabs :organization_settings do |tabs|
            tabs.add_tab :components,
                         I18n.t("decidim_toggle.system.#{Components::MODULE_NAME}.tab"),
                         form: Decidim::Voca::Components::ConfigForm,
                         command: Decidim::Toggle::UpdateModuleConfigCommand,
                         module_name: Components::MODULE_NAME,
                         position: 13
          end
        end
      end
    end
  end
end
