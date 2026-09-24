# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read `docs/ARCHITECTURE.md` before making non-trivial changes.** It has the full rationale for every major
decision (why Solidus, why this payment/freight/tax approach, what's done vs. planned per phase) and a list of
environment quirks that look wrong but aren't — don't "fix" those without reading that section first.

## Environment setup

Gems are vendored into `vendor/bundle` (`bundle config set --local path 'vendor/bundle'` was run once; this
persists in `.bundle/config`). Rails/Bundler themselves are installed as user gems, not vendored — their bin
directory must be on `PATH`:

```
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
```

Dev Postgres + Redis run via Docker (see `docker-compose.yml`):

```
docker compose up -d
bin/setup            # bundle install, db:prepare, etc. (--skip-server to not launch bin/dev)
bin/rails db:seed    # idempotent — safe to re-run; seeds option types/properties/Set taxonomy/sample catalog
```

Local dev also requires the `libvips` **system package** (not a gem) — Solidus's product image variant styles
need it. If image rendering 500s with `ImageProcessing::Error`, check `vips --version` for a glibc mismatch
before assuming it's an application bug.

## Common commands

```
bin/rails server -p 3000              # dev server — storefront at /, admin at /admin
bin/rails tailwindcss:build           # rebuild storefront CSS (also solidus_admin:tailwindcss:build for admin)

bundle exec rspec                                          # full suite
bundle exec rspec --exclude-pattern 'spec/system/**/*_spec.rb'  # excludes system specs (no browser driver set up yet)
bundle exec rspec spec/path/to/foo_spec.rb                  # single file
bundle exec rspec spec/path/to/foo_spec.rb:42               # single example by line

bin/rubocop          # lint (rubocop-rails-omakase); add -A to autocorrect
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit

RAILS_ENV=test bin/ci   # runs the exact same steps as CI (config/ci.rb), locally
```

Admin login (seeded): `admin@example.com` / `test123`.

## Commit convention

One discrete change per commit. Message format `[category]: message`, category lowercase (`feat`, `fix`,
`refactor`, `style`, `chore`, `test`, `docs`), **message always in English**.

## Architecture

**Single Rails app, three engines sharing it:** the storefront (generated directly into `app/` by
`solidus_starter_frontend` — plain Rails code you own, not a gem), `solidus_backend` (classic admin, mounted at
`/admin`), and `solidus_admin` (newer Tailwind-based admin, also at `/admin`, toggled by a
`solidus_admin`/`false` cookie — both coexist intentionally, this is upstream Solidus's own migration path, not
a leftover from setup).

**Two asset pipelines coexist on purpose.** The storefront uses Propshaft + the Tailwind v4 CLI
(`app/assets/stylesheets/application.tailwind.css` → `app/assets/builds/tailwind.css`, gitignored build output,
rebuilt by `bin/rails tailwindcss:build`). `solidus_backend`'s legacy admin CSS/JS still needs Sprockets, wired
through `app/assets/config/manifest.js`. See `docs/ARCHITECTURE.md`'s "Environment gotchas" section for why
`config.assets.css_compressor` is forced off and why there's no `tailwind.config.js` — both are load-bearing
fixes, not stylistic choices.

**Extending Solidus: `app/overrides/`, never core files.** Each file is flat (no subdirectory nesting) and
wraps its logic in a `module` matching the filename exactly — e.g. `condition_product_filter.rb` defines
`module ConditionProductFilter`. This isn't cosmetic: Zeitwerk expects that constant to exist at that path, and
`spec/solidus_starter_frontend_spec_helper.rb` has an `after(:suite)` hook that eager-loads everything and fails
loudly if it doesn't match. To reopen an existing Solidus module/class from inside that wrapper, use the fully
qualified form (`module ::Spree::Core::ProductFilters`, leading `::`) — without it you'd nest a new module under
your wrapper instead of reopening the real one. See `app/overrides/condition_product_filter.rb` and
`price_product_filter.rb` for worked examples (both reopen `Spree::Core::ProductFilters`, which its own gem
source explicitly says to override this way).

**Files generated directly into the app (not gem code) are edited directly, not decorated.** Everything under
`app/controllers`, `app/views`, `app/helpers`, `app/components` came from the `solidus_starter_frontend`
generator into *this* app — it's not `vendor/bundle` code, so normal edits apply (e.g.
`app/helpers/taxon_filters_helper.rb`). Only `bundle show solidus_core`/`solidus_backend`/etc. gem files need
the `app/overrides` decorator pattern.

**Data model** maps Pokémon TCG concepts onto Solidus's native mechanisms (products, taxonomies/taxons, option
types/values, properties) rather than custom tables — full mapping table in `docs/ARCHITECTURE.md`. Catalog
data is illustrative/seeded (`db/seeds/catalog.rb`), not a real product feed yet.

**i18n:** `pt-BR` is the only active locale, split by domain under `config/locales/pt-BR/*.yml`
(`storefront.yml`, `checkout.yml`, `admin.yml`, `general.yml`, `spree_overrides.yml` for gem-owned Solidus
strings needing a Portuguese override). Never hardcode user-facing strings in views/controllers.

**Visual identity tokens** (brand colors, `font-heading`/`font-body`/`font-ui`) live entirely in the `@theme`
block of `app/assets/stylesheets/application.tailwind.css` — there is no JS Tailwind config. Full design-system
rationale (palette, typography choices, what's still a placeholder) is in `docs/ARCHITECTURE.md`.
