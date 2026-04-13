# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Proposals::Admin::CreateProposalState, "machine translations (announcement_title)" do
  subject(:command) { described_class.new(form) }

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(4)}.lvh.me",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:component) { create(:proposal_component, organization:) }
  let(:current_user) { create(:user, :admin, :confirmed, organization:) }

  let(:form) do
    Decidim::Proposals::Admin::ProposalStateForm
      .from_params(
        {
          proposal_state: {
            title: { en: "State label" },
            announcement_title: { en: "Announcement banner text" },
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

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "machine-translates announcement_title on creation" do
    perform_with_machine_translation_jobs do
      expect { command.call }.to broadcast(:ok)
    end

    state = Decidim::Proposals::ProposalState.order(:id).last!
    expect_dummy_machine_translation_for_field(state, :announcement_title, "fr", "Announcement banner text")
  end
end
