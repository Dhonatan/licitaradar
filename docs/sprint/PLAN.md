# Bootstrap sprint — day-by-day plan

Goal: by **Sunday, Nov 22, 2026** LicitaRadar is a working product: it syncs open tenders
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

## Day 3 — Fri, Nov 20 · Accounts + saved searches

- [ ] Authentication the Rails 8 way (hand-written equivalent of `bin/rails generate authentication`):
      `User` (email_address, password_digest), `Session`, `Authentication` concern,
      sessions + passwords controllers, password reset mailer. Rate-limit login.
- [ ] Sign-up page.
- [ ] `SavedSearch` (user, name, query, filters jsonb, niche slug, active, notify_daily,
      last_notified_at) + CRUD UI; "Salvar esta busca" button on the results page.
- [ ] `SavedSearches::Matcher`: tenders matching a saved search **published or updated since
      last notification**, reusing `Tenders::Search`.
- [ ] `Notification` (saved_search, tender, sent_at) with unique index to avoid duplicate alerts.
- [ ] Tests: auth flows, saved search CRUD, matcher (new vs already notified).

## Day 4 — Sat, Nov 21 · Alerts + API

- [ ] `DigestMailer#daily` (HTML + text): grouped by saved search, top 20 per search,
      deadline and value, links to the tender page; unsubscribe link (signed token).
- [ ] `SendDailyDigestsJob`: for every user with active searches, build matches, send one
      e-mail, create `Notification` rows, update `last_notified_at`.
- [ ] Solid Queue (single database setup via migration) and `config/recurring.yml`:
      sync every 6 hours, digest daily at 07:00 (Brasília).
- [ ] JSON API v1: `GET /api/v1/tenders` (same filters as the UI, paginated, JSON with
      metadata), `GET /api/v1/tenders/:id`, `GET/POST/DELETE /api/v1/saved_searches`;
      bearer-token auth via `ApiToken` model (hashed token, last_used_at).
- [ ] `docs/API.md` with examples (curl).
- [ ] Tests: mailer previews + tests, digest job, API request tests (auth, filters, errors).

## Day 5 — Sun, Nov 22 · Hardening + release

- [ ] Error handling: sync retries/alerting in SyncRun, friendly 404/500 pages.
- [ ] Performance: verify indexes used by search (EXPLAIN in a test or doc), N+1 checks.
- [ ] `Dockerfile` (multi-stage, production), `bin/docker-entrypoint`, `.dockerignore`,
      deploy guide `docs/DEPLOY.md` (Render/Fly/Kamal, required env vars, scheduler).
- [ ] Admin status page `/status` (last sync per modality, counts) protected by basic auth env vars.
- [ ] README polish: features, screenshots placeholder section, architecture diagram (Mermaid).
- [ ] Update `ROADMAP.md`, write `CHANGELOG.md` (v0.1.0), open GitHub issues for the
      Phase 2 React portal and the backlog.
- [ ] **Final report** in `docs/sprint/REPORT.md`: what exists, how to run it, what is
      missing, risks, and suggested next steps.
