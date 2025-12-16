# frozen_string_literal: true

module Decidim
  module Voca
    module CodeCensus
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Voca::CodeCensus

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resource :authorization, only: [:new, :create], as: :authorization
          root to: "authorizations#new"
        end
      end
    end
  end
end
