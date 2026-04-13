# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/shared_examples/machine_translation_shared_examples"

RSpec.describe Decidim::Admin::CreateStaticPageTopic, "machine translations" do
  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(4)}.lvh.me",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end

  let(:user) { create(:user, :admin, :confirmed, organization:) }

  let(:form) do
    Decidim::Admin::StaticPageTopicForm
      .from_params(
        {
          static_page_topic: {
            title: { en: "Hello Topic" },
            description: { en: "Topic description" },
            show_in_footer: true,
            weight: 0
          }
        }
      )
      .with_context(current_user: user, current_organization: organization)
  end

  let(:command) { described_class.new(form) }

  let(:machine_translation_subject) { organization.static_page_topics.order(:id).last! }
  let(:machine_translation_field) { :title }
  let(:machine_translation_target_locale) { "fr" }
  let(:machine_translation_source_text) { "Hello Topic" }
  let(:perform_machine_translation_save) { -> { command.call } }

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it_behaves_like "persists dummy machine translations for field"
end
