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
            :try_participatory_space,
            :try_assembly,
            :try_conference,
            :try_conference_speakers,
            :try_conference_meeting,
            :try_component,
            :try_comment_organization,
            :try_author,
            :try_user,
            :try_current_user,
            :try_sender,
            :try_recipient,
            :try_conversation,
            :try_amender,
            :try_result,
            :try_meeting,
            :try_questionnaire,
            :try_question,
            :try_proposal,
            :try_resource,
            :try_collaborative_draft,
            :try_commentable,
            :try_project,
            :try_budget,
            :try_awesome_config,
            :try_category,
            :try_coauthorable,
            :try_flow,
            :try_condition,
            :try_from_to,
            :try_reminder,
            :try_parent,
            :try_item
          ]
        end

        def self.try_attachment(record)
          return unless record.respond_to?(:collection_for) && record.collection_for

          context = resolve_with_resolvers(record.collection_for)
          return if context.blank?

          context
        end

        def self.try_attached_to(record)
          return unless record.respond_to?(:attached_to) && record.attached_to

          context = resolve_with_resolvers(record.attached_to)
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

        def self.try_awesome_config(record)
          return unless record.respond_to?(:awesome_config) && record.awesome_config

          try_organization(record.awesome_config)
        end

        def self.try_reminder(record)
          return unless record.respond_to?(:reminder) && record.reminder

          try_component(record.reminder)
        end

        def self.try_project(record)
          return unless record.respond_to?(:project) && record.project

          try_component(record.project)
        end

        def self.try_budget(record)
          return unless record.respond_to?(:budget) && record.budget

          try_component(record.budget)
        end

        def self.try_category(record)
          return unless record.respond_to?(:category) && record.category

          try_participatory_space(record.category)
        end

        def self.try_flow(record)
          return unless record.respond_to?(:flow) && record.flow

          try_organization(record.flow)
        end

        def self.try_condition(record)
          return unless record.respond_to?(:condition) && record.condition

          try_organization(record.condition)
        end

        def self.try_coauthorable(record)
          return unless record.respond_to?(:coauthorable) && record.coauthorable

          resolve_with_resolvers(record.coauthorable)
        end

        def self.try_from_to(record)
          if record.respond_to?(:from) && record.from
            resolve_with_resolvers(record.from)
          elsif record.respond_to?(:to) && record.to
            resolve_with_resolvers(record.to)
          end
        end

        def self.try_parent(record)
          return unless record.respond_to?(:parent) && record.parent

          resolve_with_resolvers(record.parent)
        end

        def self.try_item(record)
          return unless record.respond_to?(:item) && record.item

          resolve_with_resolvers(record.item)
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

        def self.try_resource(record)
          return unless record.respond_to?(:resource) && record.resource

          resolve_with_resolvers(record.resource)
        end

        def self.try_author(record)
          return unless record.respond_to?(:author) && record.author

          try_organization(record.author)
        end

        def self.try_conference(record)
          return unless record.respond_to?(:conference) && record.conference

          try_organization(record.conference)
        end

        def self.try_conference_speakers(record)
          return unless record.respond_to?(:conference_speakers) && record.conference_speakers

          speaker = record.conference_speakers.first
          return if speaker.nil?

          try_organization(speaker)
        end

        def self.try_conference_meeting(record)
          return unless record.respond_to?(:conference_meeting) && record.conference_meeting

          try_component(record.conference_meeting)
        end

        def self.try_user(record)
          return unless record.respond_to?(:user) && record.user

          try_organization(record.user)
        end

        def self.try_sender(record)
          return unless record.respond_to?(:sender) && record.sender

          try_organization(record.sender)
        end

        def self.try_current_user(record)
          return unless record.respond_to?(:current_user) && record.current_user

          try_organization(record.current_user)
        end

        def self.try_recipient(record)
          return unless record.respond_to?(:recipient) && record.recipient

          try_organization(record.recipient)
        end

        def self.try_conversation(record)
          return unless record.respond_to?(:conversation) && record.conversation

          participants = record.conversation.participants
          return if participants.empty?

          try_organization(participants.first)
        end

        def self.try_amender(record)
          return unless record.respond_to?(:amender) && record.amender

          try_organization(record.amender)
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

        def self.try_participatory_space(record)
          return unless record.respond_to?(:participatory_space) && record.participatory_space

          try_organization(record.participatory_space)
        end

        def self.try_assembly(record)
          return unless record.respond_to?(:assembly) && record.assembly

          try_organization(record.assembly)
        end

        def self.try_component(record)
          component = try_decidim_component_id(record)
          return component if component.present?

          return unless record.respond_to?(:component) && record.component

          try_organization(record.component)
        end

        def self.try_decidim_component_id(record)
          return unless record.respond_to?(:decidim_component_id) && record.decidim_component_id

          try_organization(Decidim::Component.find(record.decidim_component_id))
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
