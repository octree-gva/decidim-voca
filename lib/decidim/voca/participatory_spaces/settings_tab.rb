# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class SettingsTab
        def self.register!
          Decidim::Toggle.settings_tabs :organization_settings do |tabs|
            tabs.add_tab :participatory_spaces,
                         I18n.t("decidim.voca.admin.participatory_spaces.tab"),
                         form: Decidim::Voca::ParticipatorySpaces::ConfigForm,
                         command: Decidim::Toggle::UpdateModuleConfigCommand,
                         module_name: ParticipatorySpaces::MODULE_CONFIG_NAME,
                         position: 12
          end
        end
      end
    end
  end
end
