# frozen_string_literal: true

module Decidim
  module Voca
    # Shared shape helpers for Awesome menu +value+ arrays ({"label" => locale hash, "url" => ...}).
    module AwesomeMenuLabels
      module_function

      def menu_config_value?(value)
        menu_items(value).any?
      end

      def menu_items(value)
        return [] unless value.is_a?(Array)

        value.filter_map do |item|
          next unless item.is_a?(Hash)

          stringy = item.deep_stringify_keys
          next unless stringy["label"].is_a?(Hash)
          next if stringy["url"].blank?

          stringy
        end
      end
    end
  end
end
