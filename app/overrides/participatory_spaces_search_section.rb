# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "decidim/search_results_section/show",
  name: "participatory_spaces_search_section_resource_type",
  set_attributes: "section.search__result",
  attributes: { "data-search-resource-type" => "<%= class_name %>" }
)
