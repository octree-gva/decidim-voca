# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      SPACES = {
        initiatives: {
          gem: "decidim-initiatives",
          name: "decidim_initiatives",
          url_segment: "initiatives",
          search_resource_type: "Decidim::Initiative"
        },
        conferences: {
          gem: "decidim-conferences",
          name: "decidim_conferences",
          url_segment: "conferences",
          search_resource_type: "Decidim::Conference"
        },
        participatory_processes: {
          gem: "decidim-participatory_processes",
          name: "decidim_participatory_processes",
          url_segment: "processes",
          search_resource_type: "Decidim::ParticipatoryProcess",
          default_enabled: true
        },
        assemblies: {
          gem: "decidim-assemblies",
          name: "decidim_assemblies",
          url_segment: "assemblies",
          search_resource_type: "Decidim::Assembly",
          default_enabled: true
        }
      }.freeze

      module_function

      def missing_spaces
        SPACES.reject { |_, config| Decidim::Toggle.gem_present?(config[:gem]) }
      end

      def installed_spaces
        SPACES.select { |_, config| Decidim::Toggle.gem_present?(config[:gem]) }
      end

      def space_enabled?(organization, space)
        return false if organization.blank?

        config = SPACES.fetch(space.to_sym)
        return false unless Decidim::Toggle.gem_present?(config[:gem])

        enabled?(organization, config[:name])
      end

      def enabled?(organization, module_name)
        return false if organization.blank?

        config = SPACES.values.find { |space_config| space_config[:name] == module_name.to_s }
        return false unless config && Decidim::Toggle.gem_present?(config[:gem])

        record = Decidim::Toggle::OrganizationModuleConfig.find_by(
          decidim_organization_id: organization.id,
          module_name: module_name.to_s
        )
        return config.fetch(:default_enabled, false) unless record&.config&.has_key?("enabled")

        ActiveModel::Type::Boolean.new.cast(record.config["enabled"])
      end

      def javascript_config_for(organization)
        installed_spaces.each_with_object({}) do |(_, config), js_config|
          js_config["#{config[:name]}.enabled"] = enabled?(organization, config[:name])
        end
      end

      def published_spaces?(organization, space)
        published_spaces_count(organization, space).positive?
      end

      def published_spaces_count(organization, space)
        return 0 if organization.blank?

        config = SPACES.fetch(space.to_sym)
        return 0 unless Decidim::Toggle.gem_present?(config[:gem])

        model_class = config[:search_resource_type]&.safe_constantize
        return 0 unless model_class&.respond_to?(:published)

        model_class.where(organization:).published.count
      end

      def published_space_label(space)
        model_class = SPACES.fetch(space.to_sym)[:search_resource_type]&.safe_constantize
        return space.to_s.humanize unless model_class

        model_class.model_name.human(count: 2)
      end
    end
  end
end
