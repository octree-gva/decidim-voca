# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::Voca::DeepL::EngineConfig do
  describe "MERGEABLE_FIELD_REGISTRY" do
    it "lists each class_name once" do
      names = described_class::MERGEABLE_FIELD_REGISTRY.map { |r| r[:class_name] }
      expect(names.uniq.size).to eq(names.size)
    end

    it "includes required proposal and organization widenings" do
      rows = described_class::MERGEABLE_FIELD_REGISTRY.index_by { |r| r[:class_name] }
      expect(rows["Decidim::Proposals::Proposal"][:fields]).to eq(%w(answer cost_report execution_period))
      expect(rows["Decidim::Organization"][:fields]).to eq(%w(short_name))
      expect(rows["Decidim::Forms::DisplayCondition"][:include_translatable_resource]).to be true
    end
  end

  describe ".apply_mergeable_fields!" do
    before do
      allow(Decidim::Voca::Installation).to receive(:deepl_enabled?).and_return(true)
      # Idempotent: safe to run multiple times in one process
      described_class.apply_mergeable_fields!
      described_class.send(:fix_accountability_timeline_entry_translatable_fields!)
    end

    it "merges proposal answer-related fields onto Proposal" do
      list = Decidim::Proposals::Proposal.translatable_fields_list.map(&:to_s)
      expect(list).to include("answer", "cost_report", "execution_period")
    end

    it "fixes TimelineEntry to list both title and description" do
      list = Decidim::Accountability::TimelineEntry.translatable_fields_list.map(&:to_s)
      expect(list).to contain_exactly("title", "description")
    end

    it "includes TranslatableResource on DisplayCondition when Forms is loaded" do
      next unless defined?(Decidim::Forms::DisplayCondition)

      expect(Decidim::Forms::DisplayCondition.included_modules).to include(Decidim::TranslatableResource)
      list = Decidim::Forms::DisplayCondition.translatable_fields_list.map(&:to_s)
      expect(list).to include("condition_value")
    end

    it "includes component settings machine translation on Component" do
      expect(Decidim::Component.included_modules).to include(Decidim::Voca::ComponentTranslatedSettingsMachineTranslation)
    end
  end
end
