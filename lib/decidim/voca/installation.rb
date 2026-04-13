# frozen_string_literal: true

module Decidim
  module Voca
    module Installation
      module_function

      def decidim_awesome_installed?
        @decidim_awesome_installed ||= Gem.loaded_specs.has_key?("decidim-decidim_awesome")
      end

      def decidim_templates_installed?
        @decidim_templates_installed ||= Gem.loaded_specs.has_key?("decidim-templates")
      end

      def deepl_installed?
        @deepl_installed ||= Gem.loaded_specs.has_key?("deepl-rb")
      end

      def decidim_conferences_installed?
        @decidim_conferences_installed ||= Gem.loaded_specs.has_key?("decidim-conferences")
      end

      def decidim_initiatives_installed?
        @decidim_initiatives_installed ||= Gem.loaded_specs.has_key?("decidim-initiatives")
      end

      def deepl_enabled?
        deepl_installed? && ::Decidim::Env.new("DECIDIM_DEEPL_API_KEY", "").present?
      end
    end
  end
end
