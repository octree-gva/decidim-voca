# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      MODULE_CONFIG_NAME = "spaces"

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

        space_enabled_flag?(organization, space)
      end

      def enabled?(organization, module_name)
        return false if organization.blank?

        space = space_for_module_name(module_name)
        return false unless space

        config = SPACES.fetch(space)
        return false unless Decidim::Toggle.gem_present?(config[:gem])

        space_enabled_flag?(organization, space)
      end

      def space_for_module_name(module_name)
        SPACES.find { |_, config| config[:name] == module_name.to_s }&.first
      end

      def space_enabled_flag?(organization, space)
        config = SPACES.fetch(space.to_sym)
        attr = "#{space}_enabled"
        raw = Decidim::Toggle.config_for(organization, MODULE_CONFIG_NAME)
        return config.fetch(:default_enabled, false) unless raw.has_key?(attr)

        ActiveModel::Type::Boolean.new.cast(raw[attr])
      end

      def published_spaces?(organization, space)
        published_spaces_count(organization, space).positive?
      end

      def published_spaces_count(organization, space)
        return 0 if organization.blank?

        config = SPACES.fetch(space.to_sym)
        return 0 unless Decidim::Toggle.gem_present?(config[:gem])

        model_class = config[:search_resource_type]&.safe_constantize
        return 0 unless model_class.respond_to?(:published)

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
