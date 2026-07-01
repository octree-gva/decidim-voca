# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_application",
  name: "voca_admin_body_data_attributes",
  set_attributes: "body",
  attributes: Decidim::Voca::AdminBodyDataAttributes.deface_attributes
)
