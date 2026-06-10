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

    it "translates pending locales via MachineTranslator with organization context" do
      translator = instance_double(Decidim::Voca::DeepL::MachineTranslator)
      allow(Decidim::Voca::DeepL::MachineTranslator).to receive(:new).with(
        component,
        "name",
        "Bonjour",
        "en",
        "fr"
      ).and_return(translator)
      expect(Decidim::Voca::DeepL::Context).to receive(:with_organization).with(organization).and_yield
      expect(translator).to receive(:translate)

      hash = {
        "fr" => "Bonjour",
        "en" => "",
        "machine_translations" => { "en" => "Hello (MT)" }
      }
      described_class.new(component, "name", context, hash).call
    end

    it "does nothing when machine translation service is disabled" do
      allow(Decidim).to receive(:machine_translation_service_klass).and_return(nil)

      expect(Decidim::Voca::DeepL::MachineTranslator).not_to receive(:new)

      hash = { "fr" => "x", "en" => "" }
      described_class.new(component, "name", context, hash).call
    end

    it "does nothing when the organization disables machine translations" do
      organization.update!(enable_machine_translations: false)

      expect(Decidim::Voca::DeepL::MachineTranslator).not_to receive(:new)

      hash = { "fr" => "x", "en" => "" }
      described_class.new(component, "name", LocaleContext.for(component), hash).call
    end
  end
end
