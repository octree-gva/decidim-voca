# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      MODULES = {
        initiatives: "decidim_initiatives",
        conferences: "decidim_conferences",
        participatory_processes: "decidim_participatory_processes",
        assemblies: "decidim_assemblies"
      }.freeze

      FORM_ATTRIBUTES = {
        initiatives_enabled: :decidim_initiatives,
        conferences_enabled: :decidim_conferences,
        participatory_processes_enabled: :decidim_participatory_processes,
        assemblies_enabled: :decidim_assemblies
      }.freeze

      module_function

      def space_enabled?(organization, space)
        enabled?(organization, MODULES.fetch(space.to_sym))
      end

      def enabled?(organization, module_name)
        record = Decidim::Toggle::OrganizationModuleConfig.find_by(
          decidim_organization_id: organization.id,
          module_name: module_name.to_s
        )
        return true unless record&.config&.key?("enabled")

        ActiveModel::Type::Boolean.new.cast(record.config["enabled"])
      end

      def javascript_config_for(organization)
        MODULES.each_value.index_with { |module_name| enabled?(organization, module_name) }.transform_keys { |m| "#{m}.enabled" }
      end
    end
  end
end
