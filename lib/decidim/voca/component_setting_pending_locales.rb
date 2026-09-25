# frozen_string_literal: true

module Decidim
  module Voca
    # Which locales still need machine translation for a nested translatable settings hash.
    module ComponentSettingPendingLocales
      module_function

      def for(field_hash, organization)
        gaps(field_hash, organization).reject { |locale| machine_translated?(field_hash, locale) }
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

      def machine_translated?(field_hash, locale)
        return false unless field_hash.is_a?(Hash)

        mt = field_hash.stringify_keys["machine_translations"]
        return false unless mt.is_a?(Hash)

        mt.stringify_keys[locale.to_s].present?
      end

      def minimalistic?(organization)
        Decidim::Voca.minimalistic_deepl? && organization.enable_machine_translations?
      end
    end
  end
end
