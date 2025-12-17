# frozen_string_literal: true
require "byebug"

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

        config.to_prepare do
          Decidim::Verifications.register_workflow(:code_census) do |workflow|
            workflow.engine = Decidim::Voca::CodeCensus::Engine
            workflow.admin_engine = Decidim::Voca::Admin::CodeCensus::AdminEngine
            workflow.icon = "community-line"
            workflow.time_between_renewals = 1.day
            workflow.ephemerable = true
          end
        end
      end
    end
  end
end
