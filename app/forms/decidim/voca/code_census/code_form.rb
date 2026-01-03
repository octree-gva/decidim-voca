# frozen_string_literal: true

module Decidim
  module Voca
    module CodeCensus
      class CodeForm < AuthorizationHandler
        attribute :code, String

        validates :code, presence: true, length: { minimum: 3 }
        validate :code_exists

        def metadata
          { code: code.to_s.strip }
        end

        def unique_id
          code.to_s.strip
        end

        private

        def code_exists
          return if validation_code.present?

          errors.add(:code, I18n.t("decidim.voca.code_census.authorizations.create.error"))
        end

        def validation_code
          @validation_code ||= Decidim::Voca::ValidationCode.find_by(
            decidim_organization_id: organization.id,
            code: code.to_s.strip
          )
        end

        def organization
          current_organization || user.organization
        end
      end
    end
  end
end
