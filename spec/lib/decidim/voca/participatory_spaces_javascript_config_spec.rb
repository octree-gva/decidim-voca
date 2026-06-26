# frozen_string_literal: true

require "spec_helper"

describe "Participatory spaces JavaScript config" do
  let(:organization) { create(:organization) }

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  it "exposes each participatory space enabled flag" do
    seed_participatory_space_toggle(organization, :decidim_initiatives, enabled: false)
    seed_participatory_space_toggle(organization, :decidim_conferences, enabled: true)

    config = Decidim::Toggle.javascript_config_for(organization)

    expect(config).to include(
      "decidim_initiatives.enabled" => false,
      "decidim_conferences.enabled" => true,
      "decidim_participatory_processes.enabled" => true,
      "decidim_assemblies.enabled" => true
    )
  end
end
