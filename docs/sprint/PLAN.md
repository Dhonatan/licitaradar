# Bootstrap sprint — day-by-day plan

Sprint 1 goal: by **Sunday, Nov 22, 2026** LicitaRadar is a working product: it syncs open tenders
from the PNCP, lets anyone search them, lets users save searches and receive a daily
e-mail digest, exposes a JSON API for the future React portal, and is ready to deploy.

Each day is executed in one working session. Rules for every session:

1. `git pull --rebase origin main` first (CI may have committed `Gemfile.lock`/`db/schema.rb`).
2. Check the latest CI run on `main`. If it is red, **fixing it is the first task of the day**.
3. Work through the day's tasks in order. Make **small commits** (one logical change each,
   roughly 4–10 per day), each with tests where it makes sense.
4. Run `ruby bin/test-lib` before every push. Push, then check CI; fix until green.
5. Tick the boxes below and append an entry to `docs/sprint/LOG.md`: what was done,
   commits, CI status, decisions, open problems.
6. If a task is too big, finish what is solid, leave a clear note in the log and move the
   rest to the next day — never push half-broken code to `main`.

Default niche presets (configurable later): **Marketing & comunicação**, **Eventos**,
**Tecnologia da informação**.

---

## Day 0 — Tue, Nov 17 ✅ (manual session)

- [x] Rails 8.1 skeleton (hand-written: no generators available in the sandbox)
- [x] `lib/pncp`: client, normalizer, CPF scrubber, modalities + 38 lib tests
- [x] CI: lib tests, Rails tests (Postgres), RuboCop (non-blocking), Brakeman
- [x] README, LICENSE (MIT), ROADMAP, this plan, docs/DEVELOPMENT.md

## Day 1 — Wed, Nov 18 · Persistence + sync ✅

- [x] Make sure the first CI run is green and `Gemfile.lock` was committed by the bot; fix anything red.
- [x] Fix RuboCop offenses and make the `lint` job blocking (remove `continue-on-error`).
- [x] Migration `create_tenders` with every attribute produced by `Pncp::TenderNormalizer`
      (string/integer/decimal(15,4)/datetime/boolean), `raw jsonb`, `last_seen_at`,
      unique index on `pncp_control_number`, indexes on `proposals_close_at`, `state`,
      `modality_id`, `status_id`.
- [x] Generated column `searchable tsvector` =
      `to_tsvector('portuguese', coalesce(object_description,'') || ' ' || coalesce(additional_info,'') || ' ' || coalesce(agency_name,'') || ' ' || coalesce(unit_name,''))`
      stored, with a GIN index.
- [x] Model `Tender`: validations, scopes `open_for_proposals` (status 1 and close_at in the future),
      `closing_within(days)`, `in_state`, `of_modality`, `value_between`.
- [x] Migration + model `SyncRun` (modality_id, started_at, finished_at, status enum
      running/succeeded/failed, pages, fetched_count, upserted_count, error_message).
- [x] Service `Tenders::Sync` (app/services): for each modality in `Pncp::Modalities::COMPETITIVE`,
      walk `Pncp::Client#each_open_tender(until_date: Date.current + 120)`, normalize, collect,
      `Tender.upsert_all` in batches of 200 (unique_by pncp_control_number), set `last_seen_at`,
      record a `SyncRun`. Skip `Pncp::InvalidRecord` (count it). One failing modality must not
      abort the others.
- [x] `SyncOpenTendersJob` (ActiveJob) wrapping the service; rake task `pncp:sync`.
- [x] Tests: model scopes, sync service with WebMock stubs built from the fixtures
      (idempotency: running twice keeps 3 tenders and updates changed fields; failure is
      recorded in SyncRun).

## Day 2 — Thu, Nov 19 · Search + public UI ✅

- [x] `Tenders::Search` query object: `q` (uses `websearch_to_tsquery('portuguese', q)` and
      ranks with `ts_rank`), filters `states[]`, `modality_ids[]`, `min_value`, `max_value`,
      `closing_within`, `niche`; sort by relevance, closing date or value.
- [x] Niche presets in `config/niches.yml` (name, slug, include keywords, exclude keywords)
      + `Niche` PORO loader; a niche expands into an OR query.
- [x] `TendersController#index` (search form + results, simple offset pagination 25/page,
      Turbo Frame for results) and `#show` (all details, links to PNCP and origin system,
      countdown to deadline).
- [x] Home page becomes the search entry point (search box + niche shortcuts + stats:
      open tenders, closing this week, last sync time).
- [x] View helpers: BRL currency, deadline badges ("encerra em 3 dias"), "valor sigiloso" when 0/nil.
- [x] Seeds (`db/seeds.rb`) with ~30 fictional tenders so the UI works offline.
- [x] Tests: search query object (keywords with accents, filters, niche), controller tests.

## Day 3 — Fri, Nov 20 · Accounts + saved searches ✅

- [x] Authentication the Rails 8 way (hand-written equivalent of `bin/rails generate authentication`):
      `User` (email_address, password_digest), `Session`, `Authentication` concern,
      sessions + passwords controllers, password reset mailer. Rate-limit login.
- [x] Sign-up page.
- [x] `SavedSearch` (user, name, query, filters jsonb, niche slug, active, notify_daily,
      last_notified_at) + CRUD UI; "Salvar esta busca" button on the results page.
- [x] `SavedSearches::Matcher`: tenders matching a saved search **published or updated since
      last notification**, reusing `Tenders::Search`.
- [x] `Notification` (saved_search, tender, sent_at) with unique index to avoid duplicate alerts.
- [x] Tests: auth flows, saved search CRUD, matcher (new vs already notified).

## Day 4 — Sat, Nov 21 · Alerts + API ✅

- [x] `DigestMailer#daily` (HTML + text): grouped by saved search, top 20 per search,
      deadline and value, links to the tender page; unsubscribe link (signed token).
- [x] `SendDailyDigestsJob`: for every user with active searches, build matches, send one
      e-mail, create `Notification` rows, update `last_notified_at`.
- [x] Solid Queue (single database setup via migration) and `config/recurring.yml`:
      sync every 6 hours, digest daily at 07:00 (Brasília).
- [x] JSON API v1: `GET /api/v1/tenders` (same filters as the UI, paginated, JSON with
      metadata), `GET /api/v1/tenders/:id`, `GET/POST/DELETE /api/v1/saved_searches`;
      bearer-token auth via `ApiToken` model (hashed token, last_used_at).
- [x] `docs/API.md` with examples (curl).
- [x] Tests: mailer previews + tests, digest job, API request tests (auth, filters, errors).

## Day 5 — Sun, Nov 22 · Hardening + release ✅

- [x] Error handling: sync retries/alerting in SyncRun, friendly 404/500 pages.
- [x] Performance: verify indexes used by search (EXPLAIN in a test or doc), N+1 checks.
- [x] `Dockerfile` (multi-stage, production), `bin/docker-entrypoint`, `.dockerignore`,
      deploy guide `docs/DEPLOY.md` (Render/Fly/Kamal, required env vars, scheduler).
- [x] Admin status page `/status` (last sync per modality, counts) protected by basic auth env vars.
- [x] README polish: features, screenshots placeholder section, architecture diagram (Mermaid).
- [x] Update `ROADMAP.md`, write `CHANGELOG.md` (v0.1.0), open GitHub issues for the
      Phase 2 React portal and the backlog.
- [x] **Final report** in `docs/sprint/REPORT.md`: what exists, how to run it, what is
      missing, risks, and suggested next steps.

---

# Sprint 2 — Nov 25–29, 2026 · Launch readiness + engagement features

Goal: close the pre-launch gaps from `docs/sprint/REPORT.md` and add features that make
users come back (documents, watchlists, reminders, public pages, webhooks). Same working
rules as Sprint 1 (see the top of this file). The **React portal (Phase 2), paid plans,
WhatsApp/Telegram alerts and PDF indexing are intentionally out of scope** — they are the
work ahead.

Note on the PNCP "integration" API (documents and items): it lives under
`https://pncp.gov.br/api/pncp/v1` (not `/api/consulta`). Confirm the exact paths and field
names from the official manual ("Manual de Integração PNCP" / "Manual das APIs de
Consultas", e.g. via web search) before writing fixtures, and keep fixtures fictional.

## Day 6 — Wed, Nov 25 · Pre-launch hardening ✅

- [x] **E-mail confirmation (#2):** `confirmed_at` on users, signed confirmation token
      (expires in 3 days), confirmation e-mail on sign-up, resend page, banner for
      unconfirmed accounts; digests and saved-search alerts only go to confirmed users;
      e-mail change requires re-confirmation. Tests for every path.
- [x] **Error reporting (#6):** `ErrorReporting` subscriber on `Rails.error` that logs with
      context and, when `SENTRY_DSN` is set, forwards to Sentry (`sentry-ruby` +
      `sentry-rails`, disabled when the env var is missing). Document in `docs/DEPLOY.md`.
- [x] **Archive old tenders (#4):** `Tenders::Archive` service + recurring job (weekly):
      delete tenders closed more than `ARCHIVE_AFTER_DAYS` (default 180) days ago that are
      not referenced by notifications or watchlists (see Day 8 — make the query easy to
      extend), in batches; record counts in the log. Tests.
- [x] Cache the home page counters for 5 minutes (`docs/PERFORMANCE.md` note) with a test.
- [x] Close issues #2, #4, #6 in commit messages (`Closes #N`) when done.

## Day 7 — Thu, Nov 26 · Tender documents + items (long) ✅

- [x] `lib/pncp`: `Pncp::IntegrationClient` (or extend `Client` with a second base URL)
      for `GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/arquivos` (documents) and
      `.../itens` (items, paginated). Normalizers `DocumentNormalizer` and
      `ItemNormalizer` (title, type, URL, published at; item number, description,
      quantity, unit, unit/total estimated value). Lib tests with fictional fixtures.
- [x] Models `TenderDocument` and `TenderItem` (belongs_to tender, unique per sequence),
      `Tenders::FetchDetails` service + `FetchTenderDetailsJob`: fetched lazily the first
      time a tender page is opened and refreshed when the tender's `source_updated_at`
      changes; never blocks the page (Turbo Frame with a loading state).
- [x] Tender page: "Documentos do edital" list (type, title, link to PNCP) and "Itens"
      table (quantity, unit, estimated values; "sigiloso" when missing).
- [x] Include item descriptions in search: add an `items_text` column to tenders (filled
      after fetching items) and extend the generated `searchable` column — or a second
      tsvector — so searches also match items. Migration + tests that the index is used.
- [x] API v1: include `documents` and `items` in `GET /api/v1/tenders/:id`; update
      `docs/API.md`.

## Day 8 — Fri, Nov 27 · Watchlist, reminders, notes, exports ✅

- [x] **Watchlist:** "Acompanhar" button on tender pages and results (`Watch` model,
      user + tender, unique); "Minhas licitações" page sorted by deadline with status
      badges (aberta, encerra hoje, encerrada).
- [x] **Deadline reminders:** e-mail N days before the proposals deadline (user setting:
      off / 1 / 3 / 7 days, default 3), sent by a daily job, never twice for the same
      watch + deadline; if the PNCP changes the deadline, a new reminder is allowed.
- [x] **Private notes** on watched tenders (plain text, per user) with Turbo inline editing.
- [x] **Calendar feed:** per-user secret `.ics` URL (`/calendario/:token.ics`) with the
      deadlines of watched tenders; regenerate-token button. Tests for the iCalendar output.
- [x] **CSV export** of search results and of the watchlist (max 5,000 rows, streamed,
      UTF-8 with BOM so Excel opens accents correctly).
- [x] API v1: `GET/POST/DELETE /api/v1/watches`; update `docs/API.md`.

## Day 9 — Sat, Nov 28 · Public pages, SEO, stats

- [ ] **Agency pages** `/orgaos/:cnpj`: agency name, location, open tenders, totals.
      Link agency names everywhere.
- [ ] **Landing pages** per state (`/licitacoes/:uf`) and per niche (`/nichos/:slug`) with
      their open tenders, short intro text and links between them.
- [ ] **Public statistics** `/estatisticas`: open tenders and estimated value by state,
      modality and niche, closing this week, updated daily (cached), charts in plain
      HTML/CSS bars or inline SVG (no JS build).
- [ ] SEO: per-page `<title>`/meta description, canonical URLs, Open Graph tags,
      `sitemap.xml` (home, landing pages, agencies, open tenders), `robots.txt`.
- [ ] Friendly, stable tender URLs (`/licitacoes/:id-slug`) keeping old URLs working.
- [ ] Tests for every page, the sitemap and that closed tenders are not in the sitemap.

## Day 10 — Sun, Nov 29 · Webhooks, API completion, release v0.2.0

- [ ] **Webhooks:** per-user endpoints (URL + secret), event `saved_search.matches`
      sent when the digest job finds new matches (same data as the e-mail), HMAC-SHA256
      signature header, timestamp, retries with backoff (Active Job), delivery log with
      status/response code, "send test event" button, auto-disable after repeated
      failures. Block private/loopback addresses (SSRF). Docs in `docs/WEBHOOKS.md`.
- [ ] **API completion (#3):** `PATCH /api/v1/saved_searches/:id`, `GET /api/v1/niches`,
      `GET /api/v1/modalities`, `GET /api/v1/states`, list of tenders already notified
      for a search. Close #3.
- [ ] **OpenAPI 3.1 spec** `docs/openapi.yaml` describing the whole API v1 + a test that
      every API route is documented.
- [ ] Update `README.md`, `ROADMAP.md`, `CHANGELOG.md` (**v0.2.0**), close finished issues,
      open issues for what is left.
- [ ] **Sprint 2 report** in `docs/sprint/REPORT-2.md` (Brazilian Portuguese): what was
      built per day, commits, test/CI numbers, what is missing or fragile, risks, next
      steps (React portal first).
