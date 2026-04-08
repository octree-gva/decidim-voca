# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Admin::UpdateStaticPageTopic, "machine translations" do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end

  let(:user) { create(:user, :admin, :confirmed, organization:) }

  let(:create_form) do
    Decidim::Admin::StaticPageTopicForm
      .from_params(
        {
          static_page_topic: {
            title: { en: "Topic title v1" },
            description: { en: "Topic desc" },
            show_in_footer: true,
            weight: 0
          }
        }
      )
      .with_context(current_user: user, current_organization: organization)
  end

  let(:topic_record) { organization.static_page_topics.order(:id).last! }

  let(:update_form) do
    Decidim::Admin::StaticPageTopicForm
      .from_params(
        {
          static_page_topic: {
            title: { en: "Topic title v2" },
            description: topic_record.reload.description,
            show_in_footer: topic_record.show_in_footer,
            weight: topic_record.weight
          }
        }
      )
      .with_context(current_user: user, current_organization: organization)
  end

  let(:machine_translation_subject) { topic_record }
  let(:machine_translation_field) { :title }
  let(:machine_translation_target_locale) { "fr" }
  let(:machine_translation_initial_source_text) { "Topic title v1" }
  let(:machine_translation_updated_source_text) { "Topic title v2" }

  def perform_create_with_machine_translation
    -> { expect { Decidim::Admin::CreateStaticPageTopic.new(create_form).call }.to broadcast(:ok) }
  end

  def perform_update_with_machine_translation
    lambda do
      expect do
        Decidim::Admin::UpdateStaticPageTopic.new(update_form, topic_record.reload).call
      end.to broadcast(:ok)
    end
  end

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it_behaves_like "refreshes dummy machine translation when default locale source changes"
end
