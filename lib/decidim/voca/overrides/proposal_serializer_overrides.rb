# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ProposalSerializerOverrides
        extend ActiveSupport::Concern

        included do
          protected

          # Fix for vote exports:
          # When `vote_weights` is not present, the payload ends up as {:votes => {}},
          # and it does not fallback to `proposal_votes_count`. As a result, the export
          # omits the votes field entirely.
          def proposal_vote_weights
            payload = {}
            if proposal.respond_to?(:vote_weights)
              proposal.update_vote_weights!
              payload[:votes] = proposal.reload.vote_weights.empty? ? proposal.proposal_votes_count : proposal.reload.vote_weights
            end
            payload
          end
        end
      end
    end
  end
end
