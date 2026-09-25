# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- rake task entry point
RSpec.describe "decidim:voca:sync_term_customizer_locales" do
  before do
    DecidimVocaTermCustomizerSpecSupport.ensure_models!
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)
    Rails.application.load_tasks unless Rake::Task.task_defined?("decidim:voca:sync_term_customizer_locales")
  end

  it "invokes TermCustomizerSync without the full Runner" do
    syncer = instance_double(Decidim::Voca::SyncLocales::TermCustomizerSync, call: { done: 0, skipped: 0 })
    allow(Decidim::Voca::SyncLocales::TermCustomizerSync).to receive(:available?).and_return(true)
    allow(Decidim::Voca::SyncLocales::TermCustomizerSync).to receive(:new).and_return(syncer)
    expect(Decidim::Voca::SyncLocales::Runner).not_to receive(:new)

    expect(syncer).to receive(:call).with(print_summary: true)

    Rake::Task["decidim:voca:sync_term_customizer_locales"].reenable
    Rake::Task["decidim:voca:sync_term_customizer_locales"].invoke
  end
end
# rubocop:enable RSpec/DescribeClass
