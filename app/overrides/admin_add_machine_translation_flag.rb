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
        params_with_default_locale = request.query_parameters.merge(locale: current_organization.default_locale)
        redirect_url = "\#{request.path}?\#{params_with_default_locale.to_query}"
      %>

      <meta http-equiv="refresh" content="5; url=<%= redirect_url %>">
      <div class="voca__machine_translation_alert">
        <div class="voca__machine_translation_alert__content">
          <h2 class="h2"><%= t("decidim.voca.admin.machine_translation_alert.title", current_locale: I18n.locale, default_locale: current_organization.default_locale) %></h2>
          <p class="prose text-lg"><%= t("decidim.voca.admin.machine_translation_alert.description_html", redirect_url: redirect_url, current_locale: I18n.locale, default_locale: current_organization.default_locale) %></p>
        </div>
      </div>
    <% end %>
  ERB
)


# TODO Hook on Decidim::FormBuilder to avoid value beeing set on inputs
# https://github.com/decidim/decidim/blob/e713f35ce655decc437ea42d13312161d1cbe187/decidim-core/lib/decidim/form_builder.rb#L80C56-L80C63