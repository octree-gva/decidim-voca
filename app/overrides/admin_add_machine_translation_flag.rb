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
    "data-machine-translated" => "<%= Decidim::Voca.minimalistic_deepl? && current_organization.enable_machine_translations? %>"
  },
  original: "9e9359026457bb1a289c94b183011e814d64893d"
)
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_title_bar",
  name: "admin_voca_machine_translation_desktop_flag",
  set_attributes: ".title-bar",
  attributes: {
    "data-machine-translated" => "<%= Decidim::Voca.minimalistic_deepl? && current_organization.enable_machine_translations? %>"
  },
  original: "978289390dedd19463db6ac36784ca94ae4a7d30"
)

# Force admin to manage only default locale, and let machine translation do the rest.
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_js_configuration",
  name: "admin_voca_force_only_default_locale",
  insert_after: "script",
  partial: "decidim/voca/deface_partials/admin_machine_translation_alert",
  original: "387d0b7c5fc52d2ee5e5c6d4b276791d69b4432e"
)
