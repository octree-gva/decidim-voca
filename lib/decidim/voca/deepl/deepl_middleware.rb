# frozen_string_literal: true

module Decidim
  module Voca
    # Before rendering the page, we set the Deepl Context from
    # request.env attributes set by decidim
    class DeeplMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        Decidim::Voca::DeeplContext.organization = env["decidim.current_organization"]
        Decidim::Voca::DeeplContext.participatory_space = env["decidim.current_participatory_space"]
        Decidim::Voca::DeeplContext.current_component = env["decidim.current_component"]
        Decidim::Voca::DeeplContext.current_user = env["warden"].user
        Decidim::Voca::DeeplContext.current_locale = I18n.locale
        @app.call(env)
      end
    end
  end
end
