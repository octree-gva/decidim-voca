# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/shared_examples/machine_translation_update_shared_examples"

RSpec.describe Decidim::Admin::UpdateComponent, "machine translations" do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
  let(:step) { participatory_process.steps.first }
  let(:manifest) { Decidim.find_component_manifest(:dummy) }
  let(:current_user) { create(:user, organization:) }

  let(:create_form) do
    instance_double(
      Decidim::Admin::ComponentForm,
      name: { en: "Component v1" },
      invalid?: false,
      valid?: true,
      current_user:,
      weight: 2,
      manifest:,
      participatory_space: participatory_process,
      settings: {},
      default_step_settings: { step.id.to_s => {} },
      step_settings: { step.id.to_s => {} }
    )
  end

  let(:component) { participatory_process.components.first }

  let(:update_form) do
    instance_double(
      Decidim::Admin::ComponentForm,
      name: { en: "Component v2" },
      invalid?: false,
      valid?: true,
      current_user:,
      weight: 3,
      manifest:,
      participatory_space: participatory_process,
      settings: {},
      default_step_settings: { step.id.to_s => {} },
      step_settings: { step.id.to_s => {} }
    )
  end

  let(:machine_translation_subject) { component }
  let(:machine_translation_field) { :name }
  let(:machine_translation_target_locale) { "fr" }
  let(:machine_translation_initial_source_text) { "Component v1" }
  let(:machine_translation_updated_source_text) { "Component v2" }

  def perform_create_with_machine_translation
    -> { Decidim::Admin::CreateComponent.new(create_form).call }
  end

  def perform_update_with_machine_translation
    lambda do
      expect do
        Decidim::Admin::UpdateComponent.new(update_form, component.reload).call
      end.to broadcast(:ok)
    end
  end

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it_behaves_like "refreshes dummy machine translation when default locale source changes"
end
