# Ocico Store — Architecture & Roadmap

This is the durable reference for *why* this project is built the way it is, and
*what's left*. It's meant to survive across sessions/agents/machines — unlike
chat history or any single assistant's private memory, this file ships with the
repo. Keep it up to date as phases complete or decisions change.

## What this is

A Pokémon TCG e-commerce store (singles, sealed product, future graded cards)
for the Brazilian market: web storefront, admin with inventory control, payment,
freight calculation, import duty calculation (product is imported from
JP/US), and monetary flow reporting. Storefront and admin live in the same
Rails app/server.

The owner has a strong Laravel + PHP + React background and deliberately chose
**Ruby on Rails + Solidus** to learn a different stack, while still wanting
something production-grade, not a toy.

**The system is built almost entirely by AI coding agents.** This is the single
biggest constraint shaping every decision below: favor strong, well-documented
conventions and officially maintained gems over obscure ones, extend via
decorators (never edit gem/core files), and treat the test suite as the primary
correctness mechanism — especially for money/tax/stock logic, where mistakes
are expensive and an agent won't always notice it broke something subtle.

## Guiding principles

- **Monolith, one Rails app.** Store, admin, and API (if ever needed) share one
  codebase and one deploy.
- **Never edit Solidus core files.** All customization goes through
  `app/overrides` (decorators/additive files) or native extension points
  (calculators, payment methods, shipping calculators, `Spree::Config`). This
  keeps `bundle update solidus` safe and diffs reviewable.
- **Convention over invention.** When Solidus/Rails has a documented idiomatic
  way to do something, use it. Don't let an agent invent a parallel mechanism.
- **Tests are the specification.** Any change touching money/tax/stock/freight
  needs RSpec coverage. CI green is the practical substitute for line-by-line
  human review of agent-written code.
- **Commit convention:** never bundle everything into one commit. Each commit
  is one discrete task, message formatted `[category]: message`, category
  lowercase (`feat`, `fix`, `refactor`, `style`, `chore`, `test`, `docs`),
  **message always in English** even though the team communicates in
  Portuguese. Example: `[feat]: add Pix payment method decorator`.

## Data model: Pokémon TCG on Solidus's native mechanisms

Deliberately reusing Solidus's built-in mechanisms instead of custom tables —
an agent is less likely to get a well-known API wrong than a bespoke schema.

| Concept | Solidus mechanism |
|---|---|
| Card / product | `Spree::Product` (one product per card or sealed item) |
| Set | `Spree::Taxonomy` "Set" + one `Spree::Taxon` per set |
| Rarity, card number | `Spree::Property` + `Spree::ProductProperty` (`rarity`, `card_number`) |
| Condition (NM/LP/MP/HP/DMG) | `Spree::OptionType` "condition" — a real variant axis (distinct SKU/price/stock) |
| Language (EN/JP/PT-BR) | `Spree::OptionType` "language" — variant axis when it affects SKU |
| Grading (future: PSA/BGS) | `Spree::OptionType` "grading" — modeled since Fase 1, not yet used on any product |
| SKU | `Spree::Variant#sku` |
| Country of origin (import duty) | `country_of_origin` column on `spree_products` — **product-level, not variant-level** (a whole set/print run shares one origin) |

Stock: native `Spree::StockLocation`/`Spree::StockItem` are enough for a
single-warehouse operation.

Seeded via `db/seeds/catalog.rb` (idempotent, safe to re-run) — currently 8
illustrative sample products across 3 real sets (Obsidian Flames, 151, Paldea
Evolved). **This is demo/dev data, not a real catalog** — replace with a real
import when the business has one.

## Payment (Fase 2 — not started)

**Decision: start with `solidus_stripe` (official gem, Payment Intents) for
cards, add Pix/Boleto on top.** Do *not* build a custom Pagar.me/Mercado Pago
gateway from scratch first — that's real payment-handling code (idempotency,
webhook signatures, partial refunds) written by agents with no Solidus
reference implementation to pattern-match against, exactly the kind of code
most likely to have expensive bugs (double charges, webhook races).

- `Spree::PaymentMethod::StripePaymentIntents` created via seed
  (`Spree::PaymentMethod.create!`), not the admin UI — reproducible per
  environment.
- Pix/Boleto: no ready-made partial in Solidus. Build additional subclasses
  (`Spree::PaymentMethod::StripePix`, `...::StripeBoleto`) reusing the same
  gateway logic with different `payment_method_types` + their own checkout
  partials — additive, doesn't touch `solidus_stripe` internals.
- Stripe webhooks → enqueue a Sidekiq job to process the state transition;
  never write directly in the webhook controller (retries would double-process).
- **Revisit only if data justifies it:** if Pix/Boleto dominate volume (likely
  in Brazil) and Stripe's BR fees become a real problem, consider a custom
  Pagar.me/Mercado Pago gateway as a Fase 6+ initiative — don't build both
  paths upfront.

## Freight (Fase 3 — not started)

No maintained gem exists for Correios/Melhor Envio on current Solidus (the
Spree-era ones are stale). **Start with Melhor Envio only** (aggregates
Correios + private carriers behind one API, free rate-shopping) — add Correios
directly later only if needed.

- New class extending `Spree::ShippingCalculator`, implementing
  `compute_package`, registered in
  `Spree::Config.environment.calculators.shipping_methods`.
- Credentials via `Rails.application.credentials`, never a loose ENV var or a
  custom settings table.
- Synchronous call during checkout (customer needs to see freight before
  paying), but with an aggressive timeout + a Redis-cached rate fallback per
  weight bracket/CEP, so a slow carrier API never blocks checkout.

## Import duty / landed cost (Fase 3 — not started)

The highest financial-risk piece — the only money logic that doesn't reuse
Solidus's existing adjustment plumbing directly (unlike payment/freight).

- Model as its own concept: `Spree::ImportDutyRate` (country of origin →
  percentage). **Do not** reuse `Spree::TaxRate` — import duty is
  origin-based, not destination/zone-based like Solidus's native tax system
  assumes; forcing it into `TaxRate` would mean fake zone modeling.
- Custom calculator (`app/overrides/.../import_duty_calculator.rb`) mirroring
  how `Spree::Calculator::DefaultTax` works, applied as a per-item
  `Spree::Adjustment` — so it flows into `order.total` correctly, shows
  separately in cart/checkout/admin, and survives native recalculation
  (`OrderUpdater#update_adjustment_total`).
- Needs the most rigorous test coverage in the system: single item, multi-item
  cart with mixed origins, zero-rate country, promotion stacking with duty,
  partial refund correctly reversing duty.

## Admin & monetary flow (Fase 4 — not started)

**Native, build nothing:** order listing filtered by payment/shipment state,
capture/refund/void per order, `Spree::RefundReason`, store credits.

**Needs custom work:**
- Daily/monthly cash-flow dashboard (`Spree::Admin::CashFlowController`
  aggregating `Spree::Payment`/`Spree::Refund` by day/method).
- Import duty collected report (sum of `Spree::Adjustment` filtered by the
  `ImportDuty` source type) for accounting reconciliation.
- CSV export of both, reusing solidus_backend's existing order-export pattern.

Scope proportionally: "good-enough dashboards + CSV" for a single-owner store,
not a full BI system.

## Background jobs — Sidekiq + Redis (Fase 2+)

Queues: `critical` (payment webhooks, order confirmation), `default` (Melhor
Envio label purchase post-payment, mailers), `low` (report/cache warmers).
Sidekiq Web UI mounted at `/admin/sidekiq`, behind the same Devise admin auth.

## Testing strategy

RSpec + FactoryBot + `solidus_dev_support` (reuse Solidus's own factories —
don't reinvent them). Capybara for checkout system specs. WebMock/VCR so tests
**never** hit a real external API.

**Mandatory coverage before merge, once those phases start:**
1. `app/overrides/**/calculator/**` (import duty) — highest rigor.
2. `app/overrides/**/payment_method/**` + webhooks — every state transition,
   idempotent duplicate-webhook handling.
3. `app/overrides/**/shipping_calculator/**` — stubbed carrier responses,
   including the timeout/fallback path.
4. Anything touching `Spree::StockItem`/`Spree::StockLocation` — no
   overselling under concurrency.
5. One system spec per payment method (card, Pix, boleto): address → shipping
   → payment → confirmation, asserting the final `order.total`.

CI (GitHub Actions, `.github/workflows/ci.yml` running `bin/ci`) is the quality
gate — green is the practical substitute for manual line-by-line review of
agent-written code.

## Deploy — Kamal 2, single VPS (Fase 5 — not started)

| Service | Role |
|---|---|
| `web` | Puma (store+admin+API), behind `kamal-proxy` (automatic Let's Encrypt TLS, zero-downtime deploys) |
| `worker` | same image, `cmd: bundle exec sidekiq` |
| `db` (accessory) | Postgres 18, persistent volume |
| `redis` (accessory) | Redis, persistent volume |

One VPS (4vCPU/8GB is plenty for a niche store) — scale vertically before
considering multiple servers. Config already scaffolded in
`config/deploy.yml`, pointing at ghcr.io — real VPS IP/domain still need to be
filled in before a real deploy. Don't forget scheduled `pg_dump` backups to
S3-compatible storage before going live.

## i18n

`pt-BR` is the default and only active locale. Never hardcode user-facing
strings — always go through `config/locales/pt-BR/*.yml`, split by domain
(`storefront.yml`, `checkout.yml`, `admin.yml`, `general.yml`,
`spree_overrides.yml` for gem-owned Solidus strings that need a Portuguese
override). See `config/application.rb` for the fallback wiring — pay attention
to the comment there, it documents a real gotcha (see "Environment gotchas"
below).

## Visual identity (storefront only — admin keeps Solidus's default skin)

- **Typography:** headings/product names → "Vintage" (dafont.com) — **not
  wired in yet**: dafont lists it as free for personal use only, and this is a
  commercial store. Currently a Georgia placeholder
  (`--font-heading` in `app/assets/stylesheets/application.tailwind.css`).
  Descriptions/prices/specs → Compagnon (Velvetyne, OFL-style, commercial-safe,
  `--font-body`). General UI/footer → Courier Prime (Google Fonts, OFL,
  `--font-ui`). Font files live in `app/assets/fonts/`.
- **Palette:** background `#f4eee8`, dark text `#151413`, accents yellow
  `#F5D463` / blue `#79C8E7` / pink `#FB7A98` (chosen as the primary CTA
  color) / green `#78E48C`. Pastel mood referencing the YouTube channel
  @Cactocoquetel. All defined as `@theme` vars in
  `app/assets/stylesheets/application.tailwind.css`.
- **Brand graphic motif:** logo/banner elements always tripled and stacked,
  offset by 13px on both X and Y axes. **No logo/banner assets exist yet** —
  header currently uses a plain text wordmark. A separate tool to help
  generate on-brand graphic assets is a deferred future idea, out of scope for
  this project.

## Environment gotchas (don't "fix" these back to the obvious approach)

A few things in this codebase look unusual and exist for specific, verified
reasons — worth understanding before changing them:

- **`bin/setup` copies a `libsass.<dlext>` file into `lib/sassc/`.** The
  `sassc` gem's FFI loader expects the compiled extension next to
  `lib/sassc/native.rb`, but Bundler's extension cache (used because gems are
  vendored into `vendor/bundle` via `bundle config set --local path`) builds it
  under `vendor/bundle/.../extensions/` instead. Without this copy, anything
  touching `solidus_backend`'s Sprockets/Sass admin assets fails to boot.
- **`config.assets.css_compressor = nil` in `config/application.rb`.**
  `sassc-rails` auto-sets this to `:sass` in any non-development environment,
  which makes Sprockets try to run our already-built Tailwind v4 CSS through
  the legacy libsass compressor — it can't parse modern CSS (range media
  queries, relative color syntax) and breaks every page in test/production.
- **`config/tailwind.config.js` doesn't exist — everything is in `@theme`
  blocks in `application.tailwind.css`.** `tailwindcss-ruby` only ships v4
  binaries now (no v3 release left on RubyGems), and this binary build can't
  load a JS config at all (tried both the `-c` CLI flag and the `@config`
  at-rule — both hit a "missing babel.cjs" bug). If you need new design tokens,
  add them as native `@theme` vars, not a JS config.
- **`bin/ci` explicitly runs `bin/rails tailwindcss:build` as its own step**
  rather than relying on whatever Rake-task enhancement builds it for local
  `bundle exec rspec` runs — that enhancement didn't fire reliably on a fresh
  CI checkout (`app/assets/builds/tailwind.css` is gitignored build output).
- **System specs (`spec/system/**`) are excluded from CI** — no browser driver
  is set up yet, and their `before(:suite)` hook also hits the sassc/libsass
  issue via `Rails.application.precompiled_assets`. Real setup work for a
  later phase, not fixed yet.
- **`config.i18n.fallbacks` is an explicit hash (`{"pt-BR" => [:en]}`), not
  `true`.** `true` would fall back to `default_locale`, which *is* pt-BR here
  — a no-op. Also, `Spree.i18n_available_locales` (solidus_core) filters
  `I18n.available_locales` down to whichever locales have a translation for
  `spree.i18n.this_file_language` — that key is set in
  `config/locales/pt-BR/general.yml` and is load-bearing, not decorative:
  without it, Solidus's own `set_user_language` before_action silently drops
  pt-BR and `I18n.locale` reads back inconsistently.
- **One pending spec**: `spec/requests/checkouts_spec.rb`'s GatewayError test
  is marked `pending`. The mocked `Spree::OrderUpdater` call sequence it
  expects doesn't match solidus_core 4.7.1's actual `Spree::Order#complete`
  internals (version drift from whatever Solidus release
  `solidus_starter_frontend` was authored against). Revisit once Fase 2/3
  build real payment/checkout system specs.
- **Local dev requires `libvips`** (system package, not a gem) for Solidus's
  image variant styles. If image rendering 500s locally with an
  `ImageProcessing::Error` or a glibc version mismatch from `vips
  --version`, that's a system package problem, not application code.

## Phase status

- ✅ **Fase 0 — Foundation.** Rails 8 + Solidus 4.7.1 + starter frontend
  installed, Postgres/Redis via Docker locally, RSpec/FactoryBot/CI working,
  Kamal config scaffolded (not yet deployed anywhere real), brand fonts
  installed (Vintage license pending), repo public on GitHub with CI green.
- ✅ **Fase 1 — Catalog & visual identity.** Tailwind migrated to native
  `@theme` (v4), Ocico Store palette/fonts applied across storefront, Solidus
  community branding removed, catalog data model seeded (option
  types/properties/Set taxonomy/8 sample products), Set-based nav and a new
  condition filter implemented, currency fixed to BRL throughout.
- ⬜ **Fase 2 — Checkout & payment.** `solidus_stripe` + Pix/Boleto subclasses,
  webhook processing via Sidekiq, payment system specs.
- ⬜ **Fase 3 — Freight & import duty.** Melhor Envio calculator,
  `ImportDutyRate` + calculator + adjustment, end-to-end order-total specs.
- ⬜ **Fase 4 — Admin & monetary reporting.** Cash-flow dashboard, import duty
  report, CSV exports.
- ⬜ **Fase 5 — Production deploy.** Real Kamal deploy, domain, TLS, backups,
  load test, real-money validation transaction per payment method.
- ⬜ **Fase 6+ (post-launch, data-driven).** Custom Pagar.me/Mercado Pago
  gateway only if justified by real fee/volume data; graded-card (PSA/BGS)
  variants; marketplace integrations; the deferred brand-asset-generation
  tool idea.
