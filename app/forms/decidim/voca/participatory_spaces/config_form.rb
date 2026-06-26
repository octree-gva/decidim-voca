# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class ConfigForm < Decidim::Form
        include Decidim::Toggle::TabForm

        mimic :organization

        SPACES.each_key do |space|
          attribute :"#{space}_enabled", :boolean, default: SPACES.fetch(space).fetch(:default_enabled, false)
        end

        validate :cannot_disable_spaces_with_published_content

        info :management_callout_html

        def management_callout_html
          installed_gems = ParticipatorySpaces.installed_spaces.values.pluck(:gem)
          missing_gems = ParticipatorySpaces.missing_spaces.values.pluck(:gem)

          not_installed =
            if installed_gems.any?
              I18n.t(
                "decidim.voca.admin.participatory_spaces.not_installed_modules_html",
                missing: missing_gems.join(", ")
              )
            else
              I18n.t(
                "decidim.voca.admin.participatory_spaces.all_modules_missing_html",
                missing: missing_gems.join(", ")
              )
            end

          I18n.t(
            "decidim.voca.admin.participatory_spaces.management_callout_html",
            installed: installed_gems.join(", "),
            not_installed:
          )
        end

        def self.from_model(organization)
          attrs = SPACES.to_h do |space, config|
            [:"#{space}_enabled", ParticipatorySpaces.enabled?(organization, config[:name])]
          end
          from_params(organization: attrs).with_context(current_organization: organization)
        end

        def attribute_disabled?(attribute)
          attribute = attribute.to_sym
          space = attribute.to_s.delete_suffix("_enabled").to_sym
          return false unless SPACES.key?(space)

          !Decidim::Toggle.gem_present?(SPACES.fetch(space)[:gem])
        end

        private

        def cannot_disable_spaces_with_published_content
          return if current_organization.blank?

          ParticipatorySpaces.installed_spaces.each_key do |space|
            next if public_send(:"#{space}_enabled")
            next unless ParticipatorySpaces.published_spaces?(current_organization, space)

            errors.add(
              :"#{space}_enabled",
              I18n.t(
                "decidim.voca.admin.participatory_spaces.cannot_disable_with_published",
                space_name: ParticipatorySpaces.published_space_label(space)
              )
            )
          end
        end
      end
    end
  end
end
