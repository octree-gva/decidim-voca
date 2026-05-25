# frozen_string_literal: true

module Decidim
  module Voca
    module Export
      # Prepended on CommentSerializer for +locale/body+ columns and +locale+ from human slots.
      module CommentSerializerLocalizedCsv
        def serialize
          data = super
          serialize_localized_data(data)
        end

        private

        def serialize_localized_data(data)
          org = resource.organization
          locales = Array(org.available_locales).map(&:to_s).uniq.compact_blank
          return data if locales.empty?

          nested = {}
          locales.each do |loc|
            nested[loc] = { "body" => CsvWithLocaleTransformer.value_for_locale(resource.body, loc) }
          end
          submission = CsvWithLocaleTransformer.human_source_locale_from(resource.body).presence ||
                       data[:locale].to_s.presence ||
                       org.default_locale.to_s
          fields_without_body_and_locale = data.except(:body, :locale)
          locale_prefixed_columns = nested.deep_stringify_keys
          fields_without_body_and_locale.merge(locale_prefixed_columns).merge(locale: submission)
        end
      end
    end
  end
end
