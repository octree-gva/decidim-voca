# frozen_string_literal: true

module Decidim
  module Voca
    # Which locales still need machine translation for a nested translatable settings hash.
    module ComponentSettingPendingLocales
      module_function

      def for(field_hash, organization)
        return [] unless field_hash.is_a?(Hash)

        allowed = organization.available_locales.map(&:to_s)
        default = organization.default_locale.to_s
        fh = field_hash.stringify_keys

        if minimalistic?(organization)
          return [] unless fh[default].present?

          allowed - [default]
        else
          human = fh.except("machine_translations").each_with_object([]) do |(loc, val), memo|
            memo << loc if val.present?
          end
          allowed - human
        end
      end

      def minimalistic?(organization)
        Decidim::Voca.minimalistic_deepl? && organization.enable_machine_translations?
      end
    end
  end
end
