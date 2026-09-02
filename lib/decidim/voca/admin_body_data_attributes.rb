# frozen_string_literal: true

module Decidim
  module Voca
    module AdminBodyDataAttributes
      module_function

      def deface_attributes(current_organization)
        ParticipatorySpaces::BodyDataAttributes.deface_attributes(current_organization).merge(
          Components::BodyDataAttributes.deface_attributes(current_organization)
        )
      end
    end
  end
end
