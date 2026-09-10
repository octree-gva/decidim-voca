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

## Configuration

You will not find **Participatory Spaces** or **Components** checkboxes under System → Organizations that come from **decidim-voca**.
