# Sprint log

One entry per working session, newest at the bottom.

## Day 0 — Tue, Nov 17, 2026

**Done**
- Rails 8.1 application skeleton (Postgres, Hotwire, Propshaft, import maps), home page.
- `lib/pncp`: `Client` (proposta/publicacao endpoints, pagination, retries with exponential
  backoff on 429/5xx/network errors, 204 = empty page, UTF-8 bodies), `TenderNormalizer`
  (Brasília times with offset, decimals, CNPJ digits, public PNCP URL), `PiiScrubber`
  (masks CPFs with valid check digits), `Modalities` table.
- 38 framework-independent tests (`bin/test-lib`), all green.
- CI workflow: lib tests, Rails tests on Postgres 16, RuboCop (non-blocking), Brakeman;
  the Rails job commits regenerated `Gemfile.lock` and `db/schema.rb` back to `main`.
- README, MIT license, ROADMAP, day-by-day plan, `docs/DEVELOPMENT.md`, `bin/pncp-probe`.

**Decisions**
- PNCP code is plain Ruby in `lib/pncp` (no Rails) so it is testable without a database
  and reusable.
- Search will be done in Postgres (Portuguese `tsvector`) because the API ignores keywords.
- No Node build: Hotwire + plain CSS. A React portal is Phase 2 and will use the JSON API.

**Notes**
- The cloud sandbox cannot reach rubygems.org or pncp.gov.br, so the Rails layer is
  verified by GitHub Actions and the PNCP client by unit tests with fixtures.

## Day 1 — Wed, Nov 18, 2026

**Starting point**
- CI on `main` was green (run for `fc26d88`) and the bot had already committed `Gemfile.lock`.
  RuboCop reported no offenses, so the lint job could be made blocking right away.

**Done**
- CI: RuboCop job is now blocking (`continue-on-error` removed).
- `tenders` table: every attribute produced by `Pncp::TenderNormalizer`, `raw jsonb`,
  `last_seen_at`, unique index on `pncp_control_number`, indexes on `proposals_close_at`,
  `state`, `modality_id`, `status_id`.
- Stored generated column `searchable` (`to_tsvector('portuguese', …)` over object,
  additional info, agency and unit names) with a GIN index.
- `Tender` model: validations (unique control number, known modality, 2-letter state,
  non-negative values) and scopes `open_for_proposals`, `closing_within(days)`, `in_state`,
  `of_modality`, `value_between` (blank filters are no-ops, open-ended ranges allowed);
  helpers `open_for_proposals?` and `confidential_value?`.
- `SyncRun` model (string enum running/succeeded/failed, pages, fetched/upserted/skipped
  counts, error message) with `recent` and `last_succeeded_at`.
- `Tenders::Sync` (app/services): walks `/v1/contratacoes/proposta` for each competitive
  modality (until today + 120 days), normalizes, upserts in batches of 200 by
  `pncp_control_number`, sets `last_seen_at`, records one `SyncRun` per modality. Invalid
  records are skipped and counted; a failing modality is recorded as failed (and reported
  via `Rails.error`) without stopping the others.
- `SyncOpenTendersJob` wrapping the service and `bin/rails pncp:sync` (`MODALITIES=6,8`
  to limit; prints one line per modality and exits non-zero if any failed).
- Tests: model scopes/validations, `SyncRun`, sync service with WebMock + fixtures
  (pagination, attribute mapping, idempotency with changed fields, duplicates in a batch,
  batching, skipped records, one failing modality, default modalities/horizon), job and
  rake task. Rails suite: 66 runs, 0 failures (now runs in parallel, 4 processes).

**Commits**
- `f850711` ci: make the RuboCop job blocking
- `21c2747` feat(db): create tenders table
- `57915e0` feat(db): add Portuguese full-text search column to tenders
- `14c763b` feat: add Tender model with validations and search scopes
- `6981f93` feat: add SyncRun model to audit PNCP sync passes
- `245135b` feat: add Tenders::Sync to upsert open tenders from the PNCP
- `801b844` feat: add SyncOpenTendersJob
- `ea78630` feat: add pncp:sync rake task
- plus this docs commit (plan, log, README, ROADMAP)

**CI**
- Every push green (lib tests, Rails tests, RuboCop — now blocking — and Brakeman).
  The bot regenerated `db/schema.rb` twice (`8a69153`, `d502141`).

**Decisions**
- The `raw` record is stored with CPFs masked too (deep scrub of every string), otherwise
  the LGPD masking of `additional_info` would be pointless.
- Added `skipped_count` to `SyncRun` (the plan asks to count invalid records).
- `SyncRun.status` is a string-backed enum, so the table is readable without the app.
- Records are de-duplicated by control number inside each batch: PNCP pages can shift
  while we walk them and Postgres rejects an `ON CONFLICT` batch touching a row twice.
- Page size 500 (the API maximum) to minimize round trips; configurable via `page_size:`.
- Tenders that disappear from the "proposta" endpoint are not deleted or closed; the
  `open_for_proposals` scope relies on status + deadline, and `last_seen_at` is there if
  we ever need to expire stale rows.

**Open problems / notes for next days**
- The sync has not been run against the live PNCP (blocked from the sandbox). First real
  run: `bin/rails pncp:sync` locally; if 500-record pages time out, lower `page_size`.
- The Portuguese `tsvector` does not strip accents, so "publicidade" matches "publicidade"
  but "agencia" will not match "agência". Day 2 (search with accents) should add
  `unaccent` through an immutable wrapper function and rebuild the generated column.
- No guard against two syncs running at the same time; add `limits_concurrency` when
  Solid Queue is set up (Day 4).
- Nothing moved to the next day.

## Day 2 — Thu, Nov 19, 2026

**Starting point**
- CI on `main` was green (run for `462b9a0`); no unchecked tasks from earlier days.

**Done**
- Accent-insensitive search: `tenders.searchable` rebuilt with accents folded by
  `translate()` (á→a, ç→c, …); `Tender.fold_accents` folds query text with the same table
  (a test asserts the model and migration tables stay identical). This closes the Day 1
  open problem ("agencia" vs "agência").
- Niche presets in `config/niches.yml` (Marketing & comunicação, Eventos, Tecnologia da
  informação) + `Niche` PORO: validated loader, `Niche.find(slug)`, and `#tsquery`, which
  expands the keywords into one `to_tsquery` expression — phrases as `<->` chains, keywords
  OR-ed, exclusions negated: `(a | b <-> c) & !(d)`.
- `Tenders::Search` (app/services): only tenders open for proposals; `q` with
  `websearch_to_tsquery` (phrases, `-exclusão`, `OR`) ranked by `ts_rank`; `niche`;
  `states[]`, `modality_ids[]` (arrays or comma-separated strings); `min_value`/`max_value`
  (accepts "1500", "1.500", "1.500,50", "R$ 1.500"; swapped bounds are fixed);
  `closing_within`; sort `relevance` (default with text) / `closing` (default otherwise) /
  `value` (nulls last); offset pagination 25/page (max page 400); `to_params` for links.
  Garbage params are ignored, never raise. All SQL is bound (no string interpolation).
- `TendersController#index` (search form + results in a Turbo Frame that advances the URL,
  pagination keeps filters) and `#show` (all details, countdown "Faltam 3 dias e 2 horas",
  PNCP and origin-system buttons only for http/https URLs, 404 for unknown ids).
- Home page is now the search entry point: search box, niche shortcuts, stats (open
  tenders, closing in 7 days with a link to that filter, last successful sync).
- Helpers: `brl` ("R$ 1.234,50"), `tender_value` ("Valor sigiloso" for 0/nil), Brazilian
  dates, `deadline_badge` ("encerra hoje às 18:00" / "amanhã" / "em 3 dias", urgency
  colors), `time_left`, `format_cnpj`, `agency_scope`, `external_url`.
- `db/seeds.rb`: 30 fictional tenders (8 per niche + 6 others, 2 closed, some confidential
  values), idempotent, deadlines relative to now; skipped in production unless
  `SEED_DEMO_DATA=1`.
- Plain CSS for the search form, result cards, badges and detail page (mobile-friendly).
- Tests: Niche (presets, tsquery, invalid config, every preset is valid SQL), Search
  (accents both ways, plural/stemming, web-search syntax, all fields searched, ranking,
  every filter, sorting, pagination, normalization, ActionController::Parameters),
  helpers, tenders and pages controllers, seeds (idempotent; each niche finds exactly its
  8 demo tenders). Rails suite: 121 runs, 0 failures.
- Docs: README (status, demo data, layout), ROADMAP, `docs/DEVELOPMENT.md` (search notes).

**Commits**
- `2550aec` feat(db): fold accents in the tenders search column
- `9cb86ae` feat: add niche presets loaded from config/niches.yml
- `322d283` feat: add Tenders::Search query object
- `942e182` feat: add view helpers for BRL values, deadlines and external links
- `528fda0` feat: add public tender search and detail pages
- `dd6e186` feat: make the home page the search entry point
- `21fde17` feat: seed 30 fictional tenders so the UI works offline
- `9cc1cc7` test: cast the niche tsquery check to text to silence an unknown OID warning
- plus this docs commit (plan, log, README, ROADMAP, DEVELOPMENT)

**CI**
- Every push green (lib tests, Rails tests, RuboCop, Brakeman). The bot regenerated
  `db/schema.rb` once (`f32f241`) for the new generated column.

**Decisions**
- Accent folding with `translate()` instead of `unaccent`: `unaccent()` is not immutable
  (can't be used in a generated column), and an immutable wrapper function or a custom
  text search configuration would not be kept in `db/schema.rb` — parallel test databases
  are built from it, so the search column would break there. Switching to `structure.sql`
  was the alternative; rejected to keep the schema workflow and the CI bot unchanged.
- Niches build the tsquery text in Ruby (words stripped to letters/digits, so it is always
  valid syntax) and pass it as a single bind to `to_tsquery`; this avoids building SQL by
  string interpolation.
- Search always restricts to tenders open for proposals (the product is about
  opportunities you can still bid on). Closed tenders remain reachable by direct link.
- With both `q` and `niche`, both must match and relevance is ranked by `q`.
- Order of work: accent folding and niches came before the query object because the
  search needs both; everything else followed the plan order.
- Niche keywords were checked against the Portuguese stemmer: "publicidade" alone stems
  to `public` (same as "pública"), and "tendas" stems like "tendo", so those appear only
  inside phrases. A stem-collision note is in `config/niches.yml` and DEVELOPMENT.md.
- Seeds use `example.com` origin URLs and no PNCP URL, so demo pages never link to
  non-existent PNCP pages.
- Kept the app's default locale (English validation messages); the UI strings and the
  helpers are Portuguese and do not depend on `rails-i18n` (no new gems).

**Open problems / notes for next days**
- Free-text search inherits the stemmer's collisions: searching "publicidade" also
  returns tenders that only say "pública". Possible fix later: rank exact (`simple`
  config) matches higher, or index a second `simple` tsvector. Logged, not urgent.
- A query made only of stop words (e.g. "de") returns no results (Postgres drops it).
- The UI has not been seen in a browser yet (no Rails runtime in the sandbox); it is
  covered by controller tests only. First local check: `bin/rails db:seed` then `/tenders`.
- The states filter is a native multi-select; a nicer chip selector can come with the
  React portal (Phase 2).
- Nothing moved to the next day.

## Day 3 — Fri, Nov 20, 2026

**Starting point**
- CI on `main` was green (run for `fe2db8a`); no unchecked tasks from earlier days.

**Done**
- CI: every job now runs `bundle lock` before the cached `bundle install`. setup-ruby
  installs in deployment mode when `Gemfile.lock` exists, so adding a gem (bcrypt, today)
  would have failed every job before the bot could regenerate the lock. The bot committed
  the new lock (`69389e7`).
- Portuguese messages: `pt-BR` is the default locale (`config/locales/pt-BR.yml` with
  validation messages and attribute names), falling back to Rails' English for anything
  else, so the Day 2 helpers behave exactly as before.
- Authentication (hand-written equivalent of `bin/rails generate authentication`): `User`
  (bcrypt, e-mail normalized, format/uniqueness, password ≥ 8 chars), `Session` (signed
  http-only cookie, IP and user agent), `Current`, `Authentication` concern (login required
  by default; tenders and home pages opt out), login/logout, password reset by e-mail
  (`PasswordsMailer`, HTML + text, 15-minute token that dies once the password changes,
  all sessions signed out after a reset), same answer for unknown e-mails, rate limit of
  10 requests per 3 minutes per IP on login, reset and sign-up. Flash messages and
  account links in the header.
- Sign-up page (`/registration/new`): creates the account, signs it in and returns to the
  page that required login (e.g. "Salvar esta busca").
- `SavedSearch` (user, name, query, niche slug, filters jsonb, active, notify_daily,
  last_notified_at): criteria normalized through `Tenders::Search`, at least one criterion
  required, unknown niches rejected, default name from the criteria ("“buffet” · Eventos ·
  PE"), max 20 per account, `notifiable` scope.
- Saved searches UI at `/saved_searches`: list (criteria, alert status, link with the
  current number of open matches), new (pre-filled from the results page), edit (criteria,
  name, daily alert on/off, pause), delete with confirmation; other users' searches are 404.
  "Salvar esta busca" button on the results page whenever the search has criteria.
- `Notification` (saved_search, tender, sent_at) with a unique index on
  (saved_search_id, tender_id) and `Notification.record!` (bulk insert, skips duplicates).
- `SavedSearches::Matcher`: open tenders matching the saved search, published / updated on
  the PNCP / first synced since `last_notified_at`, never notified for that search; ordered
  by closest deadline, optional limit.
- Tests: i18n, User, auth flows (login, logout, wrong password, unknown e-mail, rate limit,
  return-to after login, reset request/edit/update, expired/used/invalid tokens), mailer,
  sign-up, SavedSearch model and CRUD (incl. ownership), Notification, Matcher (new vs
  already notified, published/updated/synced since, criteria, ordering). Rails suite:
  197 runs, 0 failures.

**Commits**
- `cf0717a` ci: resolve Gemfile.lock before installing gems
- `c5a52f6` feat: show validation messages in Portuguese
- `2e1676e` feat: add e-mail and password authentication
- `60a5730` fix: remember the return URL for HEAD requests too
- `c206cfb` feat: add sign-up page
- `7829ebb` feat: add SavedSearch model
- `38218f3` feat: add saved searches UI and the "Salvar esta busca" button
- `2b92d6e` fix: pass saved search criteria to Tenders::Search as a hash
- `5ee276c` feat: add Notification to record alerts already sent
- `1efd70f` feat: add SavedSearches::Matcher
- plus this docs commit (plan, log, README, ROADMAP, DEVELOPMENT)

**CI**
- Green at the end of the day (run for `1efd70f`: lib tests, Rails tests, RuboCop,
  Brakeman). The bot regenerated `Gemfile.lock`/`db/schema.rb` twice (`69389e7`, `031fb03`).
- Three red runs during the day, each fixed by the next push:
  - `2e1676e`: Brakeman "HTTP verb confusion" on `request.get?` in the concern → `60a5730`
    (checks GET and HEAD).
  - `38218f3`: `Tenders::Search.new(q: …)` was called with keywords, which collide with its
    `per_page:` keyword (ArgumentError in every saved-search test) → `2b92d6e`.
  - `2b92d6e`: that commit accidentally included `has_many :notifications` before the
    `Notification` model existed → `5ee276c` added the model (≈1 minute of red `main`).

**Decisions**
- Kept the generator's English route names (`/session/new`, `/registration/new`,
  `/passwords`) to match Rails conventions; all visible text is Portuguese.
- The return URL after login is only stored for GET/HEAD requests (a POST/DELETE URL can't
  be reopened).
- A blank new password on reset is rejected explicitly (`has_secure_password` silently
  ignores blank passwords on update).
- The test environment now uses `:memory_store` so the rate limits are really exercised;
  integration tests clear it in `setup`.
- Saved-search criteria are stored already normalized (the same params `Tenders::Search`
  accepts) instead of raw form input, so the UI, the matcher and the future API all read
  the same thing. `sort` is not stored (the digest has its own order).
- "Since the last notification" uses PNCP `published_at`, PNCP `source_updated_at` and our
  `created_at` (first time we synced it), so a tender published days ago but only synced
  now still alerts. `updated_at` is useless here: every sync touches `last_seen_at`.
- A saved search that was never notified (`last_notified_at` nil) matches every open
  tender (deduplicated by `Notification`), so the first digest shows current opportunities.
- Alert order is the closest deadline first (urgency matters more than rank in an alert).

**Open problems / notes for next days**
- E-mail addresses are not confirmed. Before Day 4 sends digests, consider a confirmation
  step (or at least only sending to addresses that clicked a link) to avoid mailing people
  who never signed up. Not done today to stay within the plan.
- No terms of use / privacy consent on sign-up yet (LGPD): add before a public launch.
- `rate_limit` keeps its counters in `Rails.cache`; production has no cache store
  configured (file store per host). With several hosts, configure a shared store
  (Solid Cache or Redis) — to note in the Day 5 deploy guide.
- No "change password / delete account" page for signed-in users yet (reset by e-mail works).
- The new screens were verified only by controller tests (no browser in the sandbox).
- Nothing moved to the next day.

## Day 4 — Sat, Nov 21, 2026

**Starting point**
- CI on `main` was green (run for `fc15524`); no unchecked tasks from earlier days.

**Done**
- `SavedSearches::Digest`: one user's daily e-mail. One section per active saved search
  with `notify_daily` and something new (`SavedSearches::Matcher`), the 20 most urgent
  tenders plus the total count. `#deliver` sends the e-mail, records the tenders shown as
  `Notification`s and sets `last_notified_at` of every checked search to the moment the
  matches were looked up.
- `DigestMailer#daily` (HTML + text): grouped by saved search with its criteria, each
  tender with agency, place, modality, deadline ("Encerra em 3 dias (24/11/2026 às
  14:00)"), value ("Valor sigiloso" when 0), link to the tender page; "E mais N
  licitações" plus a link to the search's full results; subject with the count and, for a
  single search, its name. Preview at `/rails/mailers/digest_mailer/daily` (works with an
  empty database too).
- Unsubscribe: a "stop this alert" link per search and a "stop every alert" link in the
  footer, signed with `generates_token_for` (no login needed). `/unsubscribe/:token` shows
  a confirmation on GET (mail scanners open links) and turns `notify_daily` off on POST.
  `List-Unsubscribe` + `List-Unsubscribe-Post` headers for one-click unsubscribes (RFC
  8058); that POST skips CSRF because mail providers can't send a token.
- `SendDailyDigestsJob`: delivers the digest to every user with a notifiable search; one
  failing user is reported to `Rails.error` and doesn't stop the others; returns
  `{ users:, sent:, failed: }` and logs it. Re-running it the same day sends only news.
- Solid Queue (1.7.2) in production, tables in the app's database (migration mirroring the
  gem's schema), `config/queue.yml`, `bin/jobs`, Puma plugin behind
  `SOLID_QUEUE_IN_PUMA`. `config/recurring.yml`: sync at 00:30/06:30/12:30/18:30 and digest
  at 07:00, `America/Sao_Paulo`. A test validates the file with
  `SolidQueue::RecurringTask` and checks the next run times; another enqueues a real
  Solid Queue job to prove the tables match what the gem expects.
- Production e-mail: SMTP settings from `SMTP_*`, sender from `MAIL_FROM`, https links;
  `.env.example` updated.
- `ApiToken`: random `lr_` + 40 base58 chars, only the SHA-256 digest and the first
  characters stored, shown once; `last_used_at` written at most once a minute; 10 per
  account. Page `/api_tokens` (menu "API") to create and revoke them; the page with a new
  token is rendered (not a redirect + flash) with `Cache-Control: no-store`.
- JSON API v1 (`ActionController::API`, bearer token, JSON errors
  `{ error: { code, message, details } }`, rate limit 300 requests / 5 min per token):
  - `GET /api/v1/tenders`: `Tenders::Search` with the website's filters, `per_page` up to
    100, `meta` with pagination, sort and the filters actually applied;
    `GET /api/v1/tenders/:id` (any tender). Values as decimal strings, times ISO 8601.
  - `GET/POST/DELETE /api/v1/saved_searches` and `GET /:id`: the token owner's searches,
    criteria with the tenders filter names (`q`, `niche`, ...), 422 with per-field
    messages, `links.tenders` to the search's open tenders.
- `docs/API.md` (auth, rate limit, errors, every endpoint with curl and JSON examples);
  README, ROADMAP and DEVELOPMENT updated.
- Tests: digest (sections, limit, deliver, second run, no news), mailer (content, links,
  subject, "e mais", unsubscribe links and headers, preview), unsubscribes (confirm,
  per search, per account, one-click with CSRF on, invalid tokens), job (who gets
  e-mails, re-run, failure isolation), recurring schedule + Solid Queue tables, ApiToken
  model and page, API request tests (auth, revoked token, every field, filters, invalid
  filters, pagination, sort, 404, rate limit, saved search CRUD, validation errors,
  mass assignment, bad JSON). Rails suite: 252 runs, 0 failures (197 yesterday).

**Commits**
- `50506d2` feat: add the daily digest e-mail
- `f617abf` feat: add unsubscribe links to the daily digest
- `ff620b6` feat: add SendDailyDigestsJob
- `b98b7cc` feat: schedule the sync and the daily digest with Solid Queue
- `5a36717` feat: add API tokens
- `687bae5` feat: add the JSON API v1 for tenders
- `47fde9a` feat: add saved searches to the JSON API v1
- `07b66ea` chore: configure SMTP delivery and the sender address for production
- `331c13e` docs: document the JSON API v1 with curl examples
- plus this docs commit (plan, log, README, ROADMAP, DEVELOPMENT)

**CI**
- Green on every push today (lib tests, Rails tests, RuboCop, Brakeman); no red run.
  The bot regenerated `Gemfile.lock`/`db/schema.rb` twice (`d9e0b3c` with solid_queue
  1.7.2 and its tables, `4dcea5b` with `api_tokens`).

**Decisions**
- The mailer takes prebuilt sections and is sent with `deliver_now` inside the job, so the
  tenders recorded as notified are exactly the ones in the e-mail (the sections are not
  serializable for `deliver_later`, and the job already runs in the background).
- Only the 20 tenders shown are recorded; the rest are counted in the e-mail ("E mais N")
  with a link to the full results, but they will not be e-mailed later unless the PNCP
  updates them (they fall out of the "since last notification" window).
- `last_notified_at` moves forward for every checked search, even without news, and is
  the time the matches were looked up (not the time the e-mail left), so tenders synced
  meanwhile are caught by the next digest.
- Unsubscribe tokens never expire (they can only stop e-mails); separate purposes for
  the per-search and per-account tokens so one can't be used as the other.
- The sync runs at :30 of 0/6/12/18 h so the 07:00 digest uses data from ≈30 minutes
  before. Development keeps the async adapter; Solid Queue is only the production adapter.
- The whole API requires a token, including the (public on the website) tenders
  endpoints: it identifies clients and lets us rate-limit them. Tokens are managed on the
  website, not through the API.
- API money values are decimal strings (Rails' default for BigDecimal, no precision loss);
  `estimated_value` is `null` with `confidential_value: true` when the PNCP sends 0.
- API bodies must use the `saved_search` root key (`wrap_parameters false`): Rails'
  automatic wrapping would only wrap model attribute names and silently drop `q`/`niche`.
- SMTP configuration was added (not in the plan) because the digest is useless in
  production without it.

**Open problems / notes for next days**
- **E-mail addresses are still not confirmed** and digests now go out daily: anyone can
  sign up with someone else's address and that person will get alerts (with working
  unsubscribe links). Recommended before a public launch: confirmation e-mail, and only
  send digests to confirmed addresses.
- Solid Queue's tables come from a hand-written migration: when upgrading the gem, check
  its release notes for schema changes (the "tables accept jobs" test catches missing
  columns only for the code paths it exercises).
- Production still needs real values for `APP_HOST`, `MAIL_FROM` and `SMTP_*`, and the
  deploy guide (Day 5) must say how jobs run (`bin/jobs` or `SOLID_QUEUE_IN_PUMA=1`).
- The API rate limit counts in `Rails.cache` like the login limits: needs a shared cache
  store with more than one app host (Day 5 deploy notes).
- The digest's look was checked only through tests and the preview code, not in real mail
  clients (no browser/SMTP in the sandbox); the HTML uses simple inline styles.
- No `PATCH /api/v1/saved_searches/:id` yet (not in the plan); added to the ROADMAP backlog.
- Nothing moved to the next day.

## Day 5 — Sun, Nov 22, 2026

**Starting point**
- `main` green at `764a41e` (Day 4); nothing left over from earlier days.

**Done**
- Sync hardening: `SyncRun#attempt`; `SyncOpenTendersJob` re-enqueues only the failed
  modalities (attempt 2 after 15 min, attempt 3 after 45 more) and, when the last attempt
  fails, reports `SyncOpenTendersJob::SyncFailed` and e-mails `ADMIN_EMAIL`
  (`AdminMailer#sync_failed`, text e-mail with each modality's error, failures in a row
  and a link to `/status`). `SyncRun.fail_abandoned!` closes runs stuck "running" for more
  than 3 hours at the start of every sync.
- Friendly static error pages in Portuguese: 400, 404, 406 (unsupported browser), 422,
  500, plus `robots.txt`. There was no `public/` at all: `allow_browser` would have raised
  on old browsers because its 406 page was missing.
- Performance: measured the search plans on a local PostgreSQL 16 with 60k synthetic rows
  (all searches use indexes, 0.7–17 ms; no new index needed) and wrote
  `docs/PERFORMANCE.md`. Tests: query plans with sequential scans disabled (GIN index for
  keywords and niches, notifications index for the matcher, no seq scan for any search)
  and N+1 guards (results page, API tenders and saved searches; the saved searches page
  adds exactly one COUNT per search).
- `Dockerfile` (multi-stage, Ruby 3.3.13 slim, jemalloc, non-root, assets precompiled),
  `bin/docker-entrypoint` (`db:prepare` before the server, `SKIP_DB_PREPARE`),
  `.dockerignore`, and a CI job that builds the image, boots it against PostgreSQL with
  Solid Queue in Puma and requests `/up`, `/`, a search, a 404 and checks Solid Queue's
  processes.
- Admin status page `/status` (+ `.json`, 503 when unhealthy) behind basic auth with
  `STATUS_USERNAME`/`STATUS_PASSWORD` (404 when unset): latest run, last success and
  failures in a row per modality, counts, Solid Queue queue, last 20 runs.
- `docs/DEPLOY.md` (env vars, process layouts, post-deploy checklist, Render, Fly.io,
  Kamal, plain Docker, operations). README: features, screenshots placeholder,
  architecture diagram (Mermaid, checked with mmdc), deploy section. Home page no longer
  says the alerts are "em breve".
- `CHANGELOG.md` (v0.1.0), ROADMAP updated, `.env.example` with `ADMIN_EMAIL` and
  `STATUS_*`, DEVELOPMENT.md sections on sync reliability and the status page.
- GitHub issues opened: #1 Phase 2 React portal, #2 e-mail confirmation, #3 API PATCH +
  niches/modalities, #4 archive closed tenders, #5 shared cache for rate limits, #6 error
  reporting, #7 first public deploy, #8 backlog (CSV, webhooks, stats, i18n).
- Final report: `docs/sprint/REPORT.md` (Portuguese).
- Rails suite: 292 runs, 0 failures (252 yesterday); lib: 38 runs.

**Commits**
- `839ebef` feat: retry failed sync modalities and alert the admins when they keep failing
- `8843915` feat: add friendly error pages in Portuguese
- `b39d213` test: check that searches use the indexes and pages have no N+1 queries
- `a65859c` docs: add performance notes with the search query plans
- `6dc1611` test: count cached queries in the N+1 guard and pass search params as a hash
- `352bde8` chore: add a production Dockerfile and build + smoke test it in CI
- `7e3cf04` feat: add the admin status page with the sync health per modality
- `8d3cef4` docs: add the deploy guide (Docker, Render, Fly.io, Kamal)
- `bf86524` docs: polish the README with features, screenshots section and architecture diagram
- `fa6fbe9` docs: update the roadmap and add the v0.1.0 changelog
- plus this docs commit (report, plan, log, changelog links)

**CI**
- One red run: `a65859c` (the two perf test commits). Errors: `Tenders::Search.new(q: ...)`
  passed keywords instead of a params hash, and the N+1 counts differed by one because
  Active Record's query cache survived between requests in the test (the "few" case had
  a write that cleared it). Fixed in `6dc1611` by passing hashes and counting cached
  queries too. Every other run green, including the new Docker job. The bot regenerated
  `db/schema.rb` once (`49415c6`, `sync_runs.attempt`).

**Decisions**
- Retries live in the job (re-enqueue with the failed modalities and the attempt number)
  rather than `retry_on`, because `Tenders::Sync` handles errors per modality and the job
  itself never raises. Delays 15 and 45 minutes keep all retries well before the next
  scheduled run (6 hours).
- The admin alert goes out only after the last attempt (one e-mail per scheduled run
  while the PNCP stays down, i.e. at most every 6 hours). No e-mail when `ADMIN_EMAIL` is
  unset; the error is still reported.
- Error pages are static files in `public/` (Rails' default mechanism) with inline CSS,
  so they work even when the app or the asset pipeline is broken.
- No index was added: the measured plans were already fast. Suggestions for when data
  grows are in `docs/PERFORMANCE.md` (partial index for value sort, caching the open
  count, archiving closed tenders).
- `/status` without credentials configured raises a routing error (identical to a
  non-existent page) instead of being open; JSON returns 503 when unhealthy so uptime
  monitors alert. A modality is healthy when its latest run did not fail and it
  succeeded within 12 hours (two sync intervals).
- The Docker image runs `db:prepare` in the entrypoint (fine for one container); multi-host
  setups set `SKIP_DB_PREPARE=1` and migrate in a release step.
- No git tag was pushed: `v0.1.0` should be tagged when the first deploy is validated
  (the changelog does not link to the tag yet).
- Phase 2 and backlog work became GitHub issues (the API allowed it), referenced from the
  ROADMAP and the report.

**Open problems / notes**
- Not yet run against the real PNCP or deployed (#7). E-mail addresses still unconfirmed
  (#2). No error reporting service (#6). Rate limits per container (#5). Closed tenders
  accumulate (#4). See "O que falta ou é frágil" in `docs/sprint/REPORT.md`.

## Day 6 — Wed, Nov 25 · Pre-launch hardening ✅

**Done**
- **E-mail confirmation (#2, closed):** `users.confirmed_at` + `users.unconfirmed_email`;
  `generates_token_for :email_confirmation` (3 days) embedding both addresses, so a link
  dies once its change is confirmed or replaced. `EmailConfirmationsMailer#confirm` on
  sign-up; `GET /email_confirmations/:token` confirms (works signed in or out, idempotent);
  `/email_confirmations/new` resends (same answer for unknown/confirmed addresses, rate
  limited); banner with a resend button for signed-in unconfirmed users; link on the login
  page. New "Minha conta" page (`/account`): e-mail + status, change the address with the
  current password — the new address waits in `unconfirmed_email` and only replaces the
  old one (login and alerts) after its link is opened; typing the current address cancels
  a pending change; a confirmation fails cleanly if the address was taken meanwhile. A
  password reset also confirms the address it reached. `SavedSearch.notifiable` joins
  confirmed users, so the digest job and `Digest` skip unconfirmed accounts; `/status`
  counts accounts without a confirmed e-mail.
- **Error reporting (#6, closed):** `ErrorReporting` (`lib/error_reporting.rb`) subscribed
  to `Rails.error`: logs `[ErrorReporting] Class: message (handled= severity= source=)
  context={...}` + 5 backtrace lines; context reduced to plain data (`User#12`,
  `SomeJob (job id)`, controllers as `Class#action`) and filtered with
  `config.filter_parameters`; forwards to Sentry via `ErrorReporting::SentryForwarder` only
  when `Sentry.initialized?`. `sentry-ruby` + `sentry-rails` gems, `Sentry.init` only when
  `SENTRY_DSN` is set (`send_default_pii = false`, tracing off unless
  `SENTRY_TRACES_SAMPLE_RATE`). Documented in `docs/DEPLOY.md` (env table + "Error
  tracking") and `.env.example` (commented).
- **Archive old tenders (#4, closed):** `Tenders::Archive` deletes in batches of 1,000
  tenders closed more than `ARCHIVE_AFTER_DAYS` (default 180) days ago — tenders without a
  closing date count from `updated_at` — unless a model in `KEPT_WHEN_REFERENCED_BY`
  (today `Notification`) refers to them. `ArchiveOldTendersJob` (Sundays 03:15 Brasília in
  `config/recurring.yml`) logs `Tender archive: N deleted, M kept (referenced)`;
  `bin/rails tenders:archive` runs it by hand.
- **Home counters cached** 5 minutes in `Rails.cache` (open, closing in 7 days, last sync);
  note in `docs/PERFORMANCE.md`.
- CI: the Docker job now runs `bundle lock` before `docker build` (see CI below).
- Docs: DEVELOPMENT.md (e-mail confirmation, archiving, error reporting), DEPLOY.md,
  PERFORMANCE.md.
- Rails suite: 349 runs, 1597 assertions, 0 failures (292 at the end of sprint 1);
  lib: 38 runs.

**Commits**
- `8e8cee7` feat: track e-mail confirmation and pending e-mail changes on users
- `2ff2ed4` feat: confirm e-mail addresses on sign-up and on e-mail changes
- `1ac4420` feat: send daily digests only to users who confirmed their e-mail (Closes #2)
- `4933380` feat: log every Rails.error report and forward it to Sentry when configured (Closes #6)
- `beea0e2` feat: archive tenders closed more than 180 days ago every week (Closes #4)
- `01d636a` ci: refresh Gemfile.lock before building the Docker image
- `c084acc` perf: cache the home page counters for 5 minutes
- plus this docs commit; the bot regenerated `db/schema.rb` (`57e67fa`) and
  `Gemfile.lock` (`41cc305`, Sentry gems)

**CI**
- One red run: `4933380`. Only the Docker job failed — the image installs gems in frozen
  mode and the new Sentry gems were not in `Gemfile.lock` yet (the Rails job commits it
  after its tests, with `[skip ci]`). Rails tests, lint and Brakeman were green on that
  run. Fixed for good in `01d636a` (the Docker job refreshes the lockfile first, like the
  other jobs). Every later run green, including the Docker smoke test.

**Decisions**
- Column is `confirmed_at` (as in the plan; issue #2 said `email_confirmed_at`).
- Existing accounts are **not** backfilled as confirmed: nothing proves they own their
  address, and there is no public deploy yet. After deploying, existing users see the
  banner and stop getting digests until they confirm. To keep an account you trust
  receiving alerts: `User.find_by(email_address: "...").update!(confirmed_at: Time.current)`.
- Unconfirmed users can still sign in, save searches and use the API; only e-mail alerts
  wait for the confirmation (the abuse in #2 is unsolicited mail).
- E-mail change uses a pending `unconfirmed_email` (login and alerts stay on the old,
  confirmed address until the new one is confirmed) instead of switching immediately, so
  a typo cannot lock someone out or send alerts to a stranger. The change form requires
  the current password and is rate limited.
- The confirmation link is a GET that confirms directly (mail scanners pre-fetching it
  only prove the mailbox received it). It redirects to login when the browser is signed out.
- `ErrorReporting` lives in `lib/` and is required by its initializer (ignored by the
  autoloader): reloadable constants are not available while the app boots. Sentry is
  fed by our subscriber (everything reported to `Rails.error`) and by sentry-rails' own
  request/job capture; Sentry marks captured exceptions, so one error is sent once.
  Exception messages are sent unfiltered (documented: keep e-mails/tokens out of them).
- Archive deletes rows (with `delete_all`, no callbacks) instead of only blanking `raw`:
  notified tenders are kept whole, so every link ever e-mailed still opens the tender
  page; other old tenders return the normal 404. The weekly schedule (Sunday 03:15) sits
  between the 00:30 and 06:30 syncs. Counts go to the job log only — `/status` does not
  show them yet (Solid Queue does not keep job return values).
- Home counters cache key `pages/home/counters`, 5 minutes, not invalidated by the sync
  (at most 5 minutes stale after a sync that runs every 6 hours).

**Open problems / notes**
- Sentry was not exercised against a real DSN here (no network); the forwarder is tested
  with a fake client. Check the first real event after deploy (#7).
- Day 8 (watchlist) must add `Watch` to `Tenders::Archive::KEPT_WHEN_REFERENCED_BY`, and
  Day 7's documents/items tables should cascade on tender deletion.
- Still open from sprint 1: first deploy (#7), shared cache for rate limits (#5).
- Nothing moved to Day 7.

## Day 7 — Thu, Nov 26 · Tender documents + items ✅

**Done**
- **PNCP integration client (`lib/pncp`):** `Pncp::IntegrationClient` (base
  `https://pncp.gov.br/api/pncp`, env `PNCP_INTEGRATION_BASE_URL`) for
  `GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/arquivos` and `.../itens`
  (`pagina`/`tamanhoPagina`, read until a short, empty or repeated page; 50 per page, at
  most 40 pages). Paths and fields checked against the official "Manual de Integração do
  PNCP" (sections 11.8 and 11.13, access in section 5: public GETs, no authentication).
  `DocumentNormalizer` (sequence, title, type id/name, download URL, published at, active)
  and `ItemNormalizer` (number, description, M/S, quantity, unit, unit/total estimated
  value, confidential budget, status, judgment criterion, benefit, category, updated at).
  Shared code extracted first: `Pncp::HttpClient` (transport, retries, 204, JSON) and
  `Pncp::Values` (string/integer/decimal/boolean/Brasília time parsing). Fictional fixtures
  `arquivos.json`, `itens_page_1.json`, `itens_page_2.json`. Lib: 58 runs (38 before).
- **Models + fetch:** `tender_documents` and `tender_items` (unique per tender +
  sequence/number, FK `ON DELETE CASCADE`, so `Tenders::Archive` removes them with the
  tender); `tenders.details_fetched_at`, `details_source_updated_at`,
  `details_requested_at`. `Tenders::FetchDetails` replaces the rows (upsert + delete the
  ones gone from the PNCP), skips unidentifiable records, drops inactive documents and
  stores the PNCP version it fetched. `FetchTenderDetailsJob` retries `Pncp::Error` (3
  attempts, 2 min apart, last failure reported), reports 4xx without retrying, is
  discarded if the tender was archived. `Tender#request_details_fetch` enqueues it when the
  details are missing or `source_updated_at` changed, at most once per 10 minutes (atomic
  conditional UPDATE).
- **Tender page:** lazy Turbo Frame `tender_details` → `GET /tenders/:id/details`.
  Opening it requests the fetch; while nothing was fetched it shows "Buscando documentos e
  itens no PNCP…" and a small Stimulus controller (`frame-reload`) reloads it every 3 s, up
  to 20 times, then shows a "try again later / see the PNCP" message. "Documentos do
  edital" (type, title linked to the PNCP download — only http(s) — and date) and "Itens"
  (number, description, kind/benefit, quantity, unit, unit and total estimated values with
  up to 4 decimals, "sigiloso" when missing; first 100 items + link to the PNCP for larger
  tenders). Stale details stay visible while the refresh runs.
- **Search:** `tenders.items_text` (item descriptions, max 50,000 chars) and the generated
  `searchable` column rebuilt as `setweight(tender text, 'A') || setweight(items_text, 'D')`
  — same GIN index, so keyword, niche and saved-search queries match items, ranked below
  object matches. Query-plan test for an item-only word.
- **API v1:** `GET /api/v1/tenders/:id` returns `details` (`status`: available,
  refreshing, pending, unavailable; `fetched_at`), `documents` and `items` (null until the
  first fetch) and starts the fetch like the page. The list endpoint is unchanged.
  `docs/API.md` updated.
- Docs: DEVELOPMENT.md ("Tender documents and items", search notes), README (feature,
  layout), `.env.example`.
- Rails suite: 406 runs, 1845 assertions, 0 failures (349 on day 6); lib: 58 runs.

**Commits**
- `b070729` refactor(pncp): share HTTP retries and value parsing between clients and normalizers
- `a4a8f56` feat(pncp): fetch tender documents and items from the PNCP integration API
- `642d37d` feat: store tender documents and items, fetched by a background job
- `d1972a6` test: clear sent e-mails before every test
- `84e7d1c` feat: show the tender documents and items on the tender page
- `6f46f99` test: rename the tender details frame test to avoid a class name clash
- `42f0674` feat: search tender items as well
- `be06755` feat(api): include documents and items in GET /api/v1/tenders/:id
- `93db7d7` docs: document tender documents and items (development guide, README, env example)
- plus this docs commit; the bot regenerated `db/schema.rb` (`0750b2d`, `c613474`)

**CI**
- Two red runs, both fixed within minutes:
  - `642d37d`: `SendDailyDigestsJobTest` saw 3 e-mails instead of 2 — a mail sent to the
    same address by an earlier test in the same worker was still in
    `ActionMailer::Base.deliveries` (only `ActionMailer::TestCase` clears it; the new tests
    changed how files are spread over workers). Pre-existing flakiness; fixed for every
    test in `d1972a6` (`setup { ActionMailer::Base.deliveries.clear }` in `test_helper.rb`).
  - `84e7d1c`: the suite did not boot — two test classes named `TenderDetailsTest` (model
    and controller). Renamed the controller one in `6f46f99`.
- Every later run green (lib, RuboCop, Brakeman, Rails tests, Docker smoke test).

**Decisions**
- A separate `IntegrationClient` (subclass of a shared `HttpClient`) instead of a second
  base URL inside `Client`: the two APIs have different paths, paging and payloads.
- Response shape: the manual lists the fields under "documentos"/"itens" without a JSON
  example; the API is known to answer a bare array. The client accepts a bare array, an
  object with that key, or `data`. No live call was possible here (pncp.gov.br blocked),
  so this is the first thing to check against the real API (see below).
- The items endpoint returns no totals, so paging stops at the first short page, an empty
  page (204) or a page that only repeats item numbers (in case the API ignores the paging
  parameters). Page size 50 because the manual documents no maximum.
- Details are fetched **on demand** (page frame or API), never by the 6-hourly sync: one
  tender = 2+ requests, and fetching all open tenders every sync would multiply the load
  on the PNCP. Crawlers that do not load frames trigger nothing. The tender page never
  waits for the PNCP.
- Refetch rule: the stored `details_source_updated_at` is the tender's `source_updated_at`
  at the start of the fetch; a later sync that changes it makes the details stale again.
  Requests are throttled to one job per tender per 10 minutes, so a failing fetch is
  retried by the next visit after that.
- Polling instead of Turbo Stream broadcasts: no Action Cable is configured, and a 3 s
  reload for at most a minute is cheap. The server decides when to stop (the `poll` param).
- Documents inactive on the PNCP (`statusAtivo: false`) are not stored. Item values of 0
  with `orcamentoSigiloso: true` are stored as NULL and shown as "sigiloso".
- Items in `searchable` get weight D and tender text weight A, so a match in the object
  ranks above a match only in the items. Ranking among tenders without items is
  unchanged (all their words moved from D to A together).
- The page shows the first 100 items (with the total and a PNCP link); the API returns all
  stored items (at most 2,000 per tender because of the client's page cap).
- `tender_documents` / `tender_items` cascade on tender deletion (they only describe the
  tender), so they are not in `Tenders::Archive::KEPT_WHEN_REFERENCED_BY`.

**Open problems / notes**
- **Not verified against the real PNCP** (no network here): endpoint shapes, the document
  `url` format and whether `tamanhoPagina` has a maximum. After deploy (#7), open a few
  tender pages and check the log lines `[Tenders::FetchDetails] tender N: X documents, Y
  items`; reported `Pncp::HttpError`s would mean a path or parameter problem.
- Item search only covers tenders whose details were fetched (someone opened the page or
  asked the API). A background prefetch for open tenders (rate limited) would make it
  complete — candidate for the backlog. A tender that starts matching a saved search only
  because its items were fetched is not alerted unless it is also new/updated on the PNCP
  (the matcher looks at publication/update/first-sync times).
- Rebuilding `searchable` rewrites the `tenders` table once when this migration runs
  (seconds at the current size).
- In development, opening a seeded (fictional) tender enqueues a fetch that will 404 on
  the real PNCP and be reported; harmless.
- Nothing moved to Day 8. Day 8 must add `Watch` to `Tenders::Archive::KEPT_WHEN_REFERENCED_BY`.
