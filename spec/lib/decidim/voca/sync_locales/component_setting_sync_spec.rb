# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::SyncLocales::ComponentSettingSync do
  include ActiveJob::TestHelper

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
  let(:component) { create(:component, participatory_space: participatory_process) }

  before do
    stub_dummy_machine_translator
    clear_enqueued_jobs
  end

  it "enqueues MachineTranslateComponentSettingJob for pending locales" do
    inner = component.read_attribute(:settings)["global"].deep_dup.deep_stringify_keys
    inner["dummy_global_translatable_text"] = { "en" => "Hello" }
    # rubocop:disable Rails/SkipsModelValidations -- bypass validations to set nested settings fixture
    component.update_column(:settings, { "global" => inner })
    # rubocop:enable Rails/SkipsModelValidations

    expect do
      described_class.new(component).call
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateComponentSettingJob).with(
      component.id,
      "dummy_global_translatable_text",
      "fr",
      "en",
      html: true
    )
  end

  it "is a no-op for non-components" do
    expect do
      described_class.new(organization).call
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateComponentSettingJob)
  end
end
