# frozen_string_literal: true

module Decidim
  module Voca
    class ApplicationController < Decidim::ApplicationController
      def permission_class_chain
        [::Decidim::Voca::Permissions] + super
      end
    end
  end
end
