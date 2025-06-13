module Decidim
  module Voca
    module HttpCache
      class RefreshController < ApplicationController
        def show
          # Must be GET, xhr request. 
          return head :not_found unless request.get? && request.xhr?
          csrf_token = form_authenticity_token
          headers["X-CSRF-Token"] = csrf_token
          render json: { csrf_token: csrf_token, connected: user_signed_in? }, status: :ok
        end
      end
    end
  end
end