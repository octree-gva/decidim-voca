# frozen_string_literal: true

require "spec_helper"

module Decidim::Voca::SyncLocales
  describe FieldHashNormalizer do
    def ctx(allowed:, default:, org: nil)
      LocaleContext.new(allowed_locales: allowed, default_locale: default, organization: org)
    end

    describe ".call" do
      it "Scenario 1: prunes invalid MT keys, strips default from MT, keeps en MT, enqueues path inputs" do
        input = {
          "fr" => "Bonjour",
          "en" => "",
          "machine_translations" => {
            "en" => "Hello (MT)",
            "fr" => "Bonjour (wrong MT copy)",
            "ca" => "legacy Catalan"
          }
        }
        context = ctx(allowed: %w(fr en), default: "fr")
        out = described_class.call(input, context)

        expect(out).to eq(
          {
            "fr" => "Bonjour",
            "en" => "",
            "machine_translations" => {
              "en" => "Hello (MT)"
            }
          }
        )
      end

      it "Scenario 2: promotes new default from MT, moves old default root text to MT" do
        input = {
          "fr" => "Texte canonique",
          "en" => "",
          "machine_translations" => {
            "en" => "Fresh Deepl translation of fr"
          }
        }
        context = ctx(allowed: %w(fr en), default: "en")
        out = described_class.call(input, context)

        expect(out).to eq(
          {
            "fr" => "",
            "en" => "Fresh Deepl translation of fr",
            "machine_translations" => {
              "fr" => "Texte canonique"
            }
          }
        )
      end

      it "Scenario 3: drops en keys and MT, leaves fr + empty MT bucket omitted" do
        input = {
          "fr" => "Salut",
          "en" => "Hi",
          "machine_translations" => {
            "en" => "Hi MT"
          }
        }
        context = ctx(allowed: %w(fr it), default: "fr")
        out = described_class.call(input, context)

        expect(out).to eq(
          {
            "fr" => "Salut"
          }
        )
      end
    end
  end
end
