---
sidebar_position: 5
slug: /machine-translation
title: Machine Translation
description: How machine translation with DeepL works on voca, including component settings
---

# General overview

[Decidim machine translation](https://docs.decidim.org/en/develop/develop/machine_translations.html) is normally pluggable: you can point `config.machine_translation_service` at any adapter. **decidim-voca changes that contract for anything that goes through voca’s MT pipeline:** once the module is installed and you want machine translation, **the supported service is voca’s DeepL-based translator** (`Decidim::Voca::DeeplMachineTranslator`). That is required in practice because voca also machine-translates **nested JSON** (for example **translated component settings**), which cannot use Decidim’s stock `MachineTranslationSaveJob` path that only persists top-level JSONB columns.

**What voca machine-translates (no product “exceptions” in this list)**  
With voca enabled and DeepL configured, the same MT flow applies to everything voca registers, including for example:

- **Component** `name` and **translated global component settings** (e.g. proposals templates, announcements, help texts defined as `translated: true` in the component manifest).
- **Proposal states** (e.g. titles and announcement fields voca registers).
- **Budgets** titles and descriptions, **templates** (when the templates module is present), and other models voca merges into `TranslatableResource` in code.

So: **component name, component settings, proposal state names and announcements, etc.** are all intended to go through machine translation like the rest—not left out as optional exclusions.

**Tradeoffs we want to attend**

- If an admin specified a custom translation, it can get **fast** out of sync when the source string changes (there is no automatic notice).
- Many languages mean more load on editors and on translation quality review.
- Machine translation is not always ideal, especially for short strings that lack _context_.

**Voca solution (“minimalistic” DeepL)**  
We call part of our approach “minimalistic” machine translation, because we simplify the admin experience more than we add new UI:

When minimalistic mode is enabled (optional, see below):

- Other languages are not edited as separate admin fields in the same way; the **organization `default_locale`** is the authoritative human input.
- The admin experience can look like a single language; other locale slots are driven by machine translation where applicable.
- Stray non-default locale values can be normalized so stored JSON matches that model.

**VOCA implementation (minimalistic, when enabled)**  

- The machine-translation source locale is always the **organization `default_locale`**, even when the admin UI runs in another language (`I18n.locale`). That way `MachineTranslationResourceJob` (and related jobs) read the default slot for the string to translate.
- For scheduling work, only the **default locale slot** is treated as “already filled by a human” in minimalistic mode; other locales may still receive machine translation even if stray text appeared in those keys (for example manifest defaults). Non-default keys may be cleared on component create/update when minimalistic mode is on so the stored JSON matches “single-locale edit”.

# Enable DeepL machine translation (and voca syncing)

For **decidim-voca** machine translation—including **component settings**—you must wire DeepL. Concretely:

1. **Install `deepl-rb`**  
   The voca gem already depends on it; ensure your application bundle resolves it (same as other decidim-voca dependencies).

2. **Set `DECIDIM_DEEPL_API_KEY`**  
   [Get a DeepL API key](https://www.deepl.com/en/your-account/keys) and export it in the environment (or your deployment secrets). A paid plan is required in most cases.

3. **Optionally configure minimalistic DeepL**  
   If the minimalistic behaviour above fits your project, enable it in an initializer:

   ```rb
   Decidim::Voca.configure do |config|
     config.enable_minimalistic_deepl = true
   end
   ```

   If it does **not** fit, set `config.enable_minimalistic_deepl = false` and restart.

After `DECIDIM_DEEPL_API_KEY` is set, restart the application so the voca initializer can register DeepL and `Decidim::Voca::DeeplMachineTranslator` as `config.machine_translation_service`.

**Development / tests**  
Automated tests often stub `Decidim.machine_translation_service_klass` (for example with Decidim’s dummy translator) without calling DeepL. That does not change production expectations: **with voca, real MT is DeepL-backed as above.**

# Setup (organization and display)

First, set **`available_locales`** for your Decidim installation (environment variables or `config/initializers/decidim.rb`).

```bash
bundle exec rails c
Decidim.available_locales # List of available languages
```

Create the organization under `/system`. You may not see machine translation toggles in the system UI yet; that can be normal depending on version.

Then enable machine translation on the organization:

```bash
Decidim::Organization.last.update(
  enable_machine_translations: true,
  machine_translation_display_priority: "translation"
)
```

Restart the server after changing DeepL or voca configuration.

## Environment variables

| Environment variable   | Description                                      | Default                    |
|-------------------------|--------------------------------------------------|----------------------------|
| `DECIDIM_DEEPL_API_KEY` | DeepL API key (required for voca MT in prod)   | _(empty)_                  |
| `DECIDIM_DEEPL_HOST`    | DeepL API host (on-prem / regional endpoints) | `https://api.deepl.com`    |
| `DECIDIM_DEEPL_VERSION` | DeepL API version                              | `v2`                       |
| `VOCA_DUMMY_TRANSLATE`  | Debug: skip real DeepL calls and render dummy text | `false`                |

## Translate missing `.yml` with machine translations

You can use the gem `i18n-tasks` in your Rails application to translate missing I18n values.

- add [`config/i18n-tasks.yml`](/i18n-tasks.yml) (see voca / project template)
- run `bundle binstub i18n-tasks`
- run `bin/i18n-tasks translate-missing --from=en -l=ru --backend=deepl` (see `bin/i18n-tasks translate-missing --help`)

### Test translations without calling DeepL

For local or CI testing, set `VOCA_DUMMY_TRANSLATE` to `true`. That avoids calling DeepL and renders debug text whenever the voca translation path runs. You can still set `DECIDIM_DEEPL_API_KEY` to a placeholder if something in boot expects it to be present.

Example debug fragment:

```
DUMMY TRANSLATION [date=12/02/2025 14:05:16,mode=html,context="…"]
```

You can use it to check that updates change the timestamp, that `mode` matches text vs HTML, and that context strings look sensible.

### Disable minimalistic DeepL

If minimalistic mode does not fit your project:

```rb
Decidim::Voca.configure do |config|
  config.enable_minimalistic_deepl = false
end
```

Restart the server.

## Clean translatable fields (rake)

The task `decidim:voca:clean_machine_translations` walks models that use `TranslatableResource` and removes locale keys that are neither the organization default locale nor part of the intended machine-translation flow. It also handles **nested translated fields inside `Decidim::Component` settings** (global keys declared `translated: true` in the component manifest). It can be expensive on large databases.

**Dry run (no writes):** set `DRY_RUN=1` to print a semicolon-separated CSV to stdout: `model;field;value`, where `value` is the JSON **before** any change. Component nested fields use a field name like `settings[attribute_name]`.

```bash
DRY_RUN=1 bundle exec rake decidim:voca:clean_machine_translations > tmp/clean_machine_translations_preview.csv
```

Without `DRY_RUN`, records are updated (including `save!` for top-level translatable columns and `update_column` where used for settings JSON).

## Sync locales (rake)

`decidim:voca:sync_locales` normalizes translatable JSON and enqueues missing machine translations. For components, it also normalizes **translated global settings** and enqueues voca’s **component-setting** translation job (not the stock field job), so settings stay aligned with the same DeepL stack.

## Known pitfall

- Decidim Awesome custom proposals use `jquery.formbuilder`, which does not support multilingual labels for that builder UI; those labels are not covered by Decidim’s usual translatable-field MT.
- When a participant writes content in a locale that is normally machine-translated, UX may not always make it obvious that content was stored or displayed as if it were the default locale—plan communications and moderation accordingly.
