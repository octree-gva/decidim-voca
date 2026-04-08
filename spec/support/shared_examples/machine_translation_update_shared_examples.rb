# frozen_string_literal: true

# Requires:
#   :machine_translation_subject — model instance (reload inside shared example)
#   :machine_translation_field — Symbol
#   :machine_translation_target_locale — String (e.g. "fr")
#   :machine_translation_initial_source_text — String (default locale text before update)
#   :machine_translation_updated_source_text — String (default locale text after update)
#   :perform_create_with_machine_translation — proc: create + first MT pass
#   :perform_update_with_machine_translation — proc: update + second MT pass
RSpec.shared_examples "refreshes dummy machine translation when default locale source changes" do
  it "re-runs machine translation so machine_translations reflect the new source" do
    perform_with_machine_translation_jobs do
      perform_create_with_machine_translation.call
    end

    expect_dummy_machine_translation_for_field(
      machine_translation_subject.reload,
      machine_translation_field,
      machine_translation_target_locale,
      machine_translation_initial_source_text
    )

    perform_with_machine_translation_jobs do
      perform_update_with_machine_translation.call
    end

    expect_dummy_machine_translation_for_field(
      machine_translation_subject.reload,
      machine_translation_field,
      machine_translation_target_locale,
      machine_translation_updated_source_text
    )
  end
end
