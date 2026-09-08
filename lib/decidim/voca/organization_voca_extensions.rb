# frozen_string_literal: true

module Decidim
  module Voca
    module OrganizationVocaExtensions
      extend ActiveSupport::Concern

      included do
        def voca_features_toggle
          @voca_features_toggle ||= Decidim::Toggle.config_for(self, Decidim::Voca::MODULE_NAME)
        end

        def next_gen_images?
          voca_features_toggle["next_gen_images_enabled"]
        end

        def deepl_enabled?
          voca_features_toggle["deepl_enabled"]
        end

        def minimalistic_deepl?
          voca_features_toggle["minimalistic_deepl_enabled"]
        end

        def weglot?
          voca_features_toggle["weglot_enabled"]
        end

        def weglot_cache?
          voca_features_toggle["weglot_cache"]
        end
      end
    end
  end
end
