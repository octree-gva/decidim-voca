# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # This module overrides the function responsible
      # for copying the assembly categories,
      # since when there are child categories,
      # the copy is not performed correctly.
      module CopyAssemblyOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :original_copy_assembly_categories, :copy_assembly_categories

          def copy_assembly_categories
            @assembly.categories.where(parent_id: nil).flat_map do |category|
              parent = Category.create!(
                name: category.name,
                description: category.description,
                participatory_space: @copied_assembly
              )
              children = @assembly.categories.where(parent_id: category.id)
              if children
                children.flat_map do |child|
                  copy_subcategories(child, parent)
                end
              end
            end
          end

          def copy_subcategories(child, parent)
            Category.create!(
              name: child.name,
              description: child.description,
              participatory_space: @copied_assembly,
              parent_id: parent.id
            )
          end
        end
      end
    end
  end
end
