---
sidebar_position: 6
slug: /feature-toggle
title: Feature toggle
description: decidim-voca does not register a system tab to enable or disable spaces or components
---

# Feature toggle

This page is for **platform operators** looking for a **decidim-voca** organization settings tab to turn participatory space types or component types on or off.

**decidim-voca** does not register that tab.

## Infrastructure

The gem still ships other Voca behaviour (routing, translation, telemetry, and so on). None of that is a system **Organizations** tab for space or component enable/disable.

There is no `SettingsTab` / ConfigForm in this gem for those flags.

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
