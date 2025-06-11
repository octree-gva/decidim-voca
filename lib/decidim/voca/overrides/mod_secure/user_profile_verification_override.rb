# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module UserProfileVerificationOverride
        extend ActiveSupport::Concern

        included do
          before_validation :voca_sanitize_name
          before_validation :voca_sanitize_nickname

          def voca_sanitize_name
            self.name = name.gsub(/[^#{Decidim::UserBaseEntity::REGEXP_NAME}]/, "")
          end

          def voca_sanitize_nickname
            self.nickname = nickname.gsub(/[^#{Decidim::User::REGEXP_NICKNAME}]/, "")
          end
        end
      end
    end
  end
end
