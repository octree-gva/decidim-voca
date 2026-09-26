# Sync Command
This folder includes the script for the rake task `decidim:voca:sync_locales`.

```
.
├── command.rb # Execute the runner (optional model_name:), wrapping rebuild search before and after
├── runner.rb # Discovers models, optional filter, normalizes fields, enqueues MT; prints done/skipped
├── enqueue_stats.rb # Counts enqueued vs skipped-existing translations
├── field_hash_normalizer.rb # normalize the hash to be sure "root" key is only default locale, and all the rest is machine-translated. Clean locales that are not available anymore.
├── machine_translation_enqueuer.rb # Enqueue DeepL for missing locales; skip present machine_translations
├── component_setting_sync.rb # For Decidim::Component only: normalize translated *global* settings JSON and enqueue Decidim::Voca::MachineTranslateComponentSettingJob (nested JSONB, not a DB column).
├── term_customizer_sync.rb # Optional TermCustomizer: fill blank Translation.value from customized default locale
├── locale_context.rb # Find the organization linked to a resource
```

List models: `rails decidim:voca:list_translatable_models`. Filter: `rails decidim:voca:sync_locales[Decidim::Attachment]` or `rails decidim:voca:sync_locales[Decidim::ContentBlock]`.
Term Customizer only: `rails decidim:voca:sync_term_customizer_locales`.

