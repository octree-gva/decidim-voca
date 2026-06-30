# frozen_string_literal: true

require "spec_helper"

module Decidim::Admin
  describe "CreateComponent with machine translations" do
    subject(:command) { Decidim::Admin::CreateComponent.new(form) }

    let(:organization) do
      create(
        :organization,
        host: "#{SecureRandom.hex(4)}.lvh.me",
        available_locales: %w(en fr),
        default_locale: "en",
        enable_machine_translations: true
      )
    end
    let(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
    let(:step) { participatory_process.steps.first }
    let(:manifest) { Decidim.find_component_manifest(:dummy) }
    let(:current_user) { create(:user, organization:) }

    let(:form) do
      instance_double(
        ComponentForm,
        name: { en: "My component" },
        invalid?: false,
        valid?: true,
        current_user:,
        weight: 2,
        manifest:,
        participatory_space: participatory_process,
        settings: {},
        default_step_settings: { step.id.to_s => {} },
        step_settings: { step.id.to_s => {} }
      )
    end

    before do
      stub_dummy_machine_translator
      clear_enqueued_jobs
    end

    it "machine-translates component name on creation" do
      perform_with_machine_translation_jobs do
        expect { command.call }.to broadcast(:ok)
      end

      component = participatory_process.components.first
      expect(component).to be_present

      expect_dummy_machine_translation_for_field(component, :name, "fr", "My component")
    end

    context "when minimalistic Deepl is on and I18n.locale is not the organization default" do
      before { allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true) }

      let(:form) do
        instance_double(
          ComponentForm,
          name: { "en" => "My component", "fr" => "" },
          invalid?: false,
          valid?: true,
          current_user:,
          weight: 2,
          manifest:,
          participatory_space: participatory_process,
          settings: {},
          default_step_settings: { step.id.to_s => {} },
          step_settings: { step.id.to_s => {} }
        )
      end

      it "still uses default locale text as the machine translation source" do
        I18n.with_locale(:fr) do
          perform_with_machine_translation_jobs do
            expect { command.call }.to broadcast(:ok)
          end
        end

        component = participatory_process.components.first
        expect_dummy_machine_translation_for_field(component, :name, "fr", "My component")
      end
    end
  end
end
