# frozen_string_literal: true

# Add a flag on main.main to indicate the current organization is using admin
# with machine translation enabled.
# This will be used to hide the language chooser and the language tabs in text fields.
#
# :original = SHA1(match) without whitespace (Deface); Decidim 0.29.7 admin templates.
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_title_bar_responsive",
  name: "admin_voca_machine_translation_responsive_flag",
  set_attributes: ".title-bar",
  attributes: {
    "data-machine-translated" => "<%= current_organization.enable_machine_translations? %>",
    "data-minimalistic-deepl" => "<%= Decidim::Voca.minimalistic_deepl? %>"
  },
  original: "bd6f98a84ee0899f4f7d9f40f16ee42879597f67"
)
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_title_bar",
  name: "admin_voca_machine_translation_desktop_flag",
  set_attributes: ".title-bar",
  attributes: {
    "data-machine-translated" => "<%= current_organization.enable_machine_translations? %>",
    "data-minimalistic-deepl" => "<%= Decidim::Voca.minimalistic_deepl? %>"
  },
  original: "4d5d6b9e6f09a2185e5ae94b27463f560cb232fb"
)

# Force admin to manage only default locale, and let machine translation do the rest.
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_js_configuration",
  name: "admin_voca_force_only_default_locale",
  insert_after: "script",
  partial: "decidim/voca/deepl/overrides/admin_machine_translation_alert",
  original: "2b2692cefad093ec81e7099648a44d139ad6553f"
)
