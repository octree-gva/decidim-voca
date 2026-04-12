# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/shared_examples/machine_translation_shared_examples"

RSpec.describe Decidim::Admin::CreateStaticPage, "machine translations" do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end

  let(:user) { create(:user, :admin, :confirmed, organization:) }

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  context "when creating" do
    let(:slug) { "mt-static-page-#{SecureRandom.hex(4)}" }

    let(:form) do
      Decidim::Admin::StaticPageForm
        .from_params(
          {
            static_page: {
              slug:,
              title: { en: "Hello Page" },
              content: { en: "<p>#{SecureRandom.hex(32)}</p>" },
              allow_public_access: false,
              weight: 0
            }
          }
        )
        .with_context(current_user: user, current_organization: organization)
    end

    let(:command) { described_class.new(form) }

    let(:machine_translation_subject) { Decidim::StaticPage.find_by!(organization:, slug:) }
    let(:machine_translation_field) { :title }
    let(:machine_translation_target_locale) { "fr" }
    let(:machine_translation_source_text) { "Hello Page" }
    let(:perform_machine_translation_save) { -> { command.call } }

    it_behaves_like "persists dummy machine translations for field"

    it "re-runs machine translation after UpdateStaticPage changes the default locale title" do
      perform_with_machine_translation_jobs do
        expect { command.call }.to broadcast(:ok)
      end

      static_page = Decidim::StaticPage.find_by!(organization:, slug:)
      expect_dummy_machine_translation_for_field(static_page, :title, "fr", "Hello Page")

      p = static_page.reload
      update_form = Decidim::Admin::StaticPageForm.from_model(p).with_context(
        current_user: user,
        current_organization: organization
      )
      update_form.title_en = "Hello Page updated"

      perform_with_machine_translation_jobs do
        expect { Decidim::Admin::UpdateStaticPage.new(update_form, p).call }.to broadcast(:ok)
      end

      expect_dummy_machine_translation_for_field(static_page.reload, :title, "fr", "Hello Page updated")
    end
  end
end
