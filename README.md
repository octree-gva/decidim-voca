<h1 align="center"><img src="https://github.com/octree-gva/meta/blob/main/decidim/static/header.png?raw=true" alt="Decidim - Octree Participatory democracy on a robust and open source solution" /></h1>
<h4 align="center">
    <a href="https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-voca/issues">Issues</a>  |
    <a href="https://octree-gva.github.io/decidim-voca/">Documentation</a>  <br/><br />
    <a href="https://crowdin.com/project/decidim-spam-module"><img src="https://badges.crowdin.net/decidim-voca/localized.svg" /></a><br /><br />
    <a href="https://www.octree.ch">Octree</a> |
    <a href="https://octree.ch/en/contact-us/">Contact Us</a><br/><br/>
    <a href="https://decidim.org">Decidim</a> |
    <a href="https://docs.decidim.org/en/">Decidim Docs</a> |
    <a href="https://meta.decidim.org">Participatory Governance (meta Decidim)</a><br/><br/>
    <a href="https://matrix.to/#/+decidim:matrix.org">Decidim Community (Matrix+Element.io)</a><br /><br />
</h4><br />

# Decidim Voca
Fixes and adjustments for the Decidim instances distributed by voca. 

## Documentation
The documentation and the API specification are in the [documentation website](https://octree-gva.github.io/decidim-voca/)

## Development and testing (Docker)

Use the Compose stack from this directory. Prefer **`docker compose exec`** into the long-running **`voca`** service (after `docker compose up -d`) so Bundler sees the same gem path as the dev image.

Example: run the **export** specs and unset `DATABASE_URL` so the dummy app uses `config/database.yml`:

```bash
docker compose up -d
docker compose exec voca bash -lc 'cd /home/module && unset DATABASE_URL && export RAILS_ENV=test && bundle exec rspec spec/lib/decidim/voca/export*spec.rb'
```

There is no `bin/check` in this repository; use `bundle exec rspec` and `bundle exec rubocop` inside the container. See [CONTRIBUTING.md](CONTRIBUTING.md) for where features live.

### Features
- `anonymize users`: Run`rails decidim:voca:anonymize` to anonymize all your database and avoid sending email or leaking nicknames/passwords.

## Contribute

## License
This module is under APGLv3 Licence. See [LICENSE](LICENSE.md) for more information

## Update Versions
> Release a version is up to the maintainer of this repo. 

The main package.json version attribute is dispatch on versionning the ruby engine, allowing to bump the multi-repo with unique version. 

To run these scripts, change your current branch to `main` and do:

Release a patch
```
yarn version --new-version patch --no-git-tag-version
yarn postversion
git add .
git tag v0.0.<yourpatch>
```

Release a minor
```
yarn version --new-version minor --no-git-tag-version
yarn postversion
git add .
git tag $(yarn postversion)
```
