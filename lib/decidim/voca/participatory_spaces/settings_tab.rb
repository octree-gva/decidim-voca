# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class SettingsTab
        def self.register!
          Decidim::Toggle.settings_tabs :organization_settings do |tabs|
            tabs.add_tab :participatory_spaces,
                         I18n.t("decidim_toggle.system.#{ParticipatorySpaces::MODULE_NAME}.tab"),
                         form: Decidim::Voca::ParticipatorySpaces::ConfigForm,
                         command: Decidim::Toggle::UpdateModuleConfigCommand,
                         module_name: ParticipatorySpaces::MODULE_NAME,
                         position: 12
          end
        end
      end
    end
  end
end
