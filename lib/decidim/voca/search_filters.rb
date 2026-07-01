# frozen_string_literal: true

module Decidim
  module Voca
    module SearchFilters
      module_function

      def filter_results(results, organization)
        disabled = disabled_resource_types(organization)
        return results if disabled.empty?

        results.reject { |type, _| disabled.include?(type) }
      end

      def disabled_resource_types(organization)
        return [] if organization.blank?

        disabled_participatory_space_resource_types(organization) +
          disabled_component_resource_types(organization)
      end

      def disabled_participatory_space_resource_types(organization)
        ParticipatorySpaces::SPACES.filter_map do |space, config|
          config[:search_resource_type] unless ParticipatorySpaces.space_enabled?(organization, space)
        end
      end

      def disabled_component_resource_types(organization)
        Components::COMPONENTS.flat_map do |component, _config|
          next [] if Components.component_enabled?(organization, component)

          search_resource_types_for_component(component)
        end
      end

      def search_resource_types_for_component(component)
        config = Components::COMPONENTS[component.to_sym]
        return [] unless config

        manifest = Decidim.find_component_manifest(config[:manifest_name])
        return [] unless manifest

        Decidim.resource_manifests
               .select { |resource| resource.component_manifest == manifest && resource.searchable }
               .map(&:model_class_name)
      end
    end
  end
end
