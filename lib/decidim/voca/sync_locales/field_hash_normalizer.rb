# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Pure transforms for translatable JSON hashes: rules 3 → 2 → 4 → 5 → 3 (top-level).
      class FieldHashNormalizer
        class << self
          def call(field_hash, context)
            new(context).normalize(field_hash)
          end

          # Deep stringify keys
          # Example: `[{fr: "Bonjour"}]` -> `[{"fr": "Bonjour"}]`
          def deep_stringify(obj)
            case obj
            when Hash
              obj.each_with_object({}) { |(k, v), acc| acc[k.to_s] = deep_stringify(v) }
            when Array
              obj.map { |e| deep_stringify(e) }
            else
              obj
            end
          end
        end

        def initialize(context)
          @context = context
        end

        def normalize(field_hash)
          return field_hash unless field_hash.is_a?(Hash)

          locale_hash = FieldHashNormalizer.deep_stringify(field_hash).deep_dup
          allowed = @context.allowed_locales
          default = @context.default_locale

          raw_mt = locale_hash.delete("machine_translations")
          mt_hash = raw_mt.is_a?(Hash) ? FieldHashNormalizer.deep_stringify(raw_mt) : {}

          prune_mt_keys_not_in_allowed!(mt_hash, allowed)
          promote_default_from_mt_to_root!(locale_hash, mt_hash, default)
          strip_default_from_mt!(mt_hash, default)
          move_non_default_roots_to_mt!(locale_hash, mt_hash, allowed, default)
          prune_top_level_keys_not_in_allowed!(locale_hash, allowed)

          locale_hash["machine_translations"] = mt_hash if mt_hash.present?

          locale_hash
        end

        private

        # Remove machine translation keys that are not in allowed locales
        def prune_mt_keys_not_in_allowed!(mt_hash, allowed_locales)
          mt_hash.keys.each do |key|
            mt_hash.delete(key) unless allowed_locales.include?(key)
          end
        end

        # If default locale is not human-filled but exists in machine translations, promote it to the root
        def promote_default_from_mt_to_root!(locale_hash, mt_hash, default_locale)
          return if locale_hash[default_locale].present?

          promoted = mt_hash.delete(default_locale)
          return if promoted.blank?

          locale_hash[default_locale] = promoted
        end

        # Never machine-translate default locale
        def strip_default_from_mt!(mt_hash, default_locale)
          mt_hash.delete(default_locale)
        end

        # All non-default locales must be machine-translated
        def move_non_default_roots_to_mt!(locale_hash, mt_hash, allowed_locales, default_locale)
          allowed_locales.each do |locale|
            next if locale == default_locale

            val = locale_hash[locale]
            next if val.blank?

            mt_hash[locale] = val
            locale_hash[locale] = ""
          end
        end

        # Remove top-level keys that are not in allowed locales
        def prune_top_level_keys_not_in_allowed!(locale_hash, allowed_locales)
          locale_hash.keys.each do |key|
            locale_hash.delete(key) unless allowed_locales.include?(key)
          end
        end
      end
    end
  end
end
