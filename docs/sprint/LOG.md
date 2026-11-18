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
