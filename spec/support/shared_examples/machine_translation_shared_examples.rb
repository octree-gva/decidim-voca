# frozen_string_literal: true

# Lets (all required):
#   :machine_translation_subject — record after save (reload manually if needed)
#   :machine_translation_field — Symbol
#   :machine_translation_target_locale — String (e.g. "fr")
#   :machine_translation_source_text — String (DummyTranslator prepends "#{locale} - ")
#   :perform_machine_translation_save — proc run inside perform_with_machine_translation_jobs
RSpec.shared_examples "persists dummy machine translations for field" do
  it "stores machine_translations for the target locale" do
    perform_with_machine_translation_jobs do
      perform_machine_translation_save.call
    end

    expect_dummy_machine_translation_for_field(
      machine_translation_subject,
      machine_translation_field,
      machine_translation_target_locale,
      machine_translation_source_text
    )
  end
end
