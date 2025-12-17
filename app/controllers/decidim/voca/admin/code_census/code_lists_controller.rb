# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      module CodeCensus
        class CodeListsController < Decidim::Admin::ApplicationController
          layout "decidim/admin/users"
          helper_method :existing_codes

          def edit
            @form = form(CodeListForm).from_params(codes_text: existing_codes.join("\n"))
          end

          def update
            @form = form(CodeListForm).from_params(params)

            SaveCodeList.call(@form, current_organization, current_user) do
              on(:ok) do
                flash[:notice] = I18n.t("decidim.voca.admin.code_census.code_lists.update.success")
                redirect_to edit_code_list_path
              end

              on(:invalid) do
                flash.now[:alert] = I18n.t("decidim.voca.admin.code_census.code_lists.update.error")
                render :edit, status: :unprocessable_entity
              end
            end
          end

          private

          def existing_codes
            Decidim::Voca::ValidationCode.where(organization: current_organization).pluck(:code)
          end
        end
      end
    end
  end
end
