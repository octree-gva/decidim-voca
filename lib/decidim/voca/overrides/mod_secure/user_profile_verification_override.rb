# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module UserProfileVerificationOverride
        extend ActiveSupport::Concern

        included do
          before_validation :voca_sanitize_name
          before_validation :voca_sanitize_nickname

          private 
          def voca_sanitize_string(string)
            ActionController::Base.helpers.strip_tags(string).gsub(/[<>?%&\^*#@()\[\]=+:;"{}\\|\n\r]/m, "")
          end

          def voca_sanitize_name
            self.name = voca_sanitize_string(name) unless name.empty?
          end

          def voca_sanitize_nickname
            self.nickname = voca_sanitize_string(nickname) unless nickname.empty?
          end

        end
      end
    end
  end
end
