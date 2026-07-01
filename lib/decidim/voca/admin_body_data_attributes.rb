# frozen_string_literal: true

module Decidim
  module Voca
    module AdminBodyDataAttributes
      module_function

      def deface_attributes
        ParticipatorySpaces::BodyDataAttributes.deface_attributes.merge(
          Components::BodyDataAttributes.deface_attributes
        )
      end
    end
  end
end
