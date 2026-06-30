# frozen_string_literal: true

module Decidim
  module Voca
    module Export
      # Pure helpers for locale-first CSV columns (+en/body+, +locale+, …) via
      # +Decidim::Exporters::CSV+ flattening.
      module CsvWithLocaleTransformer
        module_function

        # Visible string for +locale+ from a Decidim-style i18n (+machine_translations+) hash.
        def value_for_locale(field_hash, locale)
          return "" unless field_hash.is_a?(Hash)

          h = field_hash.stringify_keys
          loc = locale.to_s
          v = h[loc]
          return v.to_s if v.present?

          mt = h["machine_translations"]
          return mt[loc].to_s if mt.is_a?(Hash) && mt[loc].present?

          ""
        end

        # First top-level locale key with a non-blank human value (+machine_translations+ excluded).
        def human_source_locale_from(field_hash)
          return nil unless field_hash.is_a?(Hash)

          field_hash.stringify_keys.except("machine_translations").each do |loc, val|
            return loc if val.present?
          end
          nil
        end

        # @param locales [Array<String>]
        # @param fields [Hash<String, Hash>] field_name => translatable hash from the record
        # @return [Hash<String, Hash>] locale => { field_name => string }
        def columns_for_locales(locales, fields)
          locales = Array(locales).map(&:to_s).uniq.compact_blank
          out = {}
          locales.each do |loc|
            out[loc] = {}
            fields.each do |name, hash|
              out[loc][name.to_s] = value_for_locale(hash, loc)
            end
          end
          out
        end
      end
    end
  end
end
