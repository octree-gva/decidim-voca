# frozen_string_literal: true

require_relative "../overrides/proposal_serializer_overrides"

module Decidim
  module Voca
    module Export
      # Prepended on ProposalSerializer: locale-first CSV columns and +locale+ from human slots.
      module ProposalSerializerLocalizedCsv
        include Decidim::Voca::Overrides::ProposalSerializerOverrides

        def serialize
          data = super
          serialize_localized_data(data)
        end

        private

        def serialize_localized_data(data)
          org = proposal.organization
          locales = Array(org.available_locales).map(&:to_s).uniq.compact_blank
          return data if locales.empty?

          nested = CsvWithLocaleTransformer.columns_for_locales(
            locales,
            "title" => proposal.title,
            "body" => proposal.body,
            "answer" => proposal.answer
          )
          nested.each_value do |inner|
            inner["body"] = plain_export_cell(inner["body"])
            inner["answer"] = plain_export_cell(inner["answer"])
          end
          submission = CsvWithLocaleTransformer.human_source_locale_from(proposal.body).presence ||
                       org.default_locale.to_s
          fields_without_translatables = data.except(:title, :body, :answer)
          locale_prefixed_columns = nested.deep_stringify_keys
          fields_without_translatables.merge(locale_prefixed_columns).merge(locale: submission)
        end

        def plain_export_cell(str)
          return "" if str.blank?

          convert_to_plain_text({ "_" => str })["_"].to_s
        end
      end
    end
  end
end
