# frozen_string_literal: true

module Decidim
  module Voca
    # Introspection for component settings marked +translated: true+ in the manifest.
    module ComponentSettingManifest
      module_function

      def translated_global_keys(manifest)
        return [] unless manifest.respond_to?(:settings)

        manifest.settings(:global).attributes.each_with_object([]) do |(name, attr), memo|
          memo << name.to_s if attr.translated?
        end
      end

      def translated_process_step_keys(manifest)
        return [] unless manifest.respond_to?(:settings)
        return [] unless manifest.settings(:step).respond_to?(:attributes)

        manifest.settings(:step).attributes.each_with_object([]) do |(name, attr), memo|
          memo << name.to_s if attr.translated?
        end
      end
    end
  end
end
