# frozen_string_literal: true

module Decidim
  module Voca
    # Which locales still need machine translation for a nested translatable settings hash.
    module ComponentSettingPendingLocales
      module_function

      def for(field_hash, organization)
        default = organization.default_locale.to_s
        gaps(field_hash, organization).reject do |locale|
          machine_translated?(field_hash, locale, default)
        end
      end

      # Locales that lack a human top-level value (or, in minimalistic mode, all non-default locales).
      def gaps(field_hash, organization)
        return [] unless field_hash.is_a?(Hash)

        allowed = organization.available_locales.map(&:to_s)
        default = organization.default_locale.to_s
        fh = field_hash.stringify_keys

        if minimalistic?(organization)
          return [] if fh[default].blank?

          allowed - [default]
        else
          human = fh.except("machine_translations").each_with_object([]) do |(loc, val), memo|
            memo << loc if val.present?
          end
          allowed - human
        end
      end

      # +default_locale+: when MT text equals the default source, treat as not translated
      # (admin often pasted the default string into other locale slots).
      def machine_translated?(field_hash, locale, default_locale = nil)
        return false unless field_hash.is_a?(Hash)

        fh = field_hash.stringify_keys
        mt = fh["machine_translations"]
        return false unless mt.is_a?(Hash)

        value = mt.stringify_keys[locale.to_s]
        return false if value.blank?
        return false if copy_of_default_source?(fh, value, default_locale)

        true
      end

      def copy_of_default_source?(field_hash, value, default_locale)
        return false if default_locale.blank?

        source = field_hash[default_locale.to_s]
        source.present? && value == source
      end

      def minimalistic?(organization)
        Decidim::Voca.minimalistic_deepl? && organization.enable_machine_translations?
      end
    end
  end
end
