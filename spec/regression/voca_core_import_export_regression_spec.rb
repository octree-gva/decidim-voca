# frozen_string_literal: true

require "spec_helper"
require "csv"
require "decidim/proposals/test/factories"

# Core parity after MERGEABLE_FIELD_REGISTRY: proposal import still works; ProposalSerializer CSV shape stable.
RSpec.describe "VOCA Core import/export regression", :regression do
  before do
    allow(Decidim::Voca::Installation).to receive(:deepl_enabled?).and_return(true)
    Decidim::Voca::DeepL::EngineConfig.apply_mergeable_fields!
    Decidim::Voca::DeepL::EngineConfig.send(:fix_accountability_timeline_entry_translatable_fields!)
  end

  def csv_headers_and_first_row(collection, serializer)
    export = Decidim::Exporters::CSV.new(collection, serializer).export
    sep = Decidim.default_csv_col_sep
    lines = export.read.lines
    headers = CSV.parse_line(lines.first.strip, col_sep: sep)
    row = lines[1] && CSV.parse_line(lines[1].strip, col_sep: sep)
    [headers, row ? headers.zip(row).to_h : {}]
  end

  describe "Decidim::Proposals::Admin::ImportProposals" do
    let!(:organization) { create(:organization) }
    let!(:proposal_component) { create(:proposal_component, organization:) }
    let!(:source_proposal) { create(:proposal, :accepted, component: proposal_component) }
    let!(:current_component) do
      create(
        :proposal_component,
        participatory_space: proposal_component.participatory_space,
        organization:
      )
    end

    let(:form) do
      instance_double(
        Decidim::Proposals::Admin::ProposalsImportForm,
        origin_component: proposal_component,
        current_component:,
        current_organization: organization,
        keep_authors: false,
        keep_answers: false,
        states: ["accepted"],
        scopes: [],
        scope_ids: [],
        current_user: create(:user, organization:),
        valid?: true,
        as_json: {
          "origin_component_id" => proposal_component.id,
          "states" => ["accepted"],
          "keep_authors" => false,
          "keep_answers" => false,
          "scopes" => []
        }
      )
    end

    it "imports proposals without invalidating merged translatable fields" do
      command = Decidim::Proposals::Admin::ImportProposals.new(form)
      expect do
        perform_enqueued_jobs { command.call }
      end.to change { Decidim::Proposals::Proposal.where(component: current_component).count }.by(1)

      imported = Decidim::Proposals::Proposal.where(component: current_component).last
      expect(imported).to be_valid
      expect(imported.title).to eq(source_proposal.title)
      expect(imported.body).to eq(source_proposal.body)
    end
  end

  describe "Decidim::Proposals::ProposalSerializer CSV export" do
    let(:organization) do
      create(
        :organization,
        host: "#{SecureRandom.hex(8)}.example.org",
        available_locales: %w(en fr es ar),
        default_locale: "en"
      )
    end
    let(:component) { create(:proposal_component, organization:) }
    let(:proposal) do
      create(
        :proposal,
        :participant_author,
        component:,
        title: { "ar" => "Arabic title" },
        body: {
          "ar" => "<p>Arabic body</p>",
          "machine_translations" => { "en" => "<p>MT English body</p>" }
        },
        answer: { "en" => "Official EN", "fr" => "Official FR" }
      )
    end

    it "keeps locale-first columns and locale column for participant-authored rows" do
      headers, row = csv_headers_and_first_row([proposal], Decidim::Proposals::ProposalSerializer)

      expect(headers).to include("en/body", "fr/body", "es/body", "ar/body", "en/title", "locale")
      expect(row["locale"]).to eq("ar")
      expect(row["en/body"]).to include("MT English body")
      expect(row["ar/body"]).to include("Arabic body")
      expect(row["fr/title"]).to eq("")
    end
  end
end
