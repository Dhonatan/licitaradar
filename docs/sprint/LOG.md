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
