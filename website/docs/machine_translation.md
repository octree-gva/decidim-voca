---
sidebar_position: 5
slug: /machine-translation
title: Machine Translation
description: DeepL-backed machine translation, minimalistic admin, CSV exports, locale management, and operations for decidim-voca
---

# Machine translation (DeepL)

[Decidim machine translation](https://docs.decidim.org/en/develop/develop/machine_translations.html) is normally pluggable: you point `config.machine_translation_service` at an adapter. **decidim-voca** extends that stack so the same DeepL pipeline can handle **top-level translatable columns** and **nested JSON** (for example **translated component settings**), which Decidim’s stock `MachineTranslationSaveJob` path alone does not cover.

## Overview: what decidim-voca adds

1. **Fill multilingual content via machine translation** — For resources voca registers (components, budgets, proposal states, templates when present, nested component settings marked `translated: true`, etc.), missing locales are filled through the **same DeepL-backed** jobs and voca’s **component-setting** job where needed, so content is not left half-translated when MT is enabled.
2. **Minimalistic administration (optional)** — When [minimalistic DeepL](#minimalistic-deepl-optional) is enabled, editors primarily work in the **organization default locale**; other locale slots are driven by machine translation and normalization rules, reducing parallel per-locale editing in admin.
3. **Consistent CSV exports** — Proposal, comment, and survey answer exports use a **stable, locale-first column layout** (for example `en/title`, `fr/body`, `locale`) so spreadsheets and open data stay comparable across proposals and surveys. See [CSV exports](#csv-exports-for-admins-and-open-data).
4. **Tasks for locale and content changes** — Rake tasks help after you change **default locale** or **available locales**, or when you need to **normalize** stored translation JSON and **re-enqueue** machine translation. See [Operation](#operation).

---

## Install

### Dependencies and API key

1. **`deepl-rb`** — Declared by decidim-voca; ensure your application bundle installs it.
2. **`DECIDIM_DEEPL_API_KEY`** — [Create a DeepL API key](https://www.deepl.com/pro-api) and set it in the environment (or your deployment secrets). Restart the application after changes.

Optional DeepL client settings (see also [Environment variables](#environment-variables-reference)):

- `DECIDIM_DEEPL_HOST` — API host (default `https://api.deepl.com`; Pro includes `https://api-free.deepl.com` for Free API).
- `DECIDIM_DEEPL_VERSION` — API version segment (default `v2`).

### Minimalistic DeepL (optional) {#minimalistic-deepl-optional}

If the [minimalistic behaviour](#overview-what-decidim-voca-adds) fits your project:

```rb
# config/initializers/decidim_voca.rb (or similar)
Decidim::Voca.configure do |config|
  config.enable_minimalistic_deepl = true
end
```

If it does **not** fit, set `enable_minimalistic_deepl` to `false` and restart.

When DeepL is enabled, voca sets `Decidim::Voca::DeepL::MachineTranslator` as `config.machine_translation_service` and sets **`Decidim.config.machine_translation_delay` to 3 seconds** (see [FAQ — Developers](#faq--developers)).

### Not compatible with Weglot for the same “stack”

decidim-voca can integrate **Weglot** for client-side / edge translation (see [Weglot](./weglot.md)), but **DeepL MT and Weglot are mutually exclusive in practice**: `Decidim::Voca.weglot?` is only true when Weglot is enabled **and** DeepL is **not** enabled (`deepl_enabled?` is false). If `DECIDIM_DEEPL_API_KEY` is set and DeepL loads, **Weglot UI integration is turned off** so DeepL-backed stored translations take precedence.

Do **not** plan to run both DeepL-backed decidim-voca MT and Weglot on the same site for the same content strategy.

### i18n-tasks

decidim-voca ships a small **`config/i18n-tasks.yml`** in the gem focused on **English locale files and voca view paths** (see comments in that file).

Typical workflow in **your host application** (extend or replace config as needed):

```bash
bundle binstub i18n-tasks
bin/i18n-tasks missing --config config/i18n-tasks.yml
bin/i18n-tasks translate-missing --from=en -l <locale> --backend=deepl
```

Use `bin/i18n-tasks translate-missing --help` for backends and options. Ensure `DEEPL_TRANSLATE_API_KEY` or the backend you use is available in the environment when translating keys.

---

## Operation

### Enable machine translation on the organization

Machine translation must be allowed **installation-wide** and **per organization**.

1. Configure **available locales** for the installation (`DECIDIM_AVAILABLE_LOCALES` / `config/initializers/decidim.rb` as in your app).
2. In **System** or **Rails console**, set on the target organization, for example:

```bash
bundle exec rails c
org = Decidim::Organization.find(<id>)
org.update!(
  enable_machine_translations: true,
  machine_translation_display_priority: "translation" # or "original" — see Decidim docs
)
```

`machine_translation_display_priority` controls whether users see **machine-translated** text or the **original** when both exist (Decidim core behaviour).

Restart workers/web if you change DeepL or voca configuration.

### Rake tasks

| Task | Purpose |
|------|---------|
| `decidim:voca:sync_locales` | Normalizes translatable JSON (including nested component settings), enqueues missing machine translation jobs, and **rebuilds the search index** before and after. **Requires [minimalistic DeepL](#minimalistic-deepl-optional) to be enabled** (`Decidim::Voca.minimalistic_deepl?` must be true — default is `enable_minimalistic_deepl: true` when DeepL is enabled). |
| `decidim:voca:clean_machine_translations` | Walks `TranslatableResource` models and removes locale keys that are not the org default and not part of the intended MT flow; can touch nested component settings. **Does not** enqueue `MachineTranslationFieldsJob`. Use `DRY_RUN=1` for a CSV preview to stdout. |

Examples (run inside your app environment, e.g. Docker `voca` service: `docker compose exec voca bash -lc 'cd /home/module && bundle exec rake …'`):

```bash
# After changing default or available locales, or to re-normalize and enqueue MT
# (fails fast if minimalistic DeepL is disabled — turn it on or use other maintenance paths)
bundle exec rake decidim:voca:sync_locales

# Preview cleanup without writes
DRY_RUN=1 bundle exec rake decidim:voca:clean_machine_translations > tmp/clean_machine_translations_preview.csv

# Apply cleanup (review code and backup DB first — can touch many rows)
bundle exec rake decidim:voca:clean_machine_translations
```

### Environment variables (reference) {#environment-variables-reference}

| Variable | Description | Typical default |
|----------|-------------|-----------------|
| `DECIDIM_DEEPL_API_KEY` | DeepL API key; required for voca DeepL MT in production | _(empty)_ |
| `DECIDIM_DEEPL_HOST` | DeepL API base URL | `https://api.deepl.com` |
| `DECIDIM_DEEPL_VERSION` | API version path segment | `v2` |
| `VOCA_DUMMY_TRANSLATE` | If `1`/`true`/`enabled`, skips real DeepL in voca’s string translation path and returns dummy text (dev/CI) | `false` |

---

## FAQ

### Does it work with Decidim Awesome?

**Partially.** Awesome works alongside voca for many features, but **proposal custom fields** that use the **form builder** UI do not get the same multilingual label story as core translatable fields; those labels are **not** covered by Decidim’s usual translatable-field machine translation. Plan content structure accordingly.

### When a participant writes in a non-default locale, do we see “translated from original”?

Decidim’s UI depends on **`machine_translation_display_priority`** and what is stored in each locale slot and under `machine_translations`. Voca’s **minimalistic** mode treats the **organization default locale** as the primary human source for admin-driven content; participant-authored content still follows each resource’s stored locale hash. If you need a specific “original vs translation” label in the UI, verify against your Decidim version and the resource presenter — it is **not** a separate voca-only flag.

### How is formality handled?

For DeepL calls made through voca’s translation path, **formality is set to `prefer_more`** when the target language [supports formality in the DeepL API](https://developers.deepl.com/docs/api-reference/translate) (voca checks language metadata and omits the parameter when unsupported).

### Are comments translated when the participant writes in another locale?

**Yes**, comment bodies go through the same translatable/machine-translation pipeline as in Decidim, subject to organization MT settings. **Open data / CSV exports** can expose **per-locale columns** and use human text when present, otherwise machine-translated text where stored — see [CSV exports](#csv-exports-for-admins-and-open-data).

---

## FAQ — Developers

### How do we make fields translatable?

In Decidim, models include `Decidim::TranslatableResource` and declare translatable fields; voca **merges** extra fields for some classes in `Decidim::Voca::DeepL::EngineConfig` (for example component `name`, budgets, proposal states, templates when installed). For **component settings**, use the component manifest (`translated: true` on global settings).

### How do we translate component settings?

Nested global settings are JSON under `settings` → `global` → `<key>` with a hash of locale strings plus optional `machine_translations`. Voca enqueues **`Decidim::Voca::MachineTranslateComponentSettingJob`** when the default-locale source for a translated setting changes, and `decidim:voca:sync_locales` can normalize and enqueue pending locales.

### How did CSV export change?

Serializers under `lib/decidim/voca/export/` reshape rows to **locale-first columns** (`<locale>/<field>`) and add **`locale`** where inferable. Wiring is registered from the engine; tests live under `spec/lib/decidim/voca/export*_spec.rb`.

### How do translatable fields look in the database?

Conventionally, a translatable column is a JSONB hash:

```json
{
  "en": "Hello from a human",
  "machine_translations": { "fr": "Bonjour (MT)" }
}
```

**Human-authored** text for a locale lives on the **top-level** key; **machine translations** live under `machine_translations` keyed by locale. When resolving text for export or display, **human values take priority** over machine-translated values for the same locale.

### Can we use another service instead of DeepL?

**Not realistically with this integration as shipped.** voca relies on DeepL for the stock MT pipeline **and** for **`TranslateString`** used by nested component-setting jobs. Swapping another provider would require a compatible adapter and reworking those paths — it is **not** a drop-in `config.machine_translation_service` change for all voca features.

### How to test machine translation without a DeepL API key?

- **RSpec**: stub `Decidim.machine_translation_service_klass` to `Decidim::Dev::DummyTranslator` (as in voca’s specs).
- **Runtime / dev**: set `VOCA_DUMMY_TRANSLATE` to enable dummy output in voca’s DeepL string path without calling the API (you may still need a key present for boot if DeepL is loaded — see your initializer and env).

### Why do DeepL-related tasks feel slow?

- **Job delay**: voca sets **`machine_translation_delay` to 3 seconds** so jobs are spaced (Decidim schedules MT work with that delay).
- **Concurrency**: string translation uses a **mutex** around DeepL API calls to avoid overlapping requests on the same process.

---

## CSV exports for admins and open data

- **Readable spreadsheets:** proposals, survey answers, and comments use **one column per language and field** (for example `en/title`, `fr/body`) plus a **`locale`** column when inferable.
- **Human vs machine:** exports prefer **human** text for a locale; if missing, **machine_translated** content for that locale is used when present.
- **Surveys:** answer text is repeated under each locale column so the grid stays rectangular; `locale` behaviour follows Decidim (often **default locale** for submission metadata — see limits in tests and core).

Implementation: `lib/decidim/voca/export/`, registration in `lib/decidim/voca/engine.rb`.

---

## Development / tests

Automated tests often use **`Decidim::Dev::DummyTranslator`** without calling DeepL. Production still expects **DeepL** when `DECIDIM_DEEPL_API_KEY` is set and voca DeepL is enabled.

---

## Reference

- [Decidim — Develop — Machine translations](https://docs.decidim.org/en/develop/develop/machine_translations.html)
- [DeepL API — Supported languages](https://developers.deepl.com/docs/resources/supported-languages)
- [DeepL API — Translate (formality and options)](https://developers.deepl.com/docs/api-reference/translate)
- [DeepL — API key security (restricting keys)](https://support.deepl.com/hc/en-us/articles/360020805640-API-key-security)
- [i18n-tasks (gem)](https://github.com/glebm/i18n-tasks)
