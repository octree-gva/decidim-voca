# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::ParticipatorySpaces::UpdateConfigCommand do
  subject(:command) { described_class.new(organization, form) }

  let(:organization) { create(:organization) }
  let(:form) do
    Decidim::Voca::ParticipatorySpaces::ConfigForm.from_params(
      initiatives_enabled: false,
      conferences_enabled: true,
      participatory_processes_enabled: false,
      assemblies_enabled: true
    ).with_context(current_organization: organization)
  end

  before do
    allow(Decidim::Toggle).to receive(:gem_present?).and_return(true)
  end

  it "persists each participatory space toggle" do
    expect { command.call }.to broadcast(:ok)

    expect(Decidim::Voca::ParticipatorySpaces.enabled?(organization.reload, :decidim_initiatives)).to be(false)
    expect(Decidim::Voca::ParticipatorySpaces.enabled?(organization, :decidim_conferences)).to be(true)
    expect(Decidim::Voca::ParticipatorySpaces.enabled?(organization, :decidim_participatory_processes)).to be(false)
    expect(Decidim::Voca::ParticipatorySpaces.enabled?(organization, :decidim_assemblies)).to be(true)
  end

  context "when disabling a space with published content" do
    before do
      require "decidim/assemblies/test/factories"
      create(:assembly, organization:, published_at: Time.current)
    end

    let(:form) do
      Decidim::Voca::ParticipatorySpaces::ConfigForm.from_params(
        organization: {
          initiatives_enabled: false,
          conferences_enabled: true,
          participatory_processes_enabled: true,
          assemblies_enabled: false
        }
      ).with_context(current_organization: organization)
    end

    it "does not persist the toggle" do
      expect { command.call }.to broadcast(:invalid)

      expect(Decidim::Voca::ParticipatorySpaces.enabled?(organization.reload, :decidim_assemblies)).to be(true)
    end
  end
end
