---
sidebar_position: 6
slug: /feature-toggle
title: Feature toggle
description: Enable or disable participatory spaces and components per organization (decidim-skin)
---

# Feature toggle

This page is for **platform operators** who turn participatory space types and component types on or off for one organization.

**decidim-voca** does not register those settings anymore (no Toggle tabs, no ConfigForm, no hide CSS or search overrides). Use **[decidim-skin](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-skin)** in the same Decidim image.

## Infrastructure

| Piece | Role |
|-------|------|
| `decidim-skin` | Skin tab: homepage plus per-tenant space and component flags |
| `decidim-toggle` | Settings tab host used by Skin (not by voca for these flags) |
| `decidim-voca` | Unrelated Voca tweaks only |

Put `decidim-skin` (and its `decidim-toggle` dependency) in the host `Gemfile`. Run Toggle migrations as Skin’s README describes.

## Where to configure

1. Sign in as system administrator.
2. Open **Organizations** → edit an organization.
3. Open the **Skin** tab.
4. Toggle participatory space types and component types, then save.

You cannot disable a type while that organization still has instances of it. Unpublish or remove them first.

Details, defaults, and how the UI is hidden live in the Skin gem (`README` and Skin docs). Do not add parallel tabs or Deface/CSS in voca for the same flags.

## Reference

| Need | Where |
|------|--------|
| Enable/disable a participatory space type | Skin tab (`Decidim::Skin::ParticipatorySpaces`) |
| Enable/disable a component type | Skin tab (`Decidim::Skin::Components`) |
| Legacy JSON keys `spaces` / `components` | Skin still reads them as fallback after a voca Toggle install |
