# frozen_string_literal: true

module Decidim
  module Voca
    module CodeCensus
      class AuthorizationsController < Decidim::ApplicationController
        include Decidim::FormFactory
        include Decidim::Verifications::Renewable

        helper_method :authorization
        before_action :load_authorization
        layout "layouts/decidim/authorizations"

        def new
          @form = form(CodeForm).from_params(user: current_user)
        end

        def create
          @form = form(CodeForm).from_params(code_form_params.merge(user: current_user))

          ConfirmCodeAuthorization.call(@authorization, @form, session) do
            on(:ok) do
              flash[:notice] = t("authorizations.create.success", scope: "decidim.voca.code_census")
              redirect_to decidim_verifications.authorizations_path
            end

            on(:invalid) do
              flash.now[:alert] = t("authorizations.create.error", scope: "decidim.voca.code_census")
              render :new, status: :unprocessable_entity
            end
          end
        end

        private

        def authorization
          @authorization ||= AuthorizationPresenter.new(@authorization)
        end

        def load_authorization
          @authorization = Decidim::Authorization.find_or_initialize_by(
            user: current_user,
            name: "code_census"
          )
        end

        def code_form_params
          params.require(:code).permit(:code)
        end
      end
    end
  end
end
