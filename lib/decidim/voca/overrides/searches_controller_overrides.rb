# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module SearchesControllerOverrides
        def index
          Search.call(term, current_organization, filters, page_params) do
            on(:ok) do |results|
              results = Decidim::Voca::SearchFilters.filter_results(results, current_organization)
              results_count = results.sum { |results_by_type| results_by_type.last[:count] }
              blocks = Decidim::Searchable.searchable_resources_by_type.map do |type|
                results.select do |resource_type, _results|
                  type.include?(resource_type)
                end
              end
              expose(sections: results, blocks:, results_count:)
            end
          end
        end
      end
    end
  end
end
