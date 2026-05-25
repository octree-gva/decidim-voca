# frozen_string_literal: true

require "csv"
require "spec_helper"
require "decidim/comments/test/factories"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "participant-authored locale flow" do
  def csv_headers_and_first_row(collection, serializer)
    export = Decidim::Exporters::CSV.new(collection, serializer).export
    headers = CSV.parse_line(export.read.lines.first.strip, col_sep: Decidim.default_csv_col_sep)
    row = CSV.parse_line(export.read.lines.second.strip, col_sep: Decidim.default_csv_col_sep)
    headers.zip(row).to_h
  end

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr),
      default_locale: "en",
      enable_machine_translations: true
    )
  end
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }

  before do
    stub_dummy_machine_translator
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
    allow(Decidim.config).to receive(:machine_translation_delay).and_return(0.seconds)
    clear_enqueued_jobs
  end

  def create_translated_content
    proposal = nil
    comment = nil
    perform_enqueued_jobs do
      proposal = create(
        :proposal,
        :participant_author,
        component:,
        title: { "fr" => "Titre citoyen" },
        body: { "fr" => "<p>Contenu citoyen</p>" }
      )
      comment = create(:comment, commentable: proposal, body: { "fr" => "Un commentaire" })
    end
    [proposal.reload, comment.reload]
  end

  it "keeps participant locale metadata and exports translated proposal and comment content" do
    proposal, comment = create_translated_content
    proposal_row = csv_headers_and_first_row([proposal], Decidim::Proposals::ProposalSerializer)
    comment_row = csv_headers_and_first_row([comment], Decidim::Comments::CommentSerializer)

    expect(proposal.title.dig("machine_translations", "en")).to eq("en - Titre citoyen")
    expect(proposal.body.dig("machine_translations", "en")).to include("en - Contenu citoyen")
    expect(comment.body.dig("machine_translations", "en")).to eq("en - Un commentaire")
    expect(proposal_row["locale"]).to eq("fr")
    expect(proposal_row["fr/body"]).to include("Contenu citoyen")
    expect(proposal_row["en/body"]).to include("en - Contenu citoyen")
    expect(comment_row["locale"]).to eq("fr")
    expect(comment_row["fr/body"]).to eq("Un commentaire")
    expect(comment_row["en/body"]).to eq("en - Un commentaire")
  end
end
# rubocop:enable RSpec/DescribeClass
