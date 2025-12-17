# frozen_string_literal: true

require "decidim/core"

module Decidim
  module Voca
    module Overrides
      module AuthorizationModalsControllerOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :original_authorize_action_path, :authorize_action_path

          def authorize_action_path(handler)
            return original_authorize_action_path(handler) unless handler == "code_census"

            begin
              path = decidim_code_census.new_authorization_path(redirect_url: request.referer)
              return path.to_s if path.present?
            rescue NoMethodError, ActionController::UrlGenerationError
              # Route helper not available, fall back to original
            end

            original_authorize_action_path(handler)
          end
        end
      end
    end
  end
end
