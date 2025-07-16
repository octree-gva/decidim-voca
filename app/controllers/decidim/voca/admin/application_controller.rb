# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      class ApplicationController < Decidim::Admin::ApplicationController
        def permission_class_chain
          [::Decidim::Voca::Admin::Permissions] + super
        end
      end
    end
  end
end
