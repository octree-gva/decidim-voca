# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      class UpdateConfigCommand < Decidim::Command
        def initialize(organization, form)
          @organization = organization
          @form = form
        end

        def call
          return broadcast(:invalid) if form.invalid?

          ParticipatorySpaces.installed_spaces.each do |space, config|
            Decidim::Toggle.save_config!(
              organization,
              config[:name],
              { enabled: form.public_send(:"#{space}_enabled") }
            )
          end

          broadcast(:ok)
        rescue ActiveRecord::RecordInvalid
          broadcast(:invalid)
        end

        private

        attr_reader :organization, :form
      end
    end
  end
end
