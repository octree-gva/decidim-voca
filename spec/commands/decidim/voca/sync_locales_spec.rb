# frozen_string_literal: true

require "spec_helper"

module Decidim::Voca
  describe "SyncLocales command" do
    let(:rake_task) { instance_double(Rake::Task, reenable: nil, invoke: nil) }

    before do
      allow(Rake::Task).to receive(:task_defined?).with("decidim:locales:rebuild_search").and_return(true)
      allow(Rake::Task).to receive(:[]).with("decidim:locales:rebuild_search").and_return(rake_task)
      runner = instance_double(Decidim::Voca::SyncLocales::Runner, call: nil)
      allow(Decidim::Voca::SyncLocales::Runner).to receive(:new).and_return(runner)
    end

    it "rebuilds search after sync and broadcasts ok" do
      expect { SyncLocales::Command.call }.to broadcast(:ok)
      expect(rake_task).to have_received(:invoke).once
      expect(rake_task).to have_received(:reenable).once
    end

    it "passes model_name to the runner" do
      allow(Decidim::Voca::SyncLocales::Runner).to receive(:new).with(model_name: "Decidim::Component").and_return(
        instance_double(Decidim::Voca::SyncLocales::Runner, call: nil)
      )
      expect { SyncLocales::Command.call(model_name: "Decidim::Component") }.to broadcast(:ok)
    end

    it "skips search rebuild for TermCustomizer::Translation filter" do
      allow(Decidim::Voca::SyncLocales::Runner).to receive(:new).with(
        model_name: "Decidim::TermCustomizer::Translation"
      ).and_return(instance_double(Decidim::Voca::SyncLocales::Runner, call: nil))

      expect { SyncLocales::Command.call(model_name: "Decidim::TermCustomizer::Translation") }.to broadcast(:ok)
      expect(rake_task).not_to have_received(:invoke)
    end
  end

  describe ".translatable_model_names" do
    it "returns sorted Decidim TranslatableResource class names" do
      names = SyncLocales.translatable_model_names
      expect(names).to include("Decidim::Component")
      expect(names).to include("Decidim::ContentBlock")
      expect(names).to eq(names.sort)
    end
  end
end
