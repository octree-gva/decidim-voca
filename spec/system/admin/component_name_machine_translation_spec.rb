# frozen_string_literal: true

require "securerandom"
require "spec_helper"

RSpec.describe Decidim::Component, :slow do
  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(4)}.lvh.me",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true,
      machine_translation_display_priority: "translation"
    )
  end

  let(:user) { create(:user, :admin, :confirmed, organization:) }

  let!(:participatory_process) do
    create(
      :participatory_process,
      :with_steps,
      organization:,
      title: { "en" => "MT Test", "fr" => "MT Test" }
    )
  end

  let(:step_id) { participatory_process.steps.first.id }

  around do |example|
    previous_minimalistic = Decidim::Voca.configuration.enable_minimalistic_deepl
    previous_deepl_key = ENV.fetch("DECIDIM_DEEPL_API_KEY", nil)
    Decidim::Voca.configure { |c| c.enable_minimalistic_deepl = true }
    ENV["DECIDIM_DEEPL_API_KEY"] = "test-key"
    clear_enqueued_jobs
    user
    login_as user, scope: :user

    I18n.with_locale(organization.default_locale.to_sym) do
      example.run
    end

    Decidim::Voca.configure { |c| c.enable_minimalistic_deepl = previous_minimalistic }
    if previous_deepl_key
      ENV["DECIDIM_DEEPL_API_KEY"] = previous_deepl_key
    else
      ENV.delete("DECIDIM_DEEPL_API_KEY")
    end
  end

  before { stub_dummy_machine_translator }

  it "persists machine translations for the default-locale name" do
    switch_to_host(organization.host)

    perform_enqueued_jobs do
      visit decidim_admin_participatory_processes.components_path(participatory_process)

      find("button[data-toggle=add-component-dropdown]").click

      within "#add-component-dropdown" do
        find(".dummy").click
      end

      expect(page).to have_no_content("Share tokens")

      within ".item__edit-form .new_component" do
        # VOCA hides .tabs under [data-machine-translated]; Decidim helpers click those tabs — reveal them in test only.
        page.execute_script(<<~JS)
          document.querySelectorAll('[data-machine-translated="true"] .tabs.tabs--lang').forEach(function(el) {
            el.style.setProperty("display", "block", "important");
          });
        JS

        fill_in_i18n(
          :component_name,
          "#component-name-tabs",
          en: "Bonjour"
        )

        within ".global-settings" do
          fill_in_i18n_editor(
            :component_settings_dummy_global_translatable_text,
            "#global-settings-dummy_global_translatable_text-tabs",
            en: "Dummy Text"
          )
          all("input[type=checkbox]").last.click
        end

        within "#panel-step_settings" do
          fill_in_i18n_editor(
            "component_step_settings_#{step_id}_dummy_step_translatable_text",
            "#step-#{step_id}-settings-dummy_step_translatable_text-tabs",
            en: "Dummy Text for Step"
          )
          all("input[type=checkbox]").first.click
        end

        click_on "Add component"
      end

      expect(page).to have_admin_callout("successfully")
    end

    component = participatory_process.reload.components.order(:id).last
    expect(component).to be_present
    expect_dummy_machine_translation_for_field(component, :name, "fr", "Bonjour")
  end
end
