# frozen_string_literal: true

require 'next_gen_images/view_helpers'

module Decidim
  module Voca
    module Overrides
      module NextGenImagesRailtieOverride
        extend ActiveSupport::Concern
        included do 
          @rake_tasks.clear
        end 
      end
    end
  end
end