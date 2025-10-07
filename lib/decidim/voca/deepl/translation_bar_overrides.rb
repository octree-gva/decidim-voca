# frozen_string_literal: true

module Decidim
  module Voca
    module Deepl
      module TranslationBarOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :voca_original_show, :show
          def show
            return if I18n.locale.to_s == current_organization.default_locale.to_s

            voca_original_show
          end
        end
      end
    end
  end
end
