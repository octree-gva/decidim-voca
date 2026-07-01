# frozen_string_literal: true

module Decidim
  module Voca
    module Components
      module BodyDataAttributes
        module_function

        def deface_attributes
          COMPONENTS.each_key.to_h do |component|
            [
              "data-#{component.to_s.dasherize}-enabled",
              "<%= Decidim::Voca::Components.component_enabled?(current_organization, :#{component}) %>"
            ]
          end
        end
      end
    end
  end
end
