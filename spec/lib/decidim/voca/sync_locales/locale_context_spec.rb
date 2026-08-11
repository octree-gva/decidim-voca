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

      it "resolves via unscoped component when association raises RecordNotFound" do
        process = create(:participatory_process, organization:)
        component = create(:proposal_component, participatory_space: process)
        state = create(:proposal_state, component:)

        allow(state).to receive(:organization).and_raise(ActiveRecord::RecordNotFound)
        allow(state).to receive(:component).and_raise(ActiveRecord::RecordNotFound)

        context = described_class.for(state)

        expect(context.organization).to eq(organization)
      end

      it "resolves AnswerChoice via answer questionnaire" do
        process = create(:participatory_process, organization:)
        questionnaire = create(:questionnaire, questionnaire_for: process)
        question = create(:questionnaire_question, questionnaire:, question_type: "single_option")
        answer_option = create(:answer_option, question:)
        answer = create(:answer, questionnaire:, question:)
        choice = create(:answer_choice, answer:, answer_option:)

        context = described_class.for(choice)

        expect(context.organization).to eq(organization)
      end

      it "resolves AgendaItem via agenda meeting" do
        process = create(:participatory_process, organization:)
        meeting_component = create(:meeting_component, participatory_space: process)
        meeting = create(:meeting, component: meeting_component)
        agenda = create(:agenda, meeting:)
        item = create(:agenda_item, agenda:)

        context = described_class.for(item)

        expect(context.organization).to eq(organization)
      end

      it "resolves questionnaire_for owners (e.g. Meetings questionnaire stand-in)" do
        process = create(:participatory_process, organization:)
        meeting_component = create(:meeting_component, participatory_space: process)
        meeting = create(:meeting, component: meeting_component)
        record = Struct.new(:questionnaire_for, :id).new(meeting, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves shapefile-backed geo rows via shapefile organization" do
        shapefile = Struct.new(:organization).new(organization)
        record = Struct.new(:decidim_geo_shapefiles_id, :id).new(42, 1)
        stub_const("Decidim::Geo::Shapefile", Class.new)
        allow(Decidim::Geo::Shapefile).to receive(:find_by).with(id: 42).and_return(shapefile)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves paper trail rows via item_type/item_id when item association is blank" do
        process = create(:participatory_process, organization:)
        component = create(:proposal_component, participatory_space: process)
        version = Struct.new(:item_type, :item_id, :item, :object, :id).new(
          "Decidim::Component",
          component.id,
          nil,
          nil,
          1
        )

        context = described_class.for(version)

        expect(context.organization).to eq(organization)
      end

      it "resolves ResponseChoice-like rows via response questionnaire" do
        process = create(:participatory_process, organization:)
        questionnaire = create(:questionnaire, questionnaire_for: process)
        question = create(:questionnaire_question, questionnaire:, question_type: "single_option")
        answer = create(:answer, questionnaire:, question:)
        record = Struct.new(:response, :id).new(answer, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves election children via election component" do
        process = create(:participatory_process, organization:)
        component = create(:component, participatory_space: process)
        election = Struct.new(:organization, :component, :id).new(nil, component, 1)
        record = Struct.new(:election, :id).new(election, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves taxonomy-backed rows via taxonomy organization" do
        taxonomy = Struct.new(:organization).new(organization)
        record = Struct.new(:taxonomy, :id).new(taxonomy, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves vote-backed rows via proposal" do
        process = create(:participatory_process, organization:)
        component = create(:proposal_component, participatory_space: process)
        proposal = create(:proposal, component:)
        vote = Struct.new(:proposal, :id).new(proposal, 1)
        record = Struct.new(:vote, :id).new(vote, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves translation sets via constraints organization" do
        constraint = Struct.new(:organization).new(organization)
        translation_set = Struct.new(:constraints, :id).new([constraint], 1)

        context = described_class.for(translation_set)

        expect(context.organization).to eq(organization)
      end

      it "resolves participatory_process association" do
        process = create(:participatory_process, organization:)
        record = Struct.new(:participatory_process, :id).new(process, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves api_client association" do
        client = Struct.new(:organization).new(organization)
        record = Struct.new(:api_client, :id).new(client, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves geo shapefile datas via decidim_geo_shapefiles_id when scope is blank" do
        shapefile = Struct.new(:organization, :decidim_organization_id).new(organization, organization.id)
        record = Struct.new(:organization, :decidim_geo_shapefiles_id, :id).new(nil, 99, 1)
        stub_const("Decidim::Geo::Shapefile", Class.new)
        allow(Decidim::Geo::Shapefile).to receive(:find_by).with(id: 99).and_return(shapefile)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves rows with organization_id (without decidim_ prefix)" do
        record = Struct.new(:organization_id, :id).new(organization.id, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves geo config-like rows via decidim_organization_id only" do
        record = Struct.new(:decidim_organization_id, :id).new(organization.id, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves spam_signal user_report_flow via flow" do
        flow = Struct.new(:organization).new(organization)
        record = Struct.new(:flow, :user_report, :id).new(flow, nil, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
      end

      it "resolves sortition-like decidim_proposals_component association" do
        process = create(:participatory_process, organization:)
        component = create(:proposal_component, participatory_space: process)
        record = Struct.new(:decidim_proposals_component, :id).new(component, 1)

        context = described_class.for(record)

        expect(context.organization).to eq(organization)
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
