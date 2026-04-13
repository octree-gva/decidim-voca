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
    end
  end
end

