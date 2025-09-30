# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/header/_menu_breadcrumb_mobile_tablet",
  name: "fix_html_escape_mobile",
  replace: "erb[silent]:contains('item_label = decidim_escape_translated(item[:label])')",
  text: <<~ERB
    <% item_label = translated_attribute(item[:label]) %>
  ERB
)
