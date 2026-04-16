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
            try_comment_organization(record) ||
            try_result(record) ||
            try_meeting(record) ||
            try_questionnaire(record) ||
            try_question(record) ||
            try_proposal(record) ||
            try_collaborative_draft(record) ||
            raise_missing_organization!(record)
        end

        def self.try_meeting(record)
          return unless record.respond_to?(:meeting)
          record.meeting.component.organization
        end

        def self.try_questionnaire(record)
          questionnaire = if record.is_a?(::Decidim::Forms::Questionnaire)
                            record
                          elsif record.respond_to?(:questionnaire)
                            record.questionnaire
                          end
          return unless questionnaire

          questionnaire_for = questionnaire.questionnaire_for
          return questionnaire_for.component.organization if questionnaire_for.respond_to?(:component)
          return questionnaire_for.organization if questionnaire_for.respond_to?(:organization)
        end

        def self.try_question(record)
          return unless record.respond_to?(:question)
          self.try_questionnaire(record.question)
        end

        def self.try_proposal(record)
          return unless record.respond_to?(:proposal)
          record.proposal.component.organization
        end

        def self.try_comment_organization(record)
          return unless record.respond_to?(:commentable)

          commentable = record.commentable
          return if commentable.nil?

          try_organization(commentable) ||
            try_participatory_space_organization(commentable) ||
            try_component_organization(commentable)
        end

        def self.try_collaborative_draft(record)
          return unless record.respond_to?(:collaborative_draft)
          record.collaborative_draft.component.organization
        end

        def self.try_result(record)
          return unless record.respond_to?(:result)
          record.result.component.organization
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
