# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_application",
  name: "participatory_spaces_admin_body_data_attributes",
  set_attributes: "body",
  attributes: Decidim::Voca::ParticipatorySpaces::BodyDataAttributes.deface_attributes
)
