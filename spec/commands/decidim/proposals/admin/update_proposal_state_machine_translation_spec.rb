# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../support/shared_examples/machine_translation_update_shared_examples"

RSpec.describe Decidim::Proposals::Admin::UpdateProposalState, "machine translations" do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:component) { create(:proposal_component, organization:) }
  let(:current_user) { create(:user, :admin, :confirmed, organization:) }

  let(:create_form) do
    Decidim::Proposals::Admin::ProposalStateForm
      .from_params(
        {
          proposal_state: {
            title: { en: "State label" },
            announcement_title: { en: "Announcement v1" },
            bg_color: "#F3F4F7",
            text_color: "#3E4C5C"
          }
        }
      )
      .with_context(
        current_user:,
        current_organization: organization,
        current_participatory_space: component.participatory_space,
        current_component: component
      )
  end

  let(:state) { Decidim::Proposals::ProposalState.order(:id).last! }

  let(:update_form) do
    Decidim::Proposals::Admin::ProposalStateForm
      .from_params(
        {
          proposal_state: {
            title: state.reload.title,
            announcement_title: { en: "Announcement v2" },
            bg_color: state.bg_color,
            text_color: state.text_color
          }
        }
      )
      .with_context(
        current_user:,
        current_organization: organization,
        current_participatory_space: component.participatory_space,
        current_component: component
      )
  end

  let(:machine_translation_subject) { state }
  let(:machine_translation_field) { :announcement_title }
  let(:machine_translation_target_locale) { "fr" }
  let(:machine_translation_initial_source_text) { "Announcement v1" }
  let(:machine_translation_updated_source_text) { "Announcement v2" }

  def perform_create_with_machine_translation
    -> { expect { Decidim::Proposals::Admin::CreateProposalState.new(create_form).call }.to broadcast(:ok) }
  end

  def perform_update_with_machine_translation
    lambda do
      expect do
        Decidim::Proposals::Admin::UpdateProposalState.new(update_form, state.reload).call
      end.to broadcast(:ok)
    end
  end

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it_behaves_like "refreshes dummy machine translation when default locale source changes"
end
