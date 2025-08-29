# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "layouts/decidim/_js_configuration",
  name: "insert_weglot_scripts",
  insert_after: "script",
  partial: "decidim/voca/weglot/js_configuration"
)

# Add a locale switcher for weglot
Deface::Override.new(
  virtual_path: "layouts/decidim/footer/_main_language_chooser",
  name: "insert_weglot_locale_switcher",
  surround: "erb[silent]:contains('available_locales.length > 1')",
  closing_selector: "erb[silent]:contains('end')",
  text: <<~ERB
    <% if ::Decidim::Voca.weglot? %>
      <%= render partial: "decidim/voca/weglot/locale_switcher", locals: { switcher_id: "desktop" } %>
    <% end %>
    <div class="voca-js--original-language-chooser" data-weglot-active="<%= ::Decidim::Voca.weglot? %>">
      <%= render_original %>
    </div>
  ERB
)
# layouts/decidim/header/_mobile_language_chooser
Deface::Override.new(
  virtual_path: "layouts/decidim/header/_mobile_language_choose",
  name: "insert_weglot_mobile_language_chooser",
  surround: "erb[silent]:contains('available_locales.length > 1')",
  closing_selector: "erb[silent]:contains('end')",
  text: <<~ERB
    <% if ::Decidim::Voca.weglot? %>
      <%= render partial: "decidim/voca/weglot/locale_switcher_mobile", locals: { switcher_id: "mobile" } %>
    <% end %>
    <div class="voca-js--original-language-chooser" data-weglot-active="<%= ::Decidim::Voca.weglot? %>">
      <%= render_original %>
    </div>
  ERB
)

Deface::Override.new(
  virtual_path: "layouts/decidim/header/_main_links_desktop",
  name: "insert_weglot_main_links_desktop_classes",
  set_attributes: "div:has(erb[loud]:contains('decidim.pages_path'))",
  attributes: {
    class: "main-bar__links-desktop__item-wrapper"
  }
)
Deface::Override.new(
  virtual_path: "layouts/decidim/header/_main_links_desktop",
  name: "insert_weglot_main_links_desktop",
  insert_bottom: "div:has(erb[loud]:contains('decidim.pages_path'))",
  text: <<~ERB
    <%= render partial: "decidim/voca/weglot/topbar_locale_switcher" %>
  ERB
)