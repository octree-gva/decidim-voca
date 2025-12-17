# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      module CodeCensus
        class SaveCodeList < Decidim::Command
          def initialize(form, organization, current_user)
            @form = form
            @organization = organization
            @current_user = current_user
          end

          def call
            return broadcast(:invalid) unless @form.valid?

            Decidim::Voca::ValidationCode.transaction do
              Decidim::Voca::ValidationCode.where(organization: @organization).delete_all

              @form.codes.each do |code|
                Decidim::Voca::ValidationCode.create!(
                  code:,
                  decidim_organization_id: @organization.id
                )
              end
            end

            broadcast(:ok)
          end
        end
      end
    end
  end
end
