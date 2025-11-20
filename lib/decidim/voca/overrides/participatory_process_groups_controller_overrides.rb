# frozen_literal_string: true

module Decidim
  module Voca
    module Overrides
      module ParticipatoryProcessGroupsControllerOverrides
        extend ActiveSupport::Concern

        included do

          alias_method :decidim_original_participatory_process_group, :participatory_process_group

          def participatory_process_group
            byebug
            return unless collection.exists?(params[:id])

            @participatory_process_group ||= collection.find(params[:id])
          end
        end
      end
    end
  end
end
