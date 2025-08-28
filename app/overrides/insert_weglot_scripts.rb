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
      <%= render partial: "decidim/voca/weglot/locale_switcher" %>
    <% end %>
    <div class="voca-js--original-language-chooser" data-weglot-active="<%= ::Decidim::Voca.weglot? %>">
      <%= render_original %>
    </div>
  ERB
)
