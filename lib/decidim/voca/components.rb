# frozen_string_literal: true

module Decidim
  module Voca
    module Components
      MODULE_NAME = "components"

      COMPONENTS = {
        meetings: {
          gem: "decidim-meetings",
          manifest_name: "meetings",
          default_enabled: true,
          metrics: %w(meetings)
        },
        blogs: {
          gem: "decidim-blogs",
          manifest_name: "blogs",
          default_enabled: true,
          metrics: []
        },
        budgets: {
          gem: "decidim-budgets",
          manifest_name: "budgets",
          default_enabled: true,
          metrics: []
        },
        proposals: {
          gem: "decidim-proposals",
          manifest_name: "proposals",
          default_enabled: true,
          metrics: %w(proposals accepted_proposals votes endorsements)
        },
        pages: {
          gem: "decidim-pages",
          manifest_name: "pages",
          default_enabled: true,
          metrics: []
        },
        debates: {
          gem: "decidim-debates",
          manifest_name: "debates",
          default_enabled: true,
          metrics: %w(debates)
        },
        accountability: {
          gem: "decidim-accountability",
          manifest_name: "accountability",
          default_enabled: true,
          metrics: %w(results)
        },
        sortitions: {
          gem: "decidim-sortitions",
          manifest_name: "sortitions",
          default_enabled: true,
          metrics: []
        },
        forms: {
          gem: "decidim-only_forms",
          manifest_name: "only_forms",
          default_enabled: false,
          metrics: %w(survey_answers)
        },
        participatory_documents: {
          gem: "decidim-participatory_documents",
          manifest_name: "participatory_documents",
          default_enabled: false,
          metrics: []
        },
        collaborative_texts: {
          gem: "decidim-collaborative_texts",
          manifest_name: "collaborative_texts",
          default_enabled: false,
          metrics: []
        },
        elections: {
          gem: "decidim-elections",
          manifest_name: "elections",
          default_enabled: false,
          metrics: []
        },
        awesome_map: {
          gem: "decidim-decidim_awesome",
          manifest_name: "awesome_map",
          default_enabled: false,
          metrics: []
        },
        awesome_iframe: {
          gem: "decidim-decidim_awesome",
          manifest_name: "awesome_iframe",
          default_enabled: false,
          metrics: []
        },
        surveys: {
          gem: "decidim-surveys",
          manifest_name: "surveys",
          default_enabled: true,
          metrics: %w(survey_answers)
        }
      }.freeze

      module_function

      def missing_components
        COMPONENTS.reject { |_, config| Decidim::Toggle.gem_present?(config[:gem]) }
      end

      def installed_components
        COMPONENTS.select { |_, config| Decidim::Toggle.gem_present?(config[:gem]) }
      end

      def component_enabled?(organization, component)
        return false if organization.blank?

        config = COMPONENTS.fetch(component.to_sym)
        return false unless Decidim::Toggle.gem_present?(config[:gem])

        component_enabled_flag?(organization, component)
      end

      def enabled?(organization, module_name)
        return false if organization.blank?

        component = component_for_module_name(module_name)
        return false unless component

        config = COMPONENTS.fetch(component)
        return false unless Decidim::Toggle.gem_present?(config[:gem])

        component_enabled_flag?(organization, component)
      end

      def component_for_module_name(module_name)
        COMPONENTS.find { |_, config| config[:manifest_name] == module_name.to_s }&.first ||
          (COMPONENTS.has_key?(module_name.to_sym) ? module_name.to_sym : nil)
      end

      def component_enabled_flag?(organization, component)
        config = COMPONENTS.fetch(component.to_sym)
        attr = "#{component}_enabled"
        raw = Decidim::Toggle.config_for(organization, MODULE_NAME)
        return config.fetch(:default_enabled, false) unless raw.has_key?(attr)

        ActiveModel::Type::Boolean.new.cast(raw[attr])
      end

      def published_components?(organization, component)
        published_components_count(organization, component).positive?
      end

      def published_components_count(organization, component)
        return 0 if organization.blank?

        config = COMPONENTS.fetch(component.to_sym)
        return 0 unless Decidim::Toggle.gem_present?(config[:gem])

        organization.published_components.where(manifest_name: config[:manifest_name]).count
      end

      def published_component_label(component)
        config = COMPONENTS.fetch(component.to_sym)
        I18n.t(
          "#{config[:manifest_name]}.name",
          scope: "decidim.components",
          default: component.to_s.humanize
        )
      end
    end
  end
end
