# frozen_string_literal: true

require "spec_helper"
require "decidim/budgets/test/factories"
require_relative "../../../../support/shared_examples/machine_translation_update_shared_examples"

RSpec.describe Decidim::Budgets::Admin::UpdateBudget, "machine translations" do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:component) { create(:budgets_component, organization:) }
  let(:participatory_process) { component.participatory_space }
  let(:current_user) { create(:user, :admin, :confirmed, organization:) }

  let(:create_form) do
    Decidim::Budgets::Admin::BudgetForm
      .from_params(
        {
          budget: {
            title: { en: "Budget v1" },
            description: { en: "<p>Body v1</p>" },
            weight: 0,
            total_budget: 50_000
          }
        }
      )
      .with_context(
        current_user:,
        current_organization: organization,
        current_participatory_space: participatory_process,
        current_component: component
      )
  end

  let(:budget) { Decidim::Budgets::Budget.order(:id).last! }

  let(:update_form) do
    Decidim::Budgets::Admin::BudgetForm
      .from_params(
        {
          budget: {
            title: { en: "Budget v2" },
            description: budget.reload.description,
            weight: budget.weight,
            total_budget: budget.total_budget,
            decidim_scope_id: budget.decidim_scope_id
          }
        }
      )
      .with_context(
        current_user:,
        current_organization: organization,
        current_participatory_space: participatory_process,
        current_component: component
      )
  end

  let(:machine_translation_subject) { budget }
  let(:machine_translation_field) { :title }
  let(:machine_translation_target_locale) { "fr" }
  let(:machine_translation_initial_source_text) { "Budget v1" }
  let(:machine_translation_updated_source_text) { "Budget v2" }

  def perform_create_with_machine_translation
    -> { expect { Decidim::Budgets::Admin::CreateBudget.new(create_form).call }.to broadcast(:ok) }
  end

  def perform_update_with_machine_translation
    lambda do
      expect do
        Decidim::Budgets::Admin::UpdateBudget.new(update_form, budget.reload).call
      end.to broadcast(:ok)
    end
  end

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it_behaves_like "refreshes dummy machine translation when default locale source changes"
end
