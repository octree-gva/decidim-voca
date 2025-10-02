# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module CheckBoxesTreeHelperOverrides
        extend ActiveSupport::Concern

        included do
          def filter_categories_values
            sorted_main_categories = current_participatory_space.categories.first_class.includes(:subcategories).sort_by do |category|
              [category.weight, translated_attribute(category.name)]
            end

            categories_values = sorted_main_categories.flat_map do |category|
              sorted_descendant_categories = category.descendants.includes(:subcategories).sort_by do |subcategory|
                [subcategory.weight, translated_attribute(subcategory.name)]
              end

              subcategories = sorted_descendant_categories.flat_map do |subcategory|
                Decidim::CheckBoxesTreeHelper::TreePoint.new(subcategory.id.to_s, translated_attribute(subcategory.name))
              end

              Decidim::CheckBoxesTreeHelper::TreeNode.new(
                Decidim::CheckBoxesTreeHelper::TreePoint.new(category.id.to_s, translated_attribute(category.name)),
                subcategories
              )
            end

            Decidim::CheckBoxesTreeHelper::TreeNode.new(
              Decidim::CheckBoxesTreeHelper::TreePoint.new("", t("decidim.core.application_helper.filter_category_values.all")),
              categories_values
            )
          end
        end
      end
    end
  end
end
