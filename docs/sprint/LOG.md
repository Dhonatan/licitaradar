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
