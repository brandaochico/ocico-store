# ocico store — Architecture & Roadmap

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

## Payment (Fase 2 — card flow in place, Pix/Boleto not started)

**Decision: start with `solidus_stripe` (official gem, Payment Intents) for
cards, add Pix/Boleto on top.** Do *not* build a custom Pagar.me/Mercado Pago
gateway from scratch first — that's real payment-handling code (idempotency,
webhook signatures, partial refunds) written by agents with no Solidus
reference implementation to pattern-match against, exactly the kind of code
most likely to have expensive bugs (double charges, webhook races).

### Done

- **The gem is pinned to a `main`-branch SHA, not a released version.** The
  last release (5.0.2) is from 2023 and predates Rails 8 and Solidus 4.7;
  `main` is actively maintained and CI-tested against Solidus v4.7 on Ruby
  3.4. Re-pin deliberately when updating — don't switch to the released gem
  thinking it's newer.
- **Payment method created by seed** (`db/seeds/payment_methods.rb`), not the
  admin UI, so every environment gets the same record reproducibly. The class
  is `SolidusStripe::PaymentMethod` (the v5 rewrite), *not* the v4-era
  `Spree::PaymentMethod::StripePaymentIntents` an older plan mentioned.
  `auto_capture` is **off**: the card is authorized at checkout and captured
  when the order ships, so we never charge for stock we can't send, and Fase
  3's freight/import duty can still move the total before capture.
- **Secrets never touch the database.** The payment method's
  `preference_source` points at the `solidus_stripe_env_credentials` static
  preference registered in `config/initializers/solidus_stripe.rb`. That
  initializer reads Rails encrypted credentials first and falls back to ENV
  (`SOLIDUS_STRIPE_API_KEY`, `_PUBLISHABLE_KEY`, `_WEBHOOK_SIGNING_SECRET`).
  Same seeded row works in test and live mode; rotating a key changes no row.
  With neither source configured the seed skips the payment method entirely
  rather than creating one that can't transact — that's the state of a fresh
  clone, and it's why checkout shows no Stripe option out of the box.
- **Storefront integration is hand-wired, not generated.** `bin/rails
  generate solidus_stripe:install` was run with `--no-storefront`: its
  storefront step injects into asset files this app names differently. The
  partials, both Stimulus controllers, the vendored `@stripe/stripe-js` and
  the CSS were copied and adapted by hand (see the commit). Re-running the
  generator with storefront enabled will fail; redo it by hand.
- **Webhooks are processed asynchronously and exactly once.** See below.

### Webhooks — the part that deviates most from upstream

Upstream's `SolidusStripe::WebhooksController#create` verifies the signature
and then publishes to `Spree::Bus` **inline**, so the payment state transition
runs while Stripe waits on the HTTP response — and a slow or timed-out
response makes Stripe redeliver and run it again.

`app/overrides/stripe_webhooks_async_processing.rb` replaces the publish with
an enqueue:

- Signature verification stays in the request. An unverifiable event must
  still be rejected with a 400, and Stripe's signature tolerance is measured
  against delivery time, not against whenever a worker picks the job up.
- `ProcessStripeWebhookEventJob` re-publishes to `Spree::Bus` from the
  background, so solidus_stripe's own subscribers keep handling the event
  unchanged — only *when* they run moves.
- Idempotency is a **database guarantee**, not a check-then-act: each delivery
  claims a row in `stripe_webhook_events` (unique index on the Stripe event
  id) and the transition runs inside that row's lock. This covers duplicate
  *and* concurrent delivery — without it a redelivered `charge.refunded` can
  race past `RefundsSynchronizer`'s "already synced?" check and create the
  same `Spree::Refund` twice. A job that raises leaves `processed_at` unset so
  an Active Job retry still gets to run.

Registering the endpoint with Stripe is still to do: production URL is
`/solidus_stripe/live/webhooks`, everywhere else `/solidus_stripe/test/webhooks`
(the slug comes from the key prefix). Locally, forward with
`stripe listen --forward-to http://localhost:3000/solidus_stripe/test/webhooks`.

### Not started

- Pix/Boleto: no ready-made partial in Solidus. Build additional subclasses
  reusing the same gateway logic with different `payment_method_types` + their
  own checkout partials — additive, doesn't touch `solidus_stripe` internals.
  Note the pinned gem depends on `stripe ~> 8.0` (SDK from 2023); confirm that
  SDK version can create Pix/Boleto intents before committing to the approach.
- System specs for the full card checkout (blocked on browser driver setup,
  see "Environment gotchas").
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
  paying), but with an aggressive timeout + a cached rate fallback per weight
  bracket/CEP, so a slow carrier API never blocks checkout. Cache via
  `Rails.cache` (Solid Cache, already configured) — there is no Redis in this
  stack any more, see "Background jobs".

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

## Background jobs — Solid Queue (Fase 2+)

**Changed from the original plan, which called for Sidekiq + Redis.** The app
generated by `rails new` was already fully wired for Solid Queue — production
`queue_adapter`, a dedicated `queue` Postgres database, `config/recurring.yml`,
the Puma plugin behind `SOLID_QUEUE_IN_PUMA` — and nothing else in the app used
Redis. Adopting Sidekiq would have meant adding a datastore, a Kamal accessory
and a second process to run, to replace something already working. Redis has
since been removed from `docker-compose.yml` and `config/deploy.yml`.

Queues: `critical` (payment webhooks, order confirmation), `default` (Melhor
Envio label purchase post-payment, mailers), `low` (report/cache warmers).
`config/queue.yml` lists `"critical,*"` so workers poll payment work first.

No jobs dashboard is mounted yet. If one is wanted later, Mission Control —
Jobs is the Solid Queue equivalent of the Sidekiq Web UI the old plan
described, and belongs behind the same Devise admin auth.

## Testing strategy

RSpec + FactoryBot + `solidus_dev_support` (reuse Solidus's own factories —
don't reinvent them). Capybara for checkout system specs. WebMock/VCR so tests
**never** hit a real external API.

**Mandatory coverage before merge, once those phases start:**
1. `app/overrides/**/calculator/**` (import duty) — highest rigor.
2. `app/overrides/**/payment_method/**` + webhooks — every state transition,
   idempotent duplicate-webhook handling. **Partly done:**
   `spec/requests/stripe_webhooks_spec.rb` (verify-in-request, work-in-job,
   400 on bad/stale signature) and
   `spec/jobs/process_stripe_webhook_event_job_spec.rb` (publishes, records,
   idempotent on redelivery, unprocessed after a raise). Still missing: the
   per-payment-method checkout system specs in item 5.
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
| `db` (accessory) | Postgres 18, persistent volume |

No separate `worker` service: Solid Queue's supervisor runs inside Puma via
`SOLID_QUEUE_IN_PUMA` (already set in `config/deploy.yml`). Split jobs onto
their own machine before adding a second web server, not before.

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

- **Typography:** headings/product names → **Vintage** (dafont), the owner's
  pick, `--font-heading`. Two things about it are load-bearing and were decided
  with the tradeoffs on the table, not overlooked:

  - **Licence.** dafont distributes Vintage as free for *personal* use, and this
    is a commercial store. The owner chose it anyway, knowing that. What the
    repo does *not* do is redistribute it: the binary is gitignored, because
    this repo is public and publishing the file is a separate act from using it.
    Each machine places `app/assets/fonts/vintage/Vintage-Regular.ttf` by hand —
    see the README there.
  - **It doesn't cover Portuguese.** Vintage maps 134 characters and lacks
    `à â ã ç ê ô õ`, `À Â Ã Ê Ô Õ` and the em dash. It carries no tilde or
    circumflex mark either, so the missing glyphs can't be composed from what's
    in the file. Portuguese headings fall through per glyph to the next font in
    the stack.

  That is why **Modak** (Ek Type, OFL) stays in the tree as the fallback:
  `--font-heading: Vintage, Modak, Georgia, serif`. Modak is in the same
  register — heavy round display — so `Condição` mixes two display faces rather
  than a display face and a book serif, which is markedly less jarring (there's
  a rendered comparison in the commit that introduced it). Modak also means a
  fresh clone and CI, which have no Vintage binary, still render headings in a
  display face instead of Georgia.

  **Both faces are single-weight** — don't pair `font-heading` with
  `font-semibold`/`font-bold`, or the browser synthesises a fake bold on an
  already very heavy face.

  Descriptions/prices/specs → Compagnon (Velvetyne, OFL-style, commercial-safe,
  `--font-body`). General UI/footer → Courier Prime (Google Fonts, OFL,
  `--font-ui`). Font files live in `app/assets/fonts/`, one directory per
  family, each with its license file alongside.
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
  touching `solidus_backend`'s Sprockets/Sass admin assets fails to boot —
  a fresh clone dies at `bin/rails db:prepare` with a
  `Bundler::GemRequireError` on `sassc/libsass.so`. (This step was silently a
  no-op until 2026-09-25: it globbed the *destination file*, which by
  definition doesn't exist yet, so the copy never ran. It globs the
  destination directory now.)

- **If specs fail inside `stylesheet_link_tag "tailwind"` with an
  `ExecJS::RuntimeError`, the JS runtime is the problem, not the app.**
  Rendering the storefront layout in the test environment makes Sprockets
  reach for a JavaScript runtime, and ExecJS picks the first one it finds on
  `PATH` — which on a machine with a `proto`/`mise` shim is Bun. If no Bun
  version is pinned, that shim exits with
  `proto::detect::failed` and every page render 500s.

  It looks like flakiness because the compiled asset is cached: plain
  `bundle exec rspec` passes on a warm cache, and only fails after something
  rewrites `app/assets/builds/tailwind.css` — which `bin/ci` does in its
  "Build assets" step, so `bin/ci` fails and a bare spec run doesn't, and a
  different spec fails each time depending on which renders the layout first.
  Confirm with `bundle exec ruby -e 'require "execjs"; puts ExecJS.runtime.name'`
  and work around it with `EXECJS_RUNTIME=Node`. GitHub Actions is unaffected:
  no proto shim there, so ExecJS finds Node.

- **`@custom-variant dark (&:where(.dark, .dark *))` in the stylesheet is
  load-bearing.** The storefront's theme is class-based: an inline script in
  the layout reads `localStorage` and puts `light`/`dark` on `<html>`, and
  `theme_switcher_controller.js` flips it. Tailwind v4 defaults `dark:` to
  `@media (prefers-color-scheme: dark)` instead, and the v3 config that
  declared `darkMode: 'class'` was dropped in the v4 migration (2b09a98) with
  nothing replacing it — so for a while anyone on a dark-themed OS got a black
  storefront they could not turn off, and the toggle was inert because it only
  touched a class no rule matched. Don't remove that line, and don't "simplify"
  it back to the media query: the brand is a light one and the OS preference is
  deliberately not consulted.

- **`config/importmap.rb` is load-bearing; the storefront has two JS
  pipelines.** Sprockets (`javascript_include_tag 'solidus_starter_frontend'`)
  serves the legacy `utils`/`checkout`/`product` scripts; importmap +
  Propshaft serve everything under `app/javascript` — every Stimulus
  controller, including checkout payment and the Stripe ones. They're
  complementary, not alternatives. Without `config/importmap.rb` the map
  resolves to `{"imports":{}}` and *all* Stimulus controllers become dead code
  in the browser with no error anywhere in Rails. Assets under
  `vendor/javascript` (where `bin/importmap pin --download` puts packages)
  must also be declared in
  `app/assets/config/solidus_starter_frontend_manifest.js`, because
  sprockets-rails — not Propshaft — resolves the digest paths in this app.

- **Engine-copied migrations are excluded from rubocop** (`db/migrate/*.*.rb`
  in `.rubocop.yml`). Files named `<timestamp>_<name>.<engine>.rb` are verbatim
  copies made by `railties:install:migrations` and must stay byte-identical to
  the engine's own — same rationale as `db/schema.rb`.

- **`config/credentials.yml.enc` can't be decrypted right now.** It's committed
  but `config/master.key` isn't (correctly — it's gitignored), and no copy is
  available on the current machine, so `Rails.application.credentials` reads
  back as empty rather than raising. Anything that needs a secret currently
  goes through ENV; the Stripe initializer supports both. Resolving this is a
  prerequisite for Fase 5 (`RAILS_MASTER_KEY` is already listed in
  `config/deploy.yml`'s secrets). Either recover the key or regenerate the
  credentials pair — regenerating discards whatever the current file holds
  (probably just `secret_key_base`, but that can't be confirmed without the
  key).
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
  installed, Postgres via Docker locally, RSpec/FactoryBot/CI working,
  Kamal config scaffolded (not yet deployed anywhere real), brand fonts
  installed, repo public on GitHub with CI green.
- ✅ **Fase 1 — Catalog & visual identity.** Tailwind migrated to native
  `@theme` (v4), ocico store palette/fonts applied across storefront, Solidus
  community branding removed, catalog data model seeded (option
  types/properties/Set taxonomy/8 sample products), Set-based nav and a new
  condition filter implemented, currency fixed to BRL throughout.

  **Re-verified in a browser afterwards, and it did not hold up the first
  time.** The phase had been signed off while every Stimulus controller was
  dead in the browser (see the importmap gotcha), so a lot of it had never
  actually run. The sweep found and fixed: dark mode ignoring its own toggle;
  headings rendering in Tailwind's default serif rather than the brand face;
  `text-h2.5`, `text-body-20`, `text-body-2xs` and `lg:grid-container` silently
  generating no rule at all (the home page's call-to-action headline was
  rendering at 16px); Tailwind classes sitting in a `style` attribute; two
  dark-mode contrast bugs; the accent colour still being Tailwind red rather
  than the brand pink, with the CTA failing WCAG AA at 2.52:1; and 92 gem
  translation keys plus 10 hardcoded strings still in English.

  The lesson worth carrying: "the CSS is written" and "the page looks right"
  are different claims, and only the second one matters. Check the second.
- 🟡 **Fase 2 — Checkout & payment (in progress).**
  Done: `solidus_stripe` installed (pinned to a `main` SHA) and mounted,
  storefront checkout UI hand-wired, payment method seeded with
  authorize-then-capture, webhook processing moved off the request into
  `ProcessStripeWebhookEventJob` with exactly-once delivery guaranteed by a
  unique index, request + job specs green.
  Left: real Stripe credentials (nothing can transact without them — see the
  credentials gotcha), registering the webhook endpoint in the Stripe
  dashboard, Pix/Boleto payment method subclasses, and the end-to-end checkout
  system specs (blocked on browser driver setup).
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
