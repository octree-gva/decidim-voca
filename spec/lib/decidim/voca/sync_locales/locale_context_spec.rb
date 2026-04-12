# frozen_string_literal: true

require "spec_helper"

module Decidim::Voca::SyncLocales
  describe LocaleContext do
    describe ".for" do
      it "uses the organization when the record has one" do
        organization = create(:organization, available_locales: %w(en fr), default_locale: "fr", enable_machine_translations: true)
        process = create(:participatory_process, organization:)
        component = create(:component, participatory_space: process)

        context = described_class.for(component)

        expect(context.allowed_locales).to eq(%w(en fr))
        expect(context.default_locale).to eq("fr")
        expect(context.organization).to eq(organization)
        expect(context.enable_machine_translations?).to be(true)
      end

      it "uses the organization record itself for Decidim::Organization" do
        organization = create(:organization, available_locales: %w(en fr uk), default_locale: "uk", enable_machine_translations: false)

        context = described_class.for(organization)

        expect(context.allowed_locales).to eq(%w(en fr uk))
        expect(context.default_locale).to eq("uk")
        expect(context.organization).to eq(organization)
        expect(context.enable_machine_translations?).to be(false)
      end

      it "uses participatory_space.organization when record.organization is absent" do
        organization = create(:organization, available_locales: %w(en fr), default_locale: "fr", enable_machine_translations: true)
        process = create(:participatory_process, organization:)
        proposal_component = create(:component, participatory_space: process)
        allow(proposal_component).to receive(:organization).and_return(nil)
        allow(proposal_component).to receive(:participatory_space).and_return(process)

        context = described_class.for(proposal_component)

        expect(context.organization).to eq(organization)
      end

      it "uses component.organization when organization and participatory_space yield nothing" do
        organization = create(:organization, available_locales: %w(en fr), default_locale: "fr", enable_machine_translations: true)
        process = create(:participatory_process, organization:)
        component = create(:proposal_component, participatory_space: process)
        proposal = create(:proposal, component:)

        allow(proposal).to receive(:organization).and_return(nil)
        allow(proposal).to receive(:participatory_space).and_return(nil)
        allow(proposal).to receive(:component).and_return(component)

        context = described_class.for(proposal)

        expect(context.organization).to eq(organization)
      end

      it "raises when organization cannot be resolved" do
        resource = Object.new

        expect { described_class.for(resource) }.to raise_error(MissingOrganizationContextError)
      end
    end
  end
end
