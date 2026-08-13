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

**Related:** [decidim-toggle integration docs](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-toggle/-/blob/main/README.md) for the generic tab registration API (`Decidim::Toggle.settings_tabs`, `ModuleConfigForm`).
