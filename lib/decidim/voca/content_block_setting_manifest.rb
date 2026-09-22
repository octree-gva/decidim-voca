# frozen_string_literal: true

module Decidim
  module Voca
    # Introspection for content-block settings marked +translated: true+ in the manifest.
    module ContentBlockSettingManifest
      module_function

      def translated_keys(manifest)
        return [] if manifest.blank?
        return [] unless manifest.respond_to?(:settings)
        return [] unless manifest.respond_to?(:has_settings?) && manifest.has_settings?

        manifest.settings.attributes.each_with_object([]) do |(name, attr), memo|
          memo << name.to_s if attr.translated?
        end
      end

      # Seeds/admin often store flat +welcome_text_en+ keys (alone or mixed with nested).
      # Always merge flat locale keys into the nested hash used by MT.
      def coalesce_flat_keys!(settings, keys, locales)
        return settings unless settings.is_a?(Hash)

        keys.each do |key|
          nested = settings[key].is_a?(Hash) ? settings[key].deep_stringify_keys : {}
          locales.each do |loc|
            flat = "#{key}_#{loc}"
            next unless settings.has_key?(flat)

            nested[loc.to_s] = settings.delete(flat)
          end
          settings[key] = nested if nested.any?
        end
        settings
      end

      # Decidim content-block JSONB is flat (+welcome_text_fr+). Expand nested (+machine_translations+)
      # back to flat keys so HeroCell/admin schema resolve locale values.
      def expand_to_flat_keys!(settings, keys)
        return settings unless settings.is_a?(Hash)

        keys.each { |key| expand_one_key_to_flat!(settings, key) }
        settings
      end

      def expand_one_key_to_flat!(settings, key)
        nested = settings.delete(key)
        return unless nested.is_a?(Hash)

        nested = nested.deep_stringify_keys
        mt = nested.delete("machine_translations")
        nested.each do |loc, val|
          next if loc.blank?

          settings["#{key}_#{loc}"] = val
        end
        return unless mt.is_a?(Hash)

        mt.deep_stringify_keys.each do |loc, val|
          next if loc.blank? || val.blank?

          settings["#{key}_#{loc}"] = val
        end
      end
    end
  end
end
