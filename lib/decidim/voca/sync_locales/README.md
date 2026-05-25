# Sync Command
This folder includes the script for the rake task `decidim:voca:sync_locales`. 

```
.
├── command.rb # Execute the runner, wrapping rebuild search before and after execution
└── runner.rb # Identifies all models that can be translated and run a normalization on translatable fields, and a new machine translation job if needed.
├── field_hash_normalizer.rb # normalize the hash to be sure "root" key is only default locale, and all the rest is machine-translated. Clean locales that are not available anymore.
├── machine_translation_enqueuer.rb # Enqueue a machine translation job for all the missing locales.
├── component_setting_sync.rb # For Decidim::Component only: normalize translated *global* settings JSON and enqueue Decidim::Voca::MachineTranslateComponentSettingJob (nested JSONB, not a DB column).
├── locale_context.rb # Find the organization linked to a resource
```

