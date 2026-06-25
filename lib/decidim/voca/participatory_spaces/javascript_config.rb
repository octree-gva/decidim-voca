# frozen_string_literal: true

require "decidim/toggle/javascript_config"

module Decidim
  module Voca
    module ParticipatorySpaces
      module JavascriptConfigExtensions
        def for(organization, registry_name: :organization_settings)
          super.merge(ParticipatorySpaces.javascript_config_for(organization))
        end
      end
    end
  end
end

Decidim::Toggle::JavascriptConfig.singleton_class.prepend(
  Decidim::Voca::ParticipatorySpaces::JavascriptConfigExtensions
)
