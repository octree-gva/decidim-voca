# frozen_string_literal: true

# Add css/js for admin
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_header",
  name: "admin_voca_css_pack",
  insert_before: "erb[loud]:contains('stylesheet_pack_tag')",
  text: "<%= append_stylesheet_pack_tag 'admin_decidim_voca' %><%= append_javascript_pack_tag 'admin_decidim_voca_js' %>"
)

# Add js/css for frontpage
Deface::Override.new(
  virtual_path: "layouts/decidim/_head",
  name: "voca_css_pack",
  insert_before: "erb[loud]:contains('decidim_overrides')",
  text: "<%= append_stylesheet_pack_tag 'decidim_voca' %><%= prepend_javascript_pack_tag 'decidim_voca_js' %>"
)
