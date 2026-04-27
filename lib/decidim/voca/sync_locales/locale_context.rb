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
          raise "Organization not found for #{record.class.name} (id: #{record.id.inspect}) [found #{org.class.name}]" unless org && org.is_a?(::Decidim::Organization)

          new(
            allowed_locales: Array(org.available_locales).map(&:to_s),
            default_locale: org.default_locale.to_s,
            organization: org
          )
        end

        def self.resolve_organization!(record)
          return record if record.is_a?(::Decidim::Organization)

          resolve_with_resolvers(record) || raise_missing_organization!(record)
        end

        def self.resolve_with_resolvers(record)
          resolver_methods.each do |resolver|
            organization = send(resolver, record)
            return organization if organization.present?
          end
          nil
        end

        def self.resolver_methods
          [
            :try_attachment,
            :try_organization,
            :try_participatory_space_organization,
            :try_component,
            :try_comment_organization,
            :try_result,
            :try_meeting,
            :try_questionnaire,
            :try_question,
            :try_proposal,
            :try_collaborative_draft,
            :try_commentable
          ]
        end

        def self.try_attachment(record)
          return unless record.respond_to?(:collection_for) && record.collection_for

          context = resolve_with_resolvers(record.collection_for)
          return if context.blank?

          context
        end

        def self.try_commentable(record)
          return unless record.respond_to?(:root_commentable) && record.root_commentable

          context = resolve_with_resolvers(record.root_commentable)
          return if context.blank?

          context
        end

        def self.try_meeting(record)
          return unless record.respond_to?(:meeting) && record.meeting

          try_component(record.meeting)
        end

        def self.try_questionnaire(record)
          questionnaire = if record.is_a?(::Decidim::Forms::Questionnaire)
                            record
                          elsif record.respond_to?(:questionnaire) && record.questionnaire
                            record.questionnaire
                          end
          return unless questionnaire

          questionnaire_for = questionnaire.questionnaire_for
          try_component(questionnaire_for) || try_organization(questionnaire_for)
        end

        def self.try_question(record)
          return unless record.respond_to?(:question) && record.question

          try_questionnaire(record.question)
        end

        def self.try_proposal(record)
          return unless record.respond_to?(:proposal) && record.proposal

          try_component(record.proposal)
        end

        def self.try_comment_organization(record)
          return unless record.respond_to?(:commentable) && record.commentable

          commentable = record.commentable
          return if commentable.nil?

          resolve_with_resolvers(commentable)
        end

        def self.try_collaborative_draft(record)
          return unless record.respond_to?(:collaborative_draft) && record.collaborative_draft

          try_component(record.collaborative_draft)
        end

        def self.try_result(record)
          return unless record.respond_to?(:result) && record.result

          try_component(record.result)
        end

        def self.try_organization(record)
          return unless record.respond_to?(:organization)

          record.organization
        end

        def self.try_participatory_space_organization(record)
          return unless record.respond_to?(:participatory_space) && record.participatory_space

          ps = record.participatory_space
          try_organization(ps)
        end

        def self.try_component(record)
          return unless record.respond_to?(:component) && record.component

          try_organization(record.component)
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
