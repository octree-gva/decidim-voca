# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module UserGroupFormOverrides
        extend ActiveSupport::Concern

        included do
          validates :nickname, format: { with: ::Decidim::User::REGEXP_NICKNAME }
        end
      end
    end
  end
end
