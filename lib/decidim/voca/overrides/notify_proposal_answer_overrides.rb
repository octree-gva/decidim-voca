# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # Add the param { force_email: true } to send an email to the proposal's author
      # and followers, regardless of their notification email settings.
      module NotifyProposalAnswerOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_original_notify_followers, :notify_followers

          def notify_followers
            return if proposal.state == "not_answered"

            Decidim::EventsManager.publish(
              event: "decidim.events.proposals.proposal_state_changed",
              event_class: Decidim::Proposals::ProposalStateChangedEvent,
              resource: proposal,
              affected_users: proposal.notifiable_identities,
              followers: proposal.followers - proposal.notifiable_identities,
              extra: { force_email: true }
            )
          end
        end
      end
    end
  end
end
