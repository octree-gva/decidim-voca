# frozen_string_literal: true

module Decidim
  module Voca
    class DeeplContext < ActiveSupport::CurrentAttributes
      attribute :organization
      attribute :participatory_space
      attribute :current_component
      attribute :current_user
      attribute :current_locale
      include ::Decidim::TranslatableAttributes
      include ActionView::Helpers::SanitizeHelper
      include ActionView::Helpers::TagHelper

      ##
      # @return String Context for Deepl API
      def deepl_context
        (
          ["Context: the text is written from a participatory platform, organized in participatory spaces, components and users."] +
            organization_context +
            participatory_space_context +
            current_component_context +
            current_user_context
        ).compact_blank.join("\n")
      end

      private
      def located_organization
        @located_organization ||= GlobalID::Locator.locate(organization)
      end

      def located_participatory_space
        @located_participatory_space ||= GlobalID::Locator.locate(participatory_space)
      end

      def located_current_component
        @located_current_component ||= GlobalID::Locator.locate(current_component)
      end

      def located_current_user
        @located_current_user ||= GlobalID::Locator.locate(current_user)
      end

      def organization_context
        return [] unless located_organization

        [
          "- Platform Name: #{translated_attribute(located_organization.name) || "undefined"}",
          "- Platform Description: #{strip_tags(sanitize(translated_attribute(located_organization.description)) || "undefined")}"
        ]
      end

      def participatory_space_context
        return [] unless located_participatory_space

        [
          "- Participatory Space Name: #{translated_attribute(located_participatory_space.name) || "undefined"}",
          "- Participatory Space Description: #{strip_tags(sanitize(translated_attribute(located_participatory_space.description)) || "undefined")}"
        ]
      end

      def current_component_context
        return [] unless located_current_component

        [
          "- Component Name: #{translated_attribute(located_current_component.name) || "undefined"}"
        ]
      end

      def current_user_context
        return [] unless located_current_user
        return [] unless located_current_user.admin? || located_current_user.roles.any?

        [
          "- Author Name: #{located_current_user.name || "undefined"}",
          "- Author Bio: #{located_current_user.about || "undefined"}"
        ]
      end
    end
  end
end
