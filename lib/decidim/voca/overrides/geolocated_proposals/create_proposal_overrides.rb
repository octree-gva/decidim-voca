# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      ##
      # Override the creation command to takes back the address, latitude and longitude from the form
      # and save them without generating a new notification.
      # On previous versions, the address would be saved only if not geolocated, meaning
      # nothing would be saved if the proposal was geolocated at creation time.
      module CreateProposalOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :voca_create_proposal_original, :create_proposal
          def create_proposal
            proposal_or_awesome_proposal = voca_create_proposal_original
            return unless proposal_or_awesome_proposal

            proposal = if proposal_or_awesome_proposal.is_a?(Decidim::Proposals::Proposal)
                         proposal_or_awesome_proposal
                       else
                         proposal_or_awesome_proposal.proposal
                       end
            proposal.address = form.address if form.address.present?
            proposal.latitude = form.latitude if form.latitude.present?
            proposal.longitude = form.longitude if form.longitude.present?
            proposal.save!
            proposal_or_awesome_proposal.reload
          end
        end
      end
    end
  end
end
