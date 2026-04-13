# frozen_string_literal: true

require "csv"
require "spec_helper"
require "decidim/comments/test/factories"
require "decidim/forms/test/factories"
require "decidim/surveys/test/factories"

RSpec.describe Decidim::Voca::Export do
  def csv_headers_and_first_row(collection, serializer)
    export = Decidim::Exporters::CSV.new(collection, serializer).export
    sep = Decidim.default_csv_col_sep
    lines = export.read.lines
    headers = CSV.parse_line(lines.first.strip, col_sep: sep)
    row = lines[1] && CSV.parse_line(lines[1].strip, col_sep: sep)
    [headers, row ? headers.zip(row).to_h : {}]
  end

  describe Decidim::Proposals::ProposalSerializer do
    let(:organization) do
      create(
        :organization,
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

    it "produces locale-first columns and a locale submission column" do
      serializer = Decidim::Proposals::ProposalSerializer
      headers, row = csv_headers_and_first_row([proposal], serializer)

      expect(headers).to include("en/body", "fr/body", "es/body", "ar/body", "en/title", "locale")
      expect(row["locale"]).to eq("ar")
      expect(row["en/body"]).to include("MT English body")
      expect(row["ar/body"]).to include("Arabic body")
      expect(row["fr/title"]).to eq("")
    end
  end

  describe Decidim::Comments::CommentSerializer do
    let(:organization) do
      create(
        :organization,
        available_locales: %w(en fr),
        default_locale: "en"
      )
    end
    let(:component) { create(:proposal_component, organization:) }
    let(:proposal) { create(:proposal, component:) }
    let(:comment) do
      create(
        :comment,
        commentable: proposal,
        body: { "fr" => "Un commentaire" }
      )
    end

    it "exposes per-locale body columns and submission locale" do
      serializer = Decidim::Comments::CommentSerializer
      headers, row = csv_headers_and_first_row([comment], serializer)

      expect(headers).to include("en/body", "fr/body", "locale")
      expect(row["fr/body"]).to eq("Un commentaire")
      expect(row["en/body"]).to eq("")
      expect(row["locale"]).to eq("fr")
    end
  end

  describe Decidim::Forms::UserAnswersSerializer do
    let(:survey) { create(:survey, skip_injection: true) }
    let(:organization) { survey.component.organization }
    let(:questionnaire) { survey.questionnaire }
    let(:question) { questionnaire.questions.order(:position).first }
    let(:user) { create(:user, :admin, :confirmed, organization:, locale: "fr") }
    let!(:answer) do
      create(
        :answer,
        questionnaire:,
        question:,
        user:,
        body: "Participant reply",
        skip_injection: true
      )
    end

    before do
      organization.update!(available_locales: %w(en fr), default_locale: "en")
    end

    it "uses stable q_<id> keys per locale and a locale column" do
      serializer = Decidim::Forms::UserAnswersSerializer
      headers, row = csv_headers_and_first_row([[answer]], serializer)

      qkey = "q_#{question.id}"
      expect(headers).to include("en/#{qkey}", "fr/#{qkey}", "locale")
      expect(row["en/#{qkey}"]).to eq("Participant reply")
      expect(row["fr/#{qkey}"]).to eq("Participant reply")
      expect(row["locale"]).to eq("en")
    end
  end
end
