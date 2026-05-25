# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::ComponentTranslatedSettingsMachineTranslation do
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

  it "enqueues MachineTranslateComponentSettingJob when default locale of a translated setting changes" do
    inner = component.read_attribute(:settings)["global"].deep_dup.deep_stringify_keys
    inner["dummy_global_translatable_text"] = { "en" => "first" }
    # rubocop:disable Rails/SkipsModelValidations -- bypass validations to set nested settings fixture
    component.update_column(:settings, { "global" => inner })
    # rubocop:enable Rails/SkipsModelValidations

    inner2 = component.reload.read_attribute(:settings)["global"].deep_dup.deep_stringify_keys
    inner2["dummy_global_translatable_text"] = { "en" => "second" }

    expect do
      component.assign_attributes(settings: inner2)
      component.save!(validate: false)
    end.to have_enqueued_job(Decidim::Voca::MachineTranslateComponentSettingJob).with(
      component.id,
      "dummy_global_translatable_text",
      "fr",
      "en",
      html: true
    )
  end

  it "does not enqueue when machine translation service is unset" do
    allow(Decidim).to receive(:machine_translation_service_klass).and_return(nil)
    inner = component.read_attribute(:settings)["global"].deep_dup.deep_stringify_keys
    inner["dummy_global_translatable_text"] = { "en" => "first" }
    # rubocop:disable Rails/SkipsModelValidations -- bypass validations to set nested settings fixture
    component.update_column(:settings, { "global" => inner })
    # rubocop:enable Rails/SkipsModelValidations

    inner2 = component.reload.read_attribute(:settings)["global"].deep_dup.deep_stringify_keys
    inner2["dummy_global_translatable_text"] = { "en" => "second" }

    expect do
      component.assign_attributes(settings: inner2)
      component.save!(validate: false)
    end.not_to have_enqueued_job(Decidim::Voca::MachineTranslateComponentSettingJob)
  end
end
