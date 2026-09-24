# Ocico Store

Pokémon TCG e-commerce (singles, sealed product, future graded cards) for the
Brazilian market. Rails 8 + [Solidus](https://solidus.io) monolith — storefront
and admin in one app.

Built almost entirely by AI coding agents. See [`CLAUDE.md`](CLAUDE.md) for
setup/commands and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full
rationale, data model, and phased roadmap (what's done vs. planned).

## Quick start

```
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
docker compose up -d          # Postgres + Redis
bin/setup                     # install deps, prepare db
bin/rails db:seed             # idempotent — seeds sample Pokémon TCG catalog
bin/rails server -p 3000
```

Storefront at `/`, admin at `/admin` (seeded login: `admin@example.com` /
`test123`). Requires the `libvips` system package for product image
processing — see `CLAUDE.md` if image rendering fails locally.

```
bundle exec rspec --exclude-pattern 'spec/system/**/*_spec.rb'   # test suite
bin/rubocop                                                       # lint
```
