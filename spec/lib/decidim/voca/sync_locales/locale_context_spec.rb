# frozen_string_literal: true

require "spec_helper"

module Decidim::Voca::SyncLocales
  describe LocaleContext do
    describe ".for" do
      let(:organization) do
        create(
          :organization,
          host: "#{SecureRandom.hex(4)}.lvh.me",
          available_locales: %w(en fr),
          default_locale: "fr",
          enable_machine_translations: true
        )
      end

      shared_examples "resolves organization context" do
        it "returns the organization context" do
          context = described_class.for(record)

          expect(context.allowed_locales).to eq(%w(en fr))
          expect(context.default_locale).to eq("fr")
          expect(context.organization).to eq(organization)
          expect(context.enable_machine_translations?).to be(true)
        end
      end

      it "uses the organization when the record has one" do
        process = create(:participatory_process, organization:)
        component = create(:component, participatory_space: process)

        context = described_class.for(component)

        expect(context.allowed_locales).to eq(%w(en fr))
        expect(context.default_locale).to eq("fr")
        expect(context.organization).to eq(organization)
        expect(context.enable_machine_translations?).to be(true)
      end

      it "uses the organization record itself for Decidim::Organization" do
        organization = create(
          :organization,
          host: "#{SecureRandom.hex(4)}.lvh.me",
          available_locales: %w(en fr uk),
          default_locale: "uk",
          enable_machine_translations: false
        )

        context = described_class.for(organization)

        expect(context.allowed_locales).to eq(%w(en fr uk))
        expect(context.default_locale).to eq("uk")
        expect(context.organization).to eq(organization)
        expect(context.enable_machine_translations?).to be(false)
      end

      it "uses participatory_space.organization when record.organization is absent" do
        process = create(:participatory_process, organization:)
        proposal_component = create(:component, participatory_space: process)
        allow(proposal_component).to receive(:organization).and_return(nil)
        allow(proposal_component).to receive(:participatory_space).and_return(process)

        context = described_class.for(proposal_component)

        expect(context.organization).to eq(organization)
      end

      it "uses component.organization when organization and participatory_space yield nothing" do
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

      context "with decidim-core records" do
        let(:process) { create(:participatory_process, organization:) }
        let(:accountability_component) { create(:accountability_component, participatory_space: process) }
        let(:proposal_component) { create(:proposal_component, participatory_space: process) }
        let(:questionnaire) { create(:questionnaire, questionnaire_for: process) }
        let(:question) { create(:questionnaire_question, questionnaire:) }
        let(:proposal) { create(:proposal, component: proposal_component) }
        let(:collaborative_draft) { create(:collaborative_draft, component: proposal_component) }

        context "when given Decidim::Accountability::Result" do
          let(:record) { create(:result, component: accountability_component) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Forms::QuestionMatrixRow" do
          let(:record) { create(:question_matrix_row, question:) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Forms::DisplayCondition" do
          let(:record) do
            conditioned_question = create(:questionnaire_question, questionnaire:, position: 1)
            create(:display_condition, question: conditioned_question, condition_question: question)
          end

          include_examples "resolves organization context"
        end

        context "when given Decidim::Forms::Questionnaire" do
          let(:record) { questionnaire }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Forms::Question" do
          let(:record) { question }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Accountability::TimelineEntry" do
          let(:record) { create(:timeline_entry, result: create(:result, component: accountability_component)) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Accountability::Status" do
          let(:record) { create(:status, component: accountability_component) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::CollaborativeDraftCollaboratorRequest" do
          let(:record) do
            Decidim::Proposals::CollaborativeDraftCollaboratorRequest.create!(
              collaborative_draft:,
              user: create(:user, organization:)
            )
          end

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::CollaborativeDraft" do
          let(:record) { collaborative_draft }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::ProposalNote" do
          let(:record) { create(:proposal_note, proposal:, author: create(:user, organization:)) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::ProposalState" do
          let(:record) { create(:proposal_state, component: proposal_component) }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::Proposal" do
          let(:record) { proposal }

          include_examples "resolves organization context"
        end

        context "when given Decidim::Proposals::ValuationAssignment" do
          let(:record) { create(:valuation_assignment, proposal:) }

          include_examples "resolves organization context"
        end
      end
    end
  end
end
