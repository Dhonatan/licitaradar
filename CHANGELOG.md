# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Next: the React portal (Phase 2, [#1](https://github.com/Dhonatan/licitaradar/issues/1)).
Open work is tracked in the [issues](https://github.com/Dhonatan/licitaradar/issues).

## [0.1.0] — 2026-11-22

First complete version of the core product, built in the one-week bootstrap sprint
([plan](docs/sprint/PLAN.md), [log](docs/sprint/LOG.md), [report](docs/sprint/REPORT.md)).

### Added

- **PNCP integration** (`lib/pncp`, plain Ruby): API client with pagination, retries with
  exponential backoff and 204 handling; record normalizer (Brasília times, decimals, CNPJ,
  public PNCP URL); CPF masking in free text (LGPD); `bin/pncp-probe`.
- **Sync**: `tenders` table with a stored Portuguese full-text column (accents folded) and
  GIN index; idempotent `Tenders::Sync` (upsert by PNCP control number, one failing
  modality doesn't stop the others) with a `SyncRun` audit log; `SyncOpenTendersJob` and
  `bin/rails pncp:sync`.
- **Search and public UI**: `Tenders::Search` (keywords in web-search syntax ranked by
  relevance, filters by state, modality, value and deadline, sorting, pagination), niche
  presets in `config/niches.yml`, home page with numbers, results and tender detail pages,
  Portuguese UI and validation messages, 30 fictional seed tenders.
- **Accounts**: sign-up, login and password reset (rate limited), saved searches with the
  "Salvar esta busca" button, `SavedSearches::Matcher` and `Notification` records so a
  tender is never alerted twice for the same search.
- **Daily digest** e-mail (HTML + text, grouped by saved search, top 20 per search) with
  per-search and per-account unsubscribe links and one-click `List-Unsubscribe`;
  `SendDailyDigestsJob`.
- **Background jobs** with Solid Queue (tables in the primary database): sync every 6 hours
  and digest at 07:00 Brasília time.
- **JSON API v1** with bearer tokens (hashed, shown once, rate limited): tenders search and
  detail, saved searches CRUD; documented in [`docs/API.md`](docs/API.md).
- **Operations**: the sync job retries failed modalities (after 15 and 45 minutes) and
  e-mails `ADMIN_EMAIL` when the last attempt fails; runs left "running" by a dead process
  are closed; admin status page `/status` (basic auth, also JSON with 503 when unhealthy).
- **Friendly error pages** in Portuguese (400, 404, 406 unsupported browser, 422, 500).
- **Deploy**: multi-stage production `Dockerfile`, `bin/docker-entrypoint` (runs
  `db:prepare`), `.dockerignore`, deploy guide for Render, Fly.io, Kamal and plain Docker
  ([`docs/DEPLOY.md`](docs/DEPLOY.md)).
- **Quality**: CI with lib tests, Rails tests on PostgreSQL, RuboCop, Brakeman and a Docker
  build + smoke test; query plan and N+1 tests ([`docs/PERFORMANCE.md`](docs/PERFORMANCE.md)).

[Unreleased]: https://github.com/Dhonatan/licitaradar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Dhonatan/licitaradar/commits/v0.1.0
