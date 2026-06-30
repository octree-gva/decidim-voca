# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      module BodyDataAttributes
        module_function

        def deface_attributes
          SPACES.each_key.to_h do |space|
            [
              "data-#{space.to_s.dasherize}-enabled",
              "<%= Decidim::Voca::ParticipatorySpaces.space_enabled?(current_organization, :#{space}) %>"
            ]
          end
        end
      end
    end
  end
end
