# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_application",
  name: "voca_admin_body_data_attributes",
  replace: "body",
  text: "<%= render partial: \"decidim/voca/toggle/admin/application\" %>"
)
