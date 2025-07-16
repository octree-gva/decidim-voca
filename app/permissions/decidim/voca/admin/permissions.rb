# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      class Permissions < Decidim::Proposals::Admin::Permissions
        def permissions
          return permission_action if permission_action.scope != :admin
          return permission_action unless user
          return permission_action if current_organization != user.organization

          super
        end

        private

        def current_organization
          context[:proposal].try(:organization) || context[:current_organization]
        end

        def component_settings
          context[:component_settings] || component.try(:settings)
        end

        def component
          context[:proposal].try(:component) || context[:current_component]
        end
      end
    end
  end
end
