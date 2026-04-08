# frozen_string_literal: true

require "spec_helper"
require "decidim/budgets/test/factories"

RSpec.describe Decidim::Budgets::Admin::CreateBudget, "machine translations" do
  subject(:command) { described_class.new(form) }

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

  let(:form) do
    Decidim::Budgets::Admin::BudgetForm
      .from_params(
        {
          budget: {
            title: { en: "Budget MT title" },
            description: { en: "<p>Budget MT body</p>" },
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

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "machine-translates budget title on creation" do
    perform_with_machine_translation_jobs do
      expect { command.call }.to broadcast(:ok)
    end

    budget = Decidim::Budgets::Budget.order(:id).last!
    expect_dummy_machine_translation_for_field(budget, :title, "fr", "Budget MT title")
  end
end
