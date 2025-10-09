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
        return @app.call(env) if env["PATH_INFO"]&.start_with?("/rails/active_storage/")

        begin
          deepl_context!(env)
        rescue StandardError => e
          log_error("Failed to set Deepl context", e)
          # return [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]]
        end
        @app.call(env)
      end

      private

      def deepl_context!(env)
        return unless Decidim::Voca.deepl_enabled?

        organization_context!(env)
        participatory_space_context!(env)
        component_context!(env)
        locale_context!
        Decidim::Voca::DeeplContext.attributes
      end

      def organization_context!(env)
        organization = env["decidim.current_organization"]
        return unless organization

        Decidim::Voca::DeeplContext.organization = organization.to_global_id.to_s
      rescue StandardError => e
        log_error("Failed to set organization context", e)
      end

      def participatory_space_context!(env)
        participatory_space = env["decidim.current_participatory_space"]
        return unless participatory_space

        Decidim::Voca::DeeplContext.participatory_space = participatory_space.to_global_id.to_s
      rescue StandardError => e
        log_error("Failed to set participatory space context", e)
      end

      def component_context!(env)
        component = env["decidim.current_component"]
        return unless component

        Decidim::Voca::DeeplContext.current_component = component.to_global_id.to_s
      rescue StandardError => e
        log_error("Failed to set component context", e)
      end

      def locale_context!
        Decidim::Voca::DeeplContext.current_locale = I18n.locale.to_s
      rescue StandardError => e
        log_error("Failed to set locale context", e)
      end

      def log_error(message, error)
        Rails.logger.error("#{self.class.name}: #{message}")
        Rails.logger.error("Error: #{error.message}")
        Rails.logger.error("Backtrace: #{error.backtrace&.first(5)&.join("\n")}")
      end
    end
  end
end
