# frozen_string_literal: true

Decidim::Verifications.register_workflow(:code_census) do |workflow|
  workflow.engine = Decidim::Voca::CodeCensus::Engine
  workflow.admin_engine = Decidim::Voca::Admin::CodeCensus::AdminEngine
  workflow.icon = "community-line"
  workflow.time_between_renewals = 1.day
  workflow.ephemerable = true
end
