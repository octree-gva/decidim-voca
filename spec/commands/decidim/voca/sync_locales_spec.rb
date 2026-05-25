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

    it "rebuilds search twice and broadcasts ok" do
      expect { SyncLocales::Command.call }.to broadcast(:ok)
      expect(rake_task).to have_received(:invoke).twice
      expect(rake_task).to have_received(:reenable).twice
    end
  end
end
