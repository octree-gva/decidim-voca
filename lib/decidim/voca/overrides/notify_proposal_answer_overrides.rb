# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # Add notify_author method with the param { force_email: true } to send an email to the proposal's author,
      # regardless of their notification email settings.
      module NotifyProposalAnswerOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_original_call, :call

          def call
            return broadcast(:invalid) if proposal.blank?

            if proposal.published_state? && state_changed?
              transaction do
                increment_score
                notify_followers
                notify_author
              end
            end

            broadcast(:ok)
          end

          def notify_author
            return if proposal.state == "not_answered"

            Decidim::EventsManager.publish(
              event: "decidim.events.proposals.proposal_state_changed",
              event_class: Decidim::Proposals::ProposalStateChangedEvent,
              resource: proposal,
              affected_users: proposal.notifiable_identities,
              extra: { force_email: true }
            )
          end
        end
      end
    end
  end
end
