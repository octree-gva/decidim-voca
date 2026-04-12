# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      class MissingOrganizationContextError < StandardError; end

      # Resolves allowed locales, default locale, and org machine-translation flag for a row.
      class LocaleContext
        attr_reader :allowed_locales, :default_locale, :organization

        def initialize(allowed_locales:, default_locale:, organization:)
          @allowed_locales = allowed_locales.map(&:to_s)
          @default_locale = default_locale.to_s
          @organization = organization
        end

        def self.for(record)
          org = resolve_organization!(record)
          new(
            allowed_locales: Array(org.available_locales).map(&:to_s),
            default_locale: org.default_locale.to_s,
            organization: org
          )
        end

        def self.resolve_organization!(record)
          return record if record.is_a?(::Decidim::Organization)

          try_organization(record) ||
            try_participatory_space_organization(record) ||
            try_component_organization(record) ||
            raise_missing_organization!(record)
        end

        def self.try_organization(record)
          return unless record.respond_to?(:organization)

          record.organization.presence
        end

        def self.try_participatory_space_organization(record)
          return unless record.respond_to?(:participatory_space)

          ps = record.participatory_space
          return unless ps.respond_to?(:organization)

          ps.organization.presence
        end

        def self.try_component_organization(record)
          return unless record.respond_to?(:component)

          comp = record.component
          return unless comp.respond_to?(:organization)

          comp.organization.presence
        end

        def self.raise_missing_organization!(record)
          rid = record.respond_to?(:id) ? record.id : "n/a"
          raise MissingOrganizationContextError,
                "Could not resolve Decidim::Organization for #{record.class.name} (id: #{rid.inspect})"
        end
        private_class_method :raise_missing_organization!

        def enable_machine_translations?
          organization.enable_machine_translations
        end
      end
    end
  end
end
