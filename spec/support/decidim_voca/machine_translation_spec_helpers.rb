# frozen_string_literal: true

module Decidim
  module Voca
    # Helpers for specs that assert Decidim machine translation (DummyTranslator + job chain).
    module MachineTranslationSpecHelpers
      extend ActiveSupport::Concern

      included do
        include ActiveJob::TestHelper
      end

      # Runs the block inside ActiveJob's test adapter with recursive job execution so
      # MachineTranslationResourceJob → MachineTranslationFieldsJob → MachineTranslationSaveJob
      # all complete (same as a single top-level perform_enqueued_jobs after save would not).
      def perform_with_machine_translation_jobs(&)
        perform_enqueued_jobs(&)
      end

      def expect_dummy_machine_translation_for_field(record, field, target_locale, source_text)
        record.reload
        value = record.public_send(field)
        expect(value).to include("machine_translations")
        expect(value.dig("machine_translations", target_locale)).to eq("#{target_locale} - #{source_text}")
      end

      def stub_dummy_machine_translator
        allow(Decidim).to receive(:machine_translation_service_klass).and_return(Decidim::Dev::DummyTranslator)
      end
    end
  end
end

RSpec.configure do |config|
  config.include Decidim::Voca::MachineTranslationSpecHelpers
end
