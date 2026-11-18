# ocico store — Architecture & Roadmap

This is the durable reference for *why* this project is built the way it is, and
*what's left*. It's meant to survive across sessions/agents/machines — unlike
chat history or any single assistant's private memory, this file ships with the
repo. Keep it up to date as phases complete or decisions change.

## What this is

A Pokémon TCG e-commerce store (singles, sealed product, future graded cards)
for the Brazilian market: web storefront, admin with inventory control, payment,
freight calculation, landed cost of imported stock (product is imported from
JP/US; the store pays the import duty, the customer never sees it), and
monetary flow reporting. Storefront and admin live in the same
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
| **Origem** (country of origin *and* language) | `Spree::Taxonomy` "Origem" + one taxon per country, flag emoji after the name |
| **Tipo** (Booster Box, ETB, …, Cartas Avulsas) | `Spree::Taxonomy` "Tipo" + one taxon per format |
| **Coleções** (the set) | `Spree::Taxonomy` "Coleções" + one taxon per set, ordered by `released_on` |
| Rarity, card number | `Spree::Property` + `Spree::ProductProperty` (`rarity`, `card_number`) |
| Condition (NM/LP/MP/HP/DMG) | `Spree::OptionType` "condition" — a real variant axis (distinct SKU/price/stock) |
| Grading (future: PSA/BGS) | `Spree::OptionType` "grading" — modeled since Fase 1, not yet used on any product |
| SKU | `Spree::Variant#sku` |
| Country of origin (import duty) | `country_of_origin` column on `spree_products`, **derived from the Origem taxon** — product-level, not variant-level |

Those three taxonomies are the whole navigation: the header lists them (see
"Storefront navigation" below) and the search sidebar filters by them.

**Two things here replaced an earlier model and should not be reintroduced:**

- There is no `language` option type any more. In the TCG the printing origin
  decides the language, so keeping both meant two places to get the same fact
  wrong; Origem is the single source, and `country_of_origin` derives from it
  rather than being entered separately.
- There is no "Set" taxonomy. It was renamed to "Coleções" in place, so
  existing taxon/product links survived.

`spree_taxons` gained a nullable `released_on` date. Taxons otherwise carry
only a manual position, and the header needs "the seven most recent
collections" to mean something real. It is meaningless for the Origem and Tipo
taxonomies, hence nullable.

Stock: native `Spree::StockLocation`/`Spree::StockItem` are enough for a
single-warehouse operation.

Seeded via `db/seeds/catalog.rb` (idempotent, safe to re-run): the six origins,
the seven types, and thirteen collections — the ten actually stocked, plus
Paldea Evolved, Obsidian Flames and 151, which are kept only because the eight
sample products are real cards from them and remapping them would mean
inventing card numbers. **All of that last group is demo data** and goes
together when a real catalog import lands.

## Brazilian addresses

Solidus' address is two free-form lines; Brazilian addresses (and Correios,
Boleto, Melhor Envio) want street, **number** and **neighbourhood (bairro)**
separately, plus an 8-digit **CEP**. So `spree_addresses` gained
`street_number` and `neighborhood`; `address1` is the street, `address2` the
optional complement.

- Rules live in `app/overrides/brazilian_address.rb` and apply to **BR
  addresses only**: number and neighbourhood required, CEP normalised to
  `00000-000` and validated. Other countries keep Solidus' stock rules — the
  inherited spec suite (and Solidus' factories) build US addresses.
  Its callbacks are registered by method name on purpose: **deface loads every
  file in `app/overrides` a second time**, and only symbol callbacks are
  deduplicated (`validates ...` would register each rule twice).
- Checkout form (`checkouts/steps/address_step/_address_inputs`) follows the
  Brazilian order with CEP first; `address_lookup_controller.js` masks it and
  fills street/neighbourhood/city/state from ViaCEP (called from the browser;
  on failure the customer just types).
- Both admins' address forms carry the two fields: the classic admin through
  copies of `spree/admin/shared/_address_form` / `_address` in `app/views`,
  solidus_admin through `OcicoAdmin::AddressFormComponent` registered in
  `config/initializers/solidus_admin.rb`. Re-check both copies when bumping
  solidus_backend/solidus_admin.
- Permitted params: `config/initializers/brazilian_address.rb`.

## Storefront navigation

The header carries four entries, and the search sidebar the same three
dimensions as combinable checkbox filters:

    País ▾ · Cartas Avulsas · Produtos ▾ · Coleções ▾

- **País, Produtos, Coleções** are dropdowns: hover opens them, a click *pins*
  one open until a click lands outside. That pinning is the whole reason
  `nav_dropdown_controller.js` keeps a `pinned` flag — otherwise moving the
  pointer away would close a menu the user deliberately clicked open.
- **Cartas Avulsas** is a plain link and closes the row: it is a product type
  like the others in the data, but a single destination rather than a group.
- **Coleções** lists the seven most recent by `released_on` and ends in "Ver
  todas as coleções...", which goes to `/colecoes` — a page about the
  collections themselves, routed outside the taxon glob for that reason.

All three are dropdowns rather than flat links because six country names
written out in the bar overflowed into the search field at every width from
1280px up; the nav alone wanted ~940px. On `lg` the header row switches from
flex to the same twelve-column grid the page content uses, so the logo occupies
the two columns the sidebar sits under and the nav starts exactly where the
page title does.

The queries behind all of this live in `app/helpers/main_navigation_helper.rb`,
shared by header and sidebar. The sidebar's filters are in
`app/overrides/taxonomy_product_filters.rb` and use a **subquery, not a join**:
chaining two scopes onto one `joins(:taxons)` asks a single joined row to match
two different taxons at once, so combining any two filters silently returned
nothing — a failure that surfaces as "no products found" rather than an error.

## Payment (Fase 2 — cards on Stripe, Pix/Boleto on Mercado Pago)

**Decision: cards on `solidus_stripe` (official gem, Payment Intents); Pix and
Boleto on Mercado Pago's Orders API.** Do *not* build a custom *card* gateway
— that's real payment-handling code (authorize/capture, chargebacks, partial
refunds) with no Solidus reference implementation to pattern-match against,
exactly the kind of code most likely to have expensive bugs.

**Why Pix/Boleto are not on Stripe** (changed from the original plan, which
had them as Stripe subclasses): verified 2026-10, Stripe's Pix for Brazilian
accounts is **invite-only and requires 60 days of processing history**, which
doesn't fit a launch timeline; Stripe's Boleto **can't be refunded at all**;
and neither supports manual capture. Pix/Boleto are also far simpler than
cards — create a charge, wait for "paid", no capture, no chargeback — so the
custom-gateway risk that argued for Stripe mostly doesn't apply to them.
Mercado Pago was picked over Asaas/Efí/Pagar.me for: HMAC-signed webhooks,
mandatory idempotency keys, partial Pix refunds, instant Pix settlement, CPF
accepted, and a sandbox that simulates Pix approval. Cost: two providers to
reconcile in Fase 4's cash-flow report.

### Pix/Boleto — how it works (`app/models/mercado_pago/`)

- `MercadoPago::PixPaymentMethod` / `BoletoPaymentMethod` are ordinary
  `Spree::PaymentMethod` subclasses (registered and given their static
  credentials in `config/initializers/mercado_pago.rb`, seeded by
  `db/seeds/payment_methods.rb`, never offered in the admin's "new payment"
  form). `auto_capture?` is hard-wired `false`.
- **Completing the order creates the charge** (Spree's authorize step →
  `MercadoPago::Gateway#authorize` → `POST /v1/orders`) and leaves the payment
  **pending**, `payment_state: balance_due`. The QR code / boleto line is kept
  on `MercadoPago::PaymentSource` and shown on the order page. The Spree
  payment's `gateway_order_id` is the idempotency key, so a retried request
  can't create a second charge.
- **`MercadoPago::PaymentSynchronizer` is the only thing that moves money
  state.** It reads the order from the API (never trusts a webhook body) and,
  under a row lock on the still-pending payment: `processed` → capture event +
  `complete!`; `expired`/`canceled`/`failed` → `failure!` and **cancel the
  Spree order, which restocks it** (agreed: stock is held while a Pix/Boleto is
  unpaid — Pix expires in 4h, `Gateway::PIX_EXPIRATION`; Boleto in 3 days). A
  paid amount below the payment's amount leaves it pending and logs an error.
- Triggered by the webhook (`POST /webhooks/mercado_pago`: HMAC check, then
  enqueue `MercadoPago::SyncPaymentJob`, `critical` queue) and by
  `MercadoPago::SyncPendingPaymentsJob` every 15 minutes in production
  (`config/recurring.yml`) — a missed webhook delays a transition, never loses
  it.
- Void cancels the Mercado Pago order (only works while unpaid; Spree then
  falls back to a refund). Refunds use `POST /v1/orders/:id/refund` with an
  explicit amount, so partial refunds work. All of the above was exercised
  against the real sandbox, not only stubs.
- **Boleto needs a split street/number/neighbourhood address** — sent from
  the address's own `street_number`/`neighborhood` columns (see "Brazilian
  addresses"). Addresses saved before those existed fall back to parsing
  "Rua X, 123" from line 1 (else `S/N`) and line 2 as the neighbourhood (else
  `-`); Mercado Pago accepts that.

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
  when the order ships, so we never charge for stock we can't send.
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
  same `Spree::Refund` twice. A job that raises leaves `processed_at` unset
  and is retried (`retry_on`, up to 10 attempts with growing waits): Stripe
  already has its 200 and never redelivers, so the retry is the only second
  chance. An event whose payment method was deleted is dropped, not retried.

Registering the endpoint with Stripe is still to do: production URL is
`/solidus_stripe/live/webhooks`, everywhere else `/solidus_stripe/test/webhooks`
(the slug comes from the key prefix). Locally, forward with
`stripe listen --events payment_intent.succeeded,payment_intent.payment_failed,payment_intent.canceled,charge.refunded --forward-to http://localhost:3000/solidus_stripe/test/webhooks`
— current Stripe CLIs refuse to run without `--events`, and those four are the
only ones solidus_stripe subscribes to. Subscribe the production endpoint to
the same four.

### Not started

- An automated system spec for the card checkout. The flow itself was
  verified by hand against a Stripe sandbox; a spec that repeats it would
  call Stripe's real test API, so it needs test keys as CI secrets. Test cards
  that cover the interesting paths: `4242 4242 4242 4242` (approved),
  `4000 0000 0000 0002` (refused), `4000 0000 0000 9995` (insufficient funds),
  `4000 0025 0000 3155` (3D Secure challenge).
- Registering the Mercado Pago webhook (application panel → Webhooks, topic
  "Order", URL `https://<domain>/webhooks/mercado_pago`) and putting the
  generated secret in `MERCADOPAGO_WEBHOOK_SECRET` / credentials. Until then
  every notification is rejected with a 401 and only the 15-minute sweep
  syncs payments.
- **Revisit only if data justifies it:** if Stripe's BR card fees become a
  real problem, Mercado Pago can take cards too — the client, webhook and
  sync are already in place.

## Freight (Fase 3 — Melhor Envio quotes in place)

Melhor Envio quotes Correios and Jadlog at checkout (`app/models/melhor_envio/`).
No maintained gem exists: `solidus_melhor_envio` was last released in 2023 and
its repository is gone. Correios directly stays out unless Melhor Envio proves
insufficient.

**How it fits Solidus.** One `Spree::ShippingMethod` per carrier service, each
with a `MelhorEnvio::ShippingCalculator` holding the service's Melhor Envio id
(1 PAC, 2 SEDEX, 3 Jadlog .Package, 17 Mini Envios), seeded by
`db/seeds/shipping.rb`. Solidus asks each calculator separately;
`MelhorEnvio::Quote` makes **one** API call per package (CEPs + contents) and
caches it, so the four methods share it. A service that can't take the
shipment (route not served, over its declared-value or weight limit — Mini
Envios stops at R$100/300 g) answers `available? == false` and simply isn't
offered. Solidus pre-selects the cheapest.

**Fallback, so checkout never dead-ends.** "Entrega padrão" (R$20,
`MelhorEnvio::FallbackCalculator`, converted in place from the old provisional
flat rate) is offered *only* when the quote fails: timeout (3 s open / 6 s
read), dropped connection, error response, a response that can't be parsed
into prices, no token configured, or a stock location without a CEP. Freight
never turns the delivery step into a 500.
When the quote succeeds but no carrier serves the destination, nothing is
offered — a flat rate for a route nobody delivers to would sell something that
can't ship.

**Cache.** Its own in-process `MemoryStore`, not `Rails.cache` (test runs a
null store, and the quote must be shared within one estimate everywhere):
quotes with at least one price for 30 minutes; failures, and quotes in which
no carrier could take the shipment, for 1 minute — one estimate still doesn't
retry once per carrier, but "no carrier" (which can be a carrier-side outage)
doesn't dead-end checkout for that CEP for half an hour.

**What a quote is made of.**
- *From:* the stock location's CEP (admin → Estoque → Locais de estoque), the
  store's dispatch address. `db/seeds/shipping.rb` sets it to Canoas/RS
  (92020-300) only when it is blank, so a CEP entered in the admin wins; with
  none, every quote falls back.
- *To:* the order's shipping CEP.
- *Products:* one entry per variant with quantity; Melhor Envio packs them.
  Weight/dimensions come from `MelhorEnvio::PackageDimensions`: the variant's
  own `weight`/`height`/`width`/`depth` (entered in the admin **in kg and cm,
  packaging included**), then its master's, then a default by the product's
  "Tipo" taxon (a single card ships as a padded envelope at the Correios
  minimum, 16×11×2 cm/50 g; a booster box as 25×20×12 cm/1 kg). The defaults
  are estimates — weigh real products and enter them.
- *Declared value* (`insurance_value`): each item's price. It's what the
  carrier insures and what caps the services that can take it.

**Delivery time.** `spree_shipping_rates` gained `min/max_delivery_days`,
filled by `app/overrides/shipping_rate_delivery_days.rb` for calculators that
know one, and shown at the delivery step ("Entrega em 5 a 7 dias úteis").
Melhor Envio's `custom_*` values already include any extra days configured in
the Melhor Envio account (e.g. handling time).

**Credentials.** `config/initializers/melhor_envio.rb`: encrypted credentials
first (`melhor_envio: token/sandbox/contact_email`), then ENV
(`MELHOR_ENVIO_TOKEN`, `MELHOR_ENVIO_SANDBOX`, `MELHOR_ENVIO_CONTACT_EMAIL`).
The token is a personal access token from the Melhor Envio panel and only works
in the environment it came from; `sandbox` defaults to on outside production.
The contact email goes in the User-Agent, which Melhor Envio requires.

**Not done yet:** buying labels after payment (Melhor Envio's cart →
checkout → generate → print flow) and tracking — today the owner buys labels in
the Melhor Envio panel.

## Import duty / landed cost — the store pays it, so no checkout logic

**Decided by the owner on 2026-11-17:** the store imports its stock and pays the
import duty itself, then resells domestically. The customer pays the shelf
price plus freight and nothing else.

That **cancels the original plan** of an `ImportDutyRate` model and a per-item
`Spree::Adjustment` added at checkout — there is no duty in `order.total` to
calculate, show or refund. Don't build it unless the business model changes
to selling imports to order (customer as importer).

What the duty still affects is **cost**, hence margin:
- A variant's landed cost (purchase price + freight to Brazil + duty + fees,
  per unit, in BRL) goes in Solidus's native `Spree::Variant#cost_price`
  (`cost_currency` BRL). No new table.
- Pricing is the owner's call in the admin; the duty is already inside the
  price they set.
- Fase 4's reports compute margin as price − `cost_price`.
- `country_of_origin` on products stays: it documents where stock comes from,
  and a landed-cost helper (if one is ever wanted) would key on it.

## Admin & monetary flow (Fase 4 — not started)

**Native, build nothing:** order listing filtered by payment/shipment state,
capture/refund/void per order, `Spree::RefundReason`, store credits.

**Needs custom work:**
- Daily/monthly cash-flow dashboard (`Spree::Admin::CashFlowController`
  aggregating `Spree::Payment`/`Spree::Refund` by day/method).
- Margin report: revenue against landed cost (`Spree::Variant#cost_price`,
  which includes the import duty the store paid) per product/period.
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
1. Freight calculators (`app/models/melhor_envio/`) — done, see
   `spec/models/melhor_envio/`. (Import duty is no longer checkout logic: see
   "Import duty / landed cost".)
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
agent-written code. It does **not** run the system specs; see the gotcha about
them for what that costs and what it would take to include them.

The system suite itself was cut down deliberately: the fifteen specs that
exercised solidus_starter_frontend's sample storefront were deleted rather than
repaired, because they test a catalogue this store doesn't have. The thirteen
covering cart, checkout, order and the money adjustments applied along the way
were kept and fixed. New specs for this store's own flows — condition filter,
the three navigation axes, Stripe checkout — are still to write.

## Deploy — Kamal 2, single VM (Fase 5 — in progress)

| Service | Role |
|---|---|
| `web` | Puma (store+admin+API), behind `kamal-proxy` (automatic Let's Encrypt TLS, zero-downtime deploys) |
| `db` (accessory) | Postgres 18, persistent volume, bound to `127.0.0.1` only |

No separate `worker` service: Solid Queue's supervisor runs inside Puma via
`SOLID_QUEUE_IN_PUMA`. Split jobs onto their own machine before adding a
second web server, not before.

**Server:** Oracle Cloud Always Free, `VM.Standard.A1.Flex` (2 OCPU / 12 GB,
**ARM64**), Ubuntu 24.04, São Paulo, `147.15.40.125` (ephemeral public IP —
it changes if the instance is stopped and started; reserve it before go-live).
Scale vertically (the free tier allows up to 4 OCPU / 24 GB) before going
multi-server. How it was prepared, by hand, once:

- **Oracle's Ubuntu image ships an iptables firewall that rejects everything
  but SSH**, independent of the VCN Security List (which also had to allow
  TCP 80/443). `/etc/iptables/rules.v4` got an `INPUT` accept for 80/443 and
  lost its `FORWARD ... REJECT`, which would otherwise block container
  traffic. The untouched original is at `/etc/iptables/rules.v4.oracle-default`.
- **Docker installed from Docker's apt repo, `ubuntu` added to the `docker`
  group.** Kamal connects as `ubuntu` (Oracle images have no root login) and
  can't bootstrap Docker as a non-root user.
- **Images are built on the server itself** (`builder.remote` in
  `config/deploy.yml`): it's ARM, the dev machine is x86, and QEMU emulation
  is slow and fragile for native gems. Docker's remote builder uses the system
  ssh client, so the dev machine's `~/.ssh/config` maps the host to the
  `~/.ssh/ocico_deploy` key (`ssh ocico` works too).

**Secrets:** `RAILS_MASTER_KEY` comes from `config/master.key`; everything else
Kamal needs lives in the encrypted credentials under `kamal:` —
`postgres_password` (generated) and `registry_password` (a GitHub PAT with
`write:packages`, added by the owner). See `.kamal/secrets`.

**Production config** (`config/environments/production.rb`): SSL assumed and
forced (`/up` excluded so kamal-proxy's health check works over plain HTTP),
`config.hosts` limited to `APP_HOST` and its `www.`, mail links on
`https://APP_HOST`. Mail goes through SMTP when `smtp:` exists in the
credentials; until then nothing is sent. The store's `url` (seeded from
`APP_HOST`) is the host in password-reset links, so production needs
`db:seed` run with `APP_HOST` set — Kamal sets it on the container. Sender:
`store.ocico@gmail.com`.

Still to do before go-live: domain + DNS, the SMTP relay, live payment and
freight credentials, and scheduled `pg_dump` backups off the server.

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

- **`config/master.key` exists only on the owner's development machine.**
  It's gitignored (correctly), and it does decrypt `config/credentials.yml.enc`,
  which holds just `secret_key_base` (verified 2026-11-17; an earlier note here
  claimed the key was lost, which was wrong). Keep a copy in a password
  manager: losing it means production can no longer read its credentials.
  Kamal passes it as `RAILS_MASTER_KEY` (`.kamal/secrets`). Development and
  test take service keys from ENV (`.env`); production's live keys go into
  the encrypted credentials when they exist — every initializer reads
  credentials first, ENV second.
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
- **solidus_admin's CSS is built with Tailwind *v3*, not the v4 above.** Its
  stylesheet is a v3 JS-config preset with four plugins, which v4 ignores: the
  build "succeeded" while emitting ~15 KB of stray utilities, and the new admin
  rendered completely unstyled (fixed 2026-11-17). `lib/tasks/solidus_admin/tailwind.rake`
  therefore runs Tailwind's official v3.4.17 standalone CLI — pinned,
  SHA256-verified, downloaded once into `tmp/` (so the first build, locally,
  in CI and in the Docker image, needs network). Only the admin uses it; the
  storefront stays on v4. Don't point that task back at `Tailwindcss::Ruby`.
- **`bin/ci` explicitly runs `bin/rails tailwindcss:build` as its own step**
  rather than relying on whatever Rake-task enhancement builds it for local
  `bundle exec rspec` runs — that enhancement didn't fire reliably on a fresh
  CI checkout (`app/assets/builds/tailwind.css` is gitignored build output).
- **System specs (`spec/system/**`) are excluded from CI, but they do run.**
  The old claim that no browser driver was set up was wrong: the headless
  Chrome config in `spec/support/solidus_starter_frontend/capybara.rb` was
  complete all along. What actually stopped them was the ExecJS/Bun problem
  below, reached through their `before(:suite)` hook
  (`Rails.application.precompiled_assets`).

  Run them with `bundle exec rspec spec/system`. They take about seven minutes
  and four of them fail for reasons that predate the rescue (store-credit
  checkout, a `render_template` assertion that drifted from solidus_core 4.7.1,
  and two order-flow ones), so putting them in `bin/ci` means fixing those
  first. They are worth it: they caught two customer-visible bugs in one pass
  that manual checking had missed.

- **`CHROME_BIN` selects the browser Capybara drives.** Selenium takes the
  first Chrome on `PATH`, which fails with "session not created: This version
  of ChromeDriver only supports Chrome version N" on a machine whose
  chromedriver is ahead of its google-chrome. CI has a matched pair and needs
  nothing; locally, point it at the build your driver supports, e.g.
  `CHROME_BIN=/usr/bin/chromium`.
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
- **Mercado Pago sandbox uses `APP_USR-...` credentials, not `TEST-...`.**
  The Orders API rejects the classic test credentials ("Test credentials are
  not supported, use test users with production credentials"). Create a
  *test seller account* in the application panel, log in as it, create an
  application there, and use that application's **production** credentials —
  they only move fake money. Order ids in sandbox start with `ORDTST`.
  A payer first name of `APRO` makes a sandbox Pix approve itself within
  seconds; the sandbox also rejects a payer email that belongs to a real
  Mercado Pago account (`MERCADOPAGO_TEST_PAYER_EMAIL` overrides it — never
  set it in production).
- **Pix/Boleto payments don't sync by themselves in development.** Dev runs
  Active Job's async adapter, so the 15-minute sweep (Solid Queue recurring,
  production only) never runs, and the webhook needs a public URL. After
  paying in the sandbox, sync by hand:
  `bin/rails mercado_pago:sync` (it runs the syncs inline — enqueueing from
  `bin/rails runner` does nothing, the process exits before async jobs run).

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

  **Then reopened again** to rebuild the catalog around three axes instead of
  one — see "Data model" and "Storefront navigation". The old single "Set"
  taxonomy is gone, the `language` option type with it, and the search sidebar
  filters by country, type and collection. The eight sample products and the
  three collections they belong to are still demo data.
- 🟡 **Fase 2 — Checkout & payment (in progress).**
  Done: `solidus_stripe` installed (pinned to a `main` SHA) and mounted,
  storefront checkout UI hand-wired, payment method seeded with
  authorize-then-capture, webhook processing moved off the request into
  `ProcessStripeWebhookEventJob` with exactly-once delivery guaranteed by a
  unique index, request + job specs green.
  Pix and Boleto via Mercado Pago (see "Payment"): charge on order
  completion, QR code / boleto on the order page, HMAC-verified webhook +
  15-minute sweep syncing payment state, stock released on expiry, partial
  refunds — verified end to end against the sandbox.
  Cards on Stripe verified end to end against a Stripe sandbox (2026-11-17):
  authorize at checkout, capture, partial refund, refusals (generic,
  insufficient funds) and a 3D Secure challenge, with `payment_intent.*` and
  `charge.refunded` webhooks forwarded by `stripe listen` and each processed
  once. Stripe.js runs with the store's locale on both the payment and the
  confirm page, so the card form and refusal messages are in Portuguese.
  Left: registering both webhook endpoints in production (Stripe dashboard,
  Mercado Pago panel), and an automated system spec that pays with Stripe
  (needs test keys available to CI).
- ✅ **Fase 3 — Freight (import duty dropped from checkout).** Melhor Envio
  quotes per carrier with delivery times and a fallback flat rate (see
  "Freight"), verified against the Melhor Envio sandbox on 2026-11-17 (four
  carriers with prices and delivery times; a remote CEP and an R$899,90 card
  correctly leave only PAC and SEDEX), quoting from the store's dispatch CEP
  in Canoas/RS (seeded). The store pays import duty itself, so there is no
  duty calculation at checkout (see "Import duty / landed cost"). Deferred:
  buying labels through the API (labels are bought in the Melhor Envio panel
  for now).
- ⬜ **Fase 4 — Admin & monetary reporting.** Cash-flow dashboard, margin
  report against landed cost (`cost_price`), CSV exports.
- ⬜ **Fase 5 — Production deploy.** Real Kamal deploy, domain, TLS, backups,
  load test, real-money validation transaction per payment method.
- ⬜ **Fase 6+ (post-launch, data-driven).** Custom Pagar.me/Mercado Pago
  gateway only if justified by real fee/volume data; graded-card (PSA/BGS)
  variants; marketplace integrations; the deferred brand-asset-generation
  tool idea.
