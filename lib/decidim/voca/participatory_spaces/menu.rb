# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class Menu
        class << self
          def register!
            register_public_menus!
            register_admin_menu_modules!
          end

          private

          def register_public_menus!
            register_initiatives_menus!
            register_participatory_processes_menus!
            register_assemblies_menus!
            register_conferences_menus!
          end

          def register_initiatives_menus!
            Decidim.menu :menu do |menu|
              menu.remove_item :initiatives
            end

            Decidim.menu :menu do |menu|
              menu.add_item :initiatives,
                            I18n.t("menu.initiatives", scope: "decidim"),
                            decidim_initiatives.initiatives_path,
                            position: 2.4,
                            active: %r{^/(initiatives|create_initiative)},
                            if: ParticipatorySpaces.space_enabled?(current_organization, :initiatives) &&
                                Decidim::InitiativesType.joins(:scopes).where(organization: current_organization).any?
            end

            Decidim.menu :mobile_menu do |menu|
              menu.remove_item :initiatives
            end

            Decidim.menu :mobile_menu do |menu|
              menu.add_item :initiatives,
                            I18n.t("menu.initiatives", scope: "decidim"),
                            decidim_initiatives.initiatives_path,
                            position: 2.4,
                            active: %r{^/(initiatives|create_initiative)},
                            if: ParticipatorySpaces.space_enabled?(current_organization, :initiatives) &&
                                !Decidim::InitiativesType.joins(:scopes).where(organization: current_organization).all.empty?
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.remove_item :initiatives
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.add_item :initiatives,
                            I18n.t("menu.initiatives", scope: "decidim"),
                            decidim_initiatives.initiatives_path,
                            position: 30,
                            active: :inclusive,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :initiatives) &&
                                Decidim::InitiativesType.joins(:scopes).where(organization: current_organization).any?
            end
          end

          def register_participatory_processes_menus!
            Decidim.menu :menu do |menu|
              menu.remove_item :participatory_processes
            end

            Decidim.menu :menu do |menu|
              menu.add_item :participatory_processes,
                            I18n.t("menu.processes", scope: "decidim"),
                            decidim_participatory_processes.participatory_processes_path,
                            position: 2,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :participatory_processes) &&
                                Decidim::ParticipatoryProcess.where(organization: current_organization).published.any?,
                            active: %r{^/process(es|_groups)}
            end

            Decidim.menu :mobile_menu do |menu|
              menu.remove_item :participatory_processes
            end

            Decidim.menu :mobile_menu do |menu|
              menu.add_item :participatory_processes,
                            I18n.t("menu.processes", scope: "decidim"),
                            decidim_participatory_processes.participatory_processes_path,
                            position: 2,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :participatory_processes) &&
                                Decidim::ParticipatoryProcess.where(organization: current_organization).published.any?,
                            active: %r{^/process(es|_groups)}
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.remove_item :participatory_processes
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.add_item :participatory_processes,
                            I18n.t("menu.processes", scope: "decidim"),
                            decidim_participatory_processes.participatory_processes_path,
                            position: 10,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :participatory_processes) &&
                                Decidim::ParticipatoryProcess.where(organization: current_organization).published.any?,
                            active: %r{^/process(es|_groups)}
            end
          end

          def register_assemblies_menus!
            Decidim.menu :menu do |menu|
              menu.remove_item :assemblies
            end

            Decidim.menu :menu do |menu|
              menu.add_item :assemblies,
                            I18n.t("menu.assemblies", scope: "decidim"),
                            decidim_assemblies.assemblies_path,
                            position: 2.2,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :assemblies) &&
                                OrganizationPublishedAssemblies.new(current_organization, current_user).any?,
                            active: :inclusive
            end

            Decidim.menu :mobile_menu do |menu|
              menu.remove_item :assemblies
            end

            Decidim.menu :mobile_menu do |menu|
              menu.add_item :assemblies,
                            I18n.t("menu.assemblies", scope: "decidim"),
                            decidim_assemblies.assemblies_path,
                            position: 2.2,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :assemblies) &&
                                OrganizationPublishedAssemblies.new(current_organization, current_user).any?,
                            active: :inclusive
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.remove_item :assemblies
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.add_item :assemblies,
                            I18n.t("menu.assemblies", scope: "decidim"),
                            decidim_assemblies.assemblies_path,
                            position: 20,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :assemblies) &&
                                OrganizationPublishedAssemblies.new(current_organization, current_user).any?,
                            active: :inclusive
            end
          end

          def register_conferences_menus!
            Decidim.menu :menu do |menu|
              menu.remove_item :conferences
            end

            Decidim.menu :menu do |menu|
              menu.add_item :conferences,
                            I18n.t("menu.conferences", scope: "decidim"),
                            decidim_conferences.conferences_path,
                            position: 2.8,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :conferences) &&
                                Decidim::Conference.where(organization: current_organization).published.any?,
                            active: :inclusive
            end

            Decidim.menu :mobile_menu do |menu|
              menu.remove_item :conferences
            end

            Decidim.menu :mobile_menu do |menu|
              menu.add_item :conferences,
                            I18n.t("menu.conferences", scope: "decidim"),
                            decidim_conferences.conferences_path,
                            position: 2.8,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :conferences) &&
                                Decidim::Conference.where(organization: current_organization).published.any?,
                            active: :inclusive
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.remove_item :conferences
            end

            Decidim.menu :home_content_block_menu do |menu|
              menu.add_item :conferences,
                            I18n.t("menu.conferences", scope: "decidim"),
                            decidim_conferences.conferences_path,
                            position: 50,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :conferences) &&
                                Decidim::Conference.where(organization: current_organization).published.any?,
                            active: :inclusive
            end
          end

          def register_admin_menu_modules!
            Decidim.menu :admin_menu_modules do |menu|
              menu.remove_item :initiatives
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.add_item :initiatives,
                            I18n.t("menu.initiatives", scope: "decidim.admin"),
                            decidim_admin_initiatives.initiatives_path,
                            icon_name: "lightbulb-flash-line",
                            position: 2.4,
                            active: is_active_link?(decidim_admin_initiatives.initiatives_path) ||
                                    is_active_link?(decidim_admin_initiatives.initiatives_types_path) ||
                                    is_active_link?(
                                      decidim_admin_initiatives.edit_initiatives_setting_path(
                                        Decidim::InitiativesSettings.find_or_create_by!(organization: current_organization)
                                      )
                                    ),
                            if: ParticipatorySpaces.space_enabled?(current_organization, :initiatives) &&
                                allowed_to?(:enter, :space_area, space_name: :initiatives)
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.remove_item :participatory_processes
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.add_item :participatory_processes,
                            I18n.t("menu.participatory_processes", scope: "decidim.admin"),
                            decidim_admin_participatory_processes.participatory_processes_path,
                            icon_name: "treasure-map-line",
                            position: 2,
                            active: is_active_link?(decidim_admin_participatory_processes.participatory_processes_path, :inclusive) ||
                                    is_active_link?(decidim_admin_participatory_processes.participatory_process_groups_path, :inclusive) ||
                                    is_active_link?(decidim_admin_participatory_processes.participatory_process_types_path),
                            if: ParticipatorySpaces.space_enabled?(current_organization, :participatory_processes) &&
                                (allowed_to?(:enter, :space_area, space_name: :processes) ||
                                  allowed_to?(:enter, :space_area, space_name: :process_groups))
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.remove_item :assemblies
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.add_item :assemblies,
                            I18n.t("menu.assemblies", scope: "decidim.admin"),
                            decidim_admin_assemblies.assemblies_path,
                            icon_name: "government-line",
                            position: 2.2,
                            active: is_active_link?(decidim_admin_assemblies.assemblies_path) ||
                                    is_active_link?(decidim_admin_assemblies.assemblies_types_path),
                            if: ParticipatorySpaces.space_enabled?(current_organization, :assemblies) &&
                                allowed_to?(:enter, :space_area, space_name: :assemblies)
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.remove_item :conferences
            end

            Decidim.menu :admin_menu_modules do |menu|
              menu.add_item :conferences,
                            I18n.t("menu.conferences", scope: "decidim.admin"),
                            decidim_admin_conferences.conferences_path,
                            icon_name: "live-line",
                            position: 2.8,
                            active: :inclusive,
                            if: ParticipatorySpaces.space_enabled?(current_organization, :conferences) &&
                                allowed_to?(:enter, :space_area, space_name: :conferences)
            end
          end
        end
      end
    end
  end
end
