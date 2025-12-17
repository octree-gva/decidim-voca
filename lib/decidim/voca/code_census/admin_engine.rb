# frozen_string_literal: true

module Decidim
  module Voca
    # Admin namespace for CodeCensus admin engine/controllers
    module Admin
      module CodeCensus
        class AdminEngine < ::Rails::Engine
          isolate_namespace Decidim::Voca::Admin::CodeCensus

          paths["db/migrate"] = nil
          paths["lib/tasks"] = nil

          routes do
            resource :code_list, only: [:edit, :update], controller: "code_lists"
            root to: "code_lists#edit"
          end
        end
      end
    end
  end
end
