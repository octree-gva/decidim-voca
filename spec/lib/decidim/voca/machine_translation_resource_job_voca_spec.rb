# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::MachineTranslationResourceJobVoca do
  let(:organization) do
    create(
      :organization,
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:participatory_process) { create(:participatory_process, organization:) }

  let!(:component) do
    create(
      :component,
      participatory_space: participatory_process,
      name: { "en" => "Hello", "fr" => "noise-should-not-block" }
    )
  end

  let(:job) { Decidim::MachineTranslationResourceJob.new }

  before do
    clear_enqueued_jobs
    job.instance_variable_set(:@resource, component)
  end

  describe "#resource_field_value" do
    let(:previous_changes) do
      {
        "name" => [
          {},
          { "en" => "Hello", "fr" => "" }
        ]
      }
    end

    context "when minimalistic Deepl is on" do
      before { allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true) }

      it "reads the organization default locale slot even when source_locale is another UI locale" do
        job.instance_variable_set(:@resource, component)
        expect(job.resource_field_value(previous_changes, "name", "fr")).to eq("Hello")
      end
    end

    context "when minimalistic Deepl is off" do
      before { allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(false) }

      it "delegates to core and uses the passed source_locale for the hash lookup" do
        job.instance_variable_set(:@resource, component)
        expect(job.resource_field_value(previous_changes, "name", "fr")).to eq("")
      end
    end
  end

  describe "#translated_locales_list" do
    context "when minimalistic Deepl is on and organization has machine translations" do
      before { allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true) }

      it "treats only the default locale as blocking so other locales stay pending for MT" do
        expect(job.send(:translated_locales_list, "name")).to eq(["en"])
      end
    end

    context "when minimalistic Deepl is off" do
      before { allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(false) }

      it "delegates to core and lists every present locale" do
        expect(job.send(:translated_locales_list, "name")).to contain_exactly("en", "fr")
      end
    end
  end

  describe "perform" do
    let(:previous_changes) do
      {
        "name" => [
          { "en" => "Old", "fr" => "noise" },
          { "en" => "Hello", "fr" => "noise" }
        ]
      }
    end

    before do
      stub_dummy_machine_translator
      allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
      allow(Decidim.config).to receive(:machine_translation_delay).and_return(0.seconds)
      # rubocop:disable Rails/SkipsModelValidations -- fixture state without callbacks
      component.update_column(:name, { "en" => "Hello", "fr" => "noise" })
      # rubocop:enable Rails/SkipsModelValidations
      clear_enqueued_jobs
    end

    it "stores machine translation for fr from default-locale source despite non-default noise" do
      perform_enqueued_jobs do
        Decidim::MachineTranslationResourceJob.perform_now(component, previous_changes, "en")
      end

      component.reload
      expect(component.name.dig("machine_translations", "fr")).to eq("fr - Hello")
    end
  end
end
