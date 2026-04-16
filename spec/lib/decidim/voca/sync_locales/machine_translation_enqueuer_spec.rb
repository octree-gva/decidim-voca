# frozen_string_literal: true

require "spec_helper"

module Decidim::Voca::SyncLocales
  describe MachineTranslationEnqueuer do
    let(:organization) do
      create(
        :organization,
        host: "#{SecureRandom.hex(8)}.example.org",
        available_locales: %w(fr en),
        default_locale: "fr",
        enable_machine_translations: true
      )
    end
    let(:participatory_process) { create(:participatory_process, organization:) }
    let(:component) { create(:component, participatory_space: participatory_process) }
    let(:context) { LocaleContext.for(component) }

    before do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Voca::DeepL::MachineTranslator)
    end

    it "performs MachineTranslationFieldsJob with the configured delay and locales" do
      delay = 12.seconds
      allow(Decidim.config).to receive(:machine_translation_delay).and_return(delay)

      chain = instance_double(ActiveJob::ConfiguredJob)
      allow(Decidim::MachineTranslationFieldsJob).to receive(:set).with(wait: delay).and_return(chain)
      expect(chain).to receive(:perform_now).with(
        component,
        "name",
        "Bonjour",
        "en",
        "fr"
      )

      hash = {
        "fr" => "Bonjour",
        "en" => "",
        "machine_translations" => { "en" => "Hello (MT)" }
      }
      described_class.new(component, "name", context, hash).call
    end

    it "does nothing when machine translation service is disabled" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(nil)

      expect(Decidim::MachineTranslationFieldsJob).not_to receive(:set)

      hash = { "fr" => "x", "en" => "" }
      described_class.new(component, "name", context, hash).call
    end

    it "does nothing when the organization disables machine translations" do
      organization.update!(enable_machine_translations: false)

      expect(Decidim::MachineTranslationFieldsJob).not_to receive(:set)

      hash = { "fr" => "x", "en" => "" }
      described_class.new(component, "name", LocaleContext.for(component), hash).call
    end
  end
end
