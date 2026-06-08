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
          alias_method :voca_original_create_proposal, :create_proposal

          def create_proposal
            voca_original_create_proposal
            return unless @proposal

            @proposal.address = form.address if form.address.present?
            @proposal.latitude = form.latitude if form.latitude.present?
            @proposal.longitude = form.longitude if form.longitude.present?
            @proposal.save!
            @proposal.reload
          end
        end
      end
    end
  end
end
