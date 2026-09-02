# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/_application",
  name: "participatory_spaces_public_body_data_attributes",
  replace: "body",
  text: "<%= render partial: \"decidim/voca/toggle/application\" %>"
)
