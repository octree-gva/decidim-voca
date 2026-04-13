# frozen_string_literal: true

module Decidim
  module Voca
    # Resolves which locale key holds human text for +MachineTranslationResourceJobVoca+ when
    # minimalistic mode treats the default locale as authoritative but that slot is empty
    # (e.g. participant wrote only in +I18n.locale+).
    module MachineTranslationHumanSource
      module_function

      # @param organization [Decidim::Organization]
      # @param field_hash [Hash] new value for a translatable JSONB field
      # @param job_source_locale [String] +I18n.locale+ passed into the resource job
      # @return [String, nil] locale string to read source text from, or nil if none
      def authoring_locale(organization, field_hash, job_source_locale)
        return nil unless organization && field_hash.is_a?(Hash)

        h = field_hash.stringify_keys
        dl = organization.default_locale.to_s
        return dl if h[dl].presence

        job_loc = job_source_locale.to_s
        return job_loc if job_loc.present? && h[job_loc].presence

        organization.available_locales.map(&:to_s).find { |loc| h[loc].presence }
      end
    end
  end
end
