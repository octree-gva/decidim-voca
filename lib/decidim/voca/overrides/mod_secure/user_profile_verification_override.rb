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
            strip_regex = /[<>?%&\^*#@()\[\]=+:;"{}\\|\n\r]/m
            ActionController::Base.helpers.strip_tags(string).gsub(strip_regex, "")
          end

          def voca_sanitize_name
            self.name = voca_sanitize_string(name) unless name.empty?
          end

          def voca_sanitize_nickname
            self.nickname = voca_sanitize_string(nickname).downcase unless nickname.empty?
          end
        end
      end
    end
  end
end
