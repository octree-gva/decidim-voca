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
            :try_organization,
            :try_decidim_organization_id,
            :try_component,
            :try_participatory_space,
            :try_assembly,
            :try_conference,
            :try_flow,
            :try_condition,
            :try_awesome_config,
            :try_author,
            :try_user,
            :try_participant,
            :try_current_user,
            :try_sender,
            :try_recipient,
            :try_amender,
            :try_meeting,
            :try_agenda,
            :try_answer,
            :try_questionnaire,
            :try_question,
            :try_proposal,
            :try_collaborative_draft,
            :try_project,
            :try_budget,
            :try_category,
            :try_reminder,
            :try_result,
            :try_conference_meeting,
            :try_conference_speakers,
            :try_participants,
            :try_conversation,
            :try_commentable,
            :try_comment_organization,
            :try_resource,
            :try_attachment,
            :try_attached_to,
            :try_privatable_to,
            :try_coauthorable,
            :try_from_to,
            :try_parent,
            :try_shapefile,
            :try_constraints,
            :try_known_parent,
            :try_item
          ]
        end

        # ponytail: audited from 0.29 models + voca schema + geo; ceiling = list new belongs_to names here
        KNOWN_PARENT_ASSOCIATIONS = [
          :response, :election, :taxonomy, :taxonomy_item, :taxonomy_filter, :taxonomizable, :scope,
          :root_taxonomy, :type, :participatory_process, :document, :document_version, :vote,
          :translation_set, :api_client, :suggestion, :content_block, :moderation, :comment, :initiative,
          :order, :amendable, :emendation, :followable, :remindable, :categorizable, :authorization,
          :transfer, :valuator_role, :conference_speaker, :decidim_component, :decidim_geo_space,
          :suggestable, :user_group, :admin, :answer_option, :matrix_row, :condition_question,
          :reportable, :cancelled_by_user, :related_object, :blocking_user, :source_user, :managed_user,
          :registration_type, :message, :dummy_resource, :templatable, :attachment_collection, :target,
          :token_for, :topic, :version, :area, :area_type, :assembly_type, :scope_type, :last_comment_by,
          :proposal_state, :participatory_process_group, :participatory_process_type, :scoped_type,
          :decidim_proposals_component, :decidim_participatory_space, :user_report, :section, :subject,
          :status
        ].freeze

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

        def self.try_decidim_organization_id(record)
          org_id = if record.respond_to?(:decidim_organization_id) && record.decidim_organization_id.present?
                     record.decidim_organization_id
                   elsif record.respond_to?(:organization_id) && record.organization_id.present?
                     # e.g. StaticPageTopic schema column is organization_id
                     record.organization_id
                   end
          return unless org_id

          Decidim::Organization.find_by(id: org_id)
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

        def self.try_agenda(record)
          return unless record.respond_to?(:agenda) && record.agenda

          try_meeting(record.agenda)
        end

        def self.try_answer(record)
          # 0.29 uses Answer; newer Decidim renamed to Response
          related = if record.respond_to?(:answer) && record.answer
                      record.answer
                    elsif record.respond_to?(:response) && record.response
                      record.response
                    end
          return unless related

          try_questionnaire(related) || try_organization(related)
        end

        def self.try_constraints(record)
          return unless record.respond_to?(:constraints)

          constraint = begin
            record.constraints.first
          rescue StandardError
            nil
          end
          return unless constraint

          try_organization(constraint) || resolve_with_resolvers(constraint)
        end

        def self.try_known_parent(record)
          # ponytail: one-level re-entry guard; avoids A↔B loops via known parents
          return if Thread.current[:voca_sync_locales_known_parent]

          Thread.current[:voca_sync_locales_known_parent] = true
          begin
            KNOWN_PARENT_ASSOCIATIONS.each do |name|
              next unless record.respond_to?(name)

              related = safe_association(record, name)
              next unless known_parent_related?(related, record)

              organization = resolve_with_resolvers(related)
              return organization if organization.present?
            end
            nil
          ensure
            Thread.current[:voca_sync_locales_known_parent] = false
          end
        end

        def self.known_parent_related?(related, record)
          return false if related.blank? || related.equal?(record)
          # skip STI `type` strings / constants; allow Struct stand-ins in specs
          return false if related.is_a?(String) || related.is_a?(Module) || related.is_a?(Numeric)

          true
        end
        private_class_method :known_parent_related?

        def self.try_shapefile(record)
          # Geo::Shapedata: organization via scope may be nil; schema has decidim_geo_shapefiles_id
          # Skip ActiveStorage has_one_attached :shapefile on Shapefile itself
          shapefile = safe_association(record, :shapefile) if record.respond_to?(:shapefile)
          shapefile = nil unless shapefile.is_a?(ActiveRecord::Base)

          if shapefile.blank? && record.respond_to?(:decidim_geo_shapefiles_id) && record.decidim_geo_shapefiles_id
            return unless defined?(::Decidim::Geo::Shapefile)

            shapefile = ::Decidim::Geo::Shapefile.find_by(id: record.decidim_geo_shapefiles_id)
          end
          return unless shapefile

          try_organization(shapefile) || try_decidim_organization_id(shapefile)
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

        def self.try_privatable_to(record)
          return unless record.respond_to?(:privatable_to) && record.privatable_to

          resolve_with_resolvers(record.privatable_to)
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
          item = paper_trail_item(record)
          return resolve_with_resolvers(item) if item

          try_version_object_attributes(record)
        end

        def self.try_questionnaire(record)
          if record.respond_to?(:questionnaire_for)
            questionnaire_for = safe_association(record, :questionnaire_for)
            return try_component(questionnaire_for) || try_organization(questionnaire_for) if questionnaire_for
          end

          questionnaire = if record.is_a?(::Decidim::Forms::Questionnaire)
                            record
                          elsif record.respond_to?(:questionnaire)
                            safe_association(record, :questionnaire)
                          end
          return unless questionnaire
          return if questionnaire.equal?(record)

          try_questionnaire(questionnaire)
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

        def self.try_participant(record)
          return unless record.respond_to?(:participant) && record.participant

          try_organization(record.participant)
        end

        def self.try_participants(record)
          return unless record.respond_to?(:participants) && record.participants

          participant = record.participants.first
          return if participant.nil?

          try_organization(participant)
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

          begin
            org = record.organization
            return org if org.present?
          rescue ActiveRecord::RecordNotFound
            # Component default_scope can make delegated organization raise.
          end

          organization_from_component_id(record)
        end

        def self.try_participatory_space(record)
          return unless record.respond_to?(:participatory_space)

          space = safe_association(record, :participatory_space)
          return unless space

          try_organization(space)
        end

        def self.try_assembly(record)
          return unless record.respond_to?(:assembly) && record.assembly

          try_organization(record.assembly)
        end

        def self.try_component(record)
          organization = organization_from_component_id(record)
          return organization if organization.present?

          component = if record.respond_to?(:component)
                        safe_association(record, :component)
                      elsif record.respond_to?(:decidim_component)
                        safe_association(record, :decidim_component)
                      end
          component ||= unscoped_component_for(record)
          return unless component

          organization_of(component)
        end

        def self.try_decidim_component_id(record)
          organization_from_component_id(record)
        end

        def self.paper_trail_item(record)
          return unless record.respond_to?(:item_type) && record.respond_to?(:item_id)
          return if record.item_type.blank? || record.item_id.blank?

          if record.respond_to?(:item)
            item = safe_association(record, :item)
            return item if item
          end

          paper_trail_item_from_type(record)
        end
        private_class_method :paper_trail_item

        def self.paper_trail_item_from_type(record)
          klass = record.item_type.safe_constantize
          return unless klass.is_a?(Class) && klass < ActiveRecord::Base

          scope = klass.respond_to?(:unscoped) ? klass.unscoped : klass
          scope.find_by(id: record.item_id)
        end
        private_class_method :paper_trail_item_from_type

        # ponytail: reads organization_id/component_id from version object only; upgrade if other attrs needed
        def self.try_version_object_attributes(record)
          return unless record.respond_to?(:object) && record.object.present?

          attrs = record.object
          attrs = attrs.with_indifferent_access if attrs.respond_to?(:with_indifferent_access)
          return unless attrs.is_a?(Hash)

          if (org_id = attrs[:decidim_organization_id]).present?
            return Decidim::Organization.find_by(id: org_id)
          end

          if (component_id = attrs[:decidim_component_id]).present?
            component = Decidim::Component.unscoped.find_by(id: component_id)
            return organization_of(component) if component
          end

          nil
        end
        private_class_method :try_version_object_attributes

        def self.organization_from_component_id(record)
          component = unscoped_component_for(record)
          return unless component

          organization_of(component)
        end
        private_class_method :organization_from_component_id

        def self.unscoped_component_for(record)
          return unless record.respond_to?(:decidim_component_id) && record.decidim_component_id

          Decidim::Component.unscoped.find_by(id: record.decidim_component_id)
        end
        private_class_method :unscoped_component_for

        def self.organization_of(record)
          return unless record

          begin
            org = record.organization if record.respond_to?(:organization)
            return org if org.present?
          rescue ActiveRecord::RecordNotFound
            nil
          end

          space = safe_association(record, :participatory_space) if record.respond_to?(:participatory_space)
          return unless space

          space.organization if space.respond_to?(:organization)
        rescue ActiveRecord::RecordNotFound
          nil
        end
        private_class_method :organization_of

        def self.safe_association(record, name)
          return unless record.respond_to?(name)

          record.public_send(name)
        rescue ActiveRecord::RecordNotFound
          nil
        end
        private_class_method :safe_association

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
