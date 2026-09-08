# Contributing to decidim-voca

## Layout (where logic lives)

- **Engine** — `lib/decidim/voca/engine.rb` (initializers, `config.to_prepare`, routes)
- **Overrides** — `lib/decidim/voca/overrides/**`, `app/overrides/**` (Deface)
- **CSV export shape** — `lib/decidim/voca/export/**` (locale-first columns for `ProposalSerializer`, `CommentSerializer`, `UserAnswersSerializer`)
- **Public API / requires** — `lib/decidim/voca.rb`, `lib/decidim/voca/version.rb`
- **Specs** — `spec/` (dummy app under `spec/decidim_dummy_app/`)

Upstream references for exports: `Decidim::Exporters::CSV`, `Decidim::Exporters::ExportManifest` in decidim-core; serializers in `decidim-proposals`, `decidim-comments`, `decidim-forms`.

## Checks

From the repo root, with the `voca` container up:

```bash
docker compose exec voca bash -lc 'cd /home/module && unset DATABASE_URL && export RAILS_ENV=test && bundle exec rspec'
docker compose exec voca bash -lc 'cd /home/module && bundle exec rubocop lib/decidim/voca'
```

CI may run additional steps (see `.gitlab-ci.yml`). To run the GitLab **rubocop** and **rspec** jobs locally:

```bash
docker compose -f docker-compose.ci.yml run --rm rubocop
docker compose -f docker-compose.ci.yml run --rm rspec
```

`rspec` matches CI paths only (`spec/models`, `spec/forms`, `spec/node_audit_spec.rb`, `spec/lib`, `spec/commands`). Gem publish is not included.

## Docs

Human-facing documentation is under `website/docs/` (Docusaurus). CSV export behaviour and how it ties to machine translation are described in `website/docs/machine_translation.md` (CSV exports section). Organization feature toggles are described in `website/docs/feature-toggle.md`.
