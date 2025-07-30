# Add a flag on main.main to indicate the current organization is using admin 
# with machine translation enabled.
# This will be used to hide the language chooser and the language tabs in text fields.
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_application",
  name: "admin_voca_machine_translation_flag",
  set_attributes: ".main",
  attributes: {
    "data-machine-translation-flag" => "<%= Decidim::Voca.minimalistic_deepl? && current_organization.enable_machine_translations? %>"
  }
)

# Force admin to manage only default locale, and let machine translation do the rest.
Deface::Override.new(
  virtual_path: "layouts/decidim/admin/_application",
  name: "admin_voca_force_only_default_locale",
  insert_before: ".main",
  text: <<~ERB
    <% if Decidim::Voca.minimalistic_deepl? && current_organization.enable_machine_translations? && current_organization.default_locale.to_s != I18n.locale.to_s %>
       <% 
        locale = current_organization.default_locale
      %>
      <div class="voca__machine_translation_alert">
        <div class="voca__machine_translation_alert__content">
          <h2 class="h2"><%= t("decidim.voca.admin.machine_translation_alert.title", current_locale: I18n.locale, default_locale: current_organization.default_locale) %></h2>
          <p class="prose text-lg">
            <%= t("decidim.voca.admin.machine_translation_alert.description_html", current_locale: I18n.locale, default_locale: current_organization.default_locale) %>
            <%= link_to t("decidim.voca.admin.machine_translation_alert.button"), decidim.locale_path(locale:), method: :post, lang: locale, class: "button button__sm button__secondary" %>
          </p>
        </div>
      </div>
    <% end %>
  ERB
)