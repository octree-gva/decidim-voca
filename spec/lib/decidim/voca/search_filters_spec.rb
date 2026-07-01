# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::SearchFilters do
  subject(:organization) { create(:organization) }

  let(:results) do
    {
      "Decidim::User" => { count: 1, results: [] },
      "Decidim::ParticipatoryProcess" => { count: 0, results: [] },
      "Decidim::Assembly" => { count: 0, results: [] },
      "Decidim::Conference" => { count: 1, results: [] },
      "Decidim::Proposals::Proposal" => { count: 0, results: [] },
      "Decidim::Meetings::Meeting" => { count: 0, results: [] },
      "Decidim::Budgets::Project" => { count: 0, results: [] },
      "Decidim::Comments::Comment" => { count: 0, results: [] }
    }
  end

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  describe ".filter_results" do
    it "removes disabled participatory space and component resource types" do
      seed_participatory_space_toggle(organization, :participatory_processes, enabled: false)
      seed_participatory_space_toggle(organization, :conferences, enabled: true)
      seed_component_toggle(organization, :proposals, enabled: false)
      seed_component_toggle(organization, :budgets, enabled: false)

      filtered = described_class.filter_results(results, organization)

      expect(filtered.keys).to contain_exactly(
        "Decidim::User",
        "Decidim::Assembly",
        "Decidim::Conference",
        "Decidim::Meetings::Meeting",
        "Decidim::Comments::Comment"
      )
    end

    it "returns the original results when every toggle is enabled" do
      Decidim::Voca::Components::COMPONENTS.each_key do |component|
        seed_component_toggle(organization, component, enabled: true)
      end
      Decidim::Voca::ParticipatorySpaces::SPACES.each_key do |space|
        seed_participatory_space_toggle(organization, space, enabled: true)
      end

      expect(described_class.filter_results(results, organization)).to eq(results)
    end
  end

  describe ".search_resource_types_for_component" do
    it "returns searchable resource class names for budgets" do
      types = described_class.search_resource_types_for_component(:budgets)

      expect(types).to include("Decidim::Budgets::Project", "Decidim::Budgets::Budget")
    end

    it "returns an empty list for components without searchable resources" do
      expect(described_class.search_resource_types_for_component(:awesome_map)).to eq([])
    end
  end
end
