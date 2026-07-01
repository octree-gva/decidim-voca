---
sidebar_position: 6
slug: /feature-toggle
title: Feature toggle
description: Organization-level toggles for participatory spaces and components (decidim-toggle)
---

# Feature toggle

Platform operators use **decidim-voca** together with **[decidim-toggle](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-toggle)** to turn participatory spaces and Decidim components on or off **per organization**, from the system admin UI (`/system`).

Toggles are stored as JSON module configuration on the organization. They do **not** uninstall gems or change the component registry — they control whether each space or component type is treated as enabled for that tenant, and hide related UI when disabled.

**Prerequisite:** `decidim-toggle` in the host app `Gemfile` (already required by `decidim-voca`).

## Where to configure

1. Sign in as system administrator.
2. Open **Organizations** → edit an organization.
3. Use the settings tabs registered by voca:
   - **Participatory Spaces** — initiatives, conferences, processes, assemblies.
   - **Component** — meetings, blogs, budgets, proposals, pages, debates, accountability, sortitions, forms, participatory documents, collaborative texts, elections.

Each checkbox is disabled in the form when the corresponding gem is not in the server bundle.

## Participatory spaces

Controls which **participatory space types** are enabled for the organization.

| Toggle | Default | Gem required |
|--------|---------|--------------|
| Participatory processes | on | `decidim-participatory_processes` |
| Assemblies | on | `decidim-assemblies` |
| Initiatives | off | `decidim-initiatives` |
| Conferences | off | `decidim-conferences` |

When a space type is **off**:

- **Admin:** space module entries, related homepage content blocks, and cross-space link fields are hidden (CSS on `body` data attributes).
- **Public:** main menu links, footer links, and global search filters for that space type are hidden the same way.

When a space type is **off**, you cannot save the toggle if the organization still has **published** spaces of that type. Unpublish them first.

Implementation: `Decidim::Voca::ParticipatorySpaces` (`lib/decidim/voca/participatory_spaces.rb`), module config key `spaces`.

## Components

Controls which **component manifests** admins can add and which related admin surfaces are shown.

| Toggle | Default | Gem required |
|--------|---------|--------------|
| Meetings | on | `decidim-meetings` |
| Blogs | on | `decidim-blogs` |
| Participatory budget | on | `decidim-budgets` |
| Proposals | on | `decidim-proposals` |
| Page | on | `decidim-pages` |
| Debates | on | `decidim-debates` |
| Accountability | on | `decidim-accountability` |
| Sortition | on | `decidim-sortitions` |
| Form | off | `decidim-only_forms` |
| Participatory document | off | `decidim-participatory_documents` |
| Collaborative text | off | `decidim-collaborative_texts` |
| Election | off | `decidim-elections` |
| Awesome Map | off | `decidim-decidim_awesome` |
| Fullscreen Iframe | off | `decidim-decidim_awesome` |
| Survey | on | `decidim-surveys` |

When a component type is **off**:

- **Admin only:** the “Add component” dropdown entry for that manifest is hidden, and dashboard metrics tied to that component are hidden where applicable.
- **Not changed:** participant-facing pages, open-data exports, and existing published components (validation prevents disabling while published components of that type still exist).

Implementation: `Decidim::Voca::Components` (`lib/decidim/voca/components.rb`), module config key `components`.

## How hiding works

Both features use the same pattern:

1. **Deface** adds `data-<name>-enabled="true|false"` on `<body>` (admin layout for components; admin and public layouts for participatory spaces).
2. **SCSS** in `app/packs/stylesheets/decidim/voca/` hides matching UI when the attribute is `false`.

No Ruby overrides of `Decidim.component_registry` are involved.

## Validation rules

For both tabs:

- A toggle cannot be turned **off** while the organization has **published** instances of that space or component type.
- Optional gems: checkbox is disabled when the gem is not installed; defaults apply from the table above when no config exists yet.

## Reference

| Module config key | Settings tab label | Ruby module |
|-------------------|-------------------|-------------|
| `spaces` | Participatory Spaces | `Decidim::Voca::ParticipatorySpaces` |
| `components` | Component | `Decidim::Voca::Components` |

**Locales:** field labels under `decidim_toggle.system.spaces.*` and `decidim_toggle.system.components.*` in `config/locales/en.yml`.

**Specs:** `spec/lib/decidim/voca/participatory_spaces*_spec.rb`, `spec/lib/decidim/voca/components*_spec.rb`.

**Related:** [decidim-toggle integration docs](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-toggle/-/blob/main/README.md) for the generic tab registration API (`Decidim::Toggle.settings_tabs`, `ModuleConfigForm`).
