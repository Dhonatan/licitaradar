# Development guide

Read `README.md` for what the product is. The active plan is `docs/sprint/PLAN.md` and
progress is logged in `docs/sprint/LOG.md`.

## Ground rules

- Ruby 3.3.13, Rails 8.1, PostgreSQL. Hotwire/import maps, plain CSS — **no Node build**.
- Style: rubocop-rails-omakase (double quotes, spaces inside array brackets: `[ 1, 2 ]`,
  `private` with indented methods below it).
- `lib/pncp/` must stay **framework-independent** (stdlib only). Its tests live in
  `test/lib/` and run with `ruby bin/test-lib`.
- Never hit the real PNCP API in tests: use `PncpTestSupport::FakeTransport` (lib tests) or
  WebMock (Rails tests) with the fictional fixtures in `test/fixtures/files/pncp/`.
- Never commit secrets or real personal data. Fixtures use fictional agencies and CNPJs
  like `00000000000191`.
- Small, focused commits with clear messages (conventional prefixes: `feat:`, `fix:`,
  `test:`, `docs:`, `chore:`, `refactor:`, `ci:`).

## Offline work and generated files

If your environment cannot reach rubygems.org or pncp.gov.br:

- Run `ruby bin/test-lib` locally (no gems needed) for anything in `lib/`.
- Rails code is verified by GitHub Actions. After pushing, check the run with the GitHub
  API (`/repos/Dhonatan/licitaradar/actions/runs`) and fix failures before moving on.
- CI regenerates `Gemfile.lock` and `db/schema.rb` and commits them back to `main` as
  `github-actions[bot]`. **Always `git pull --rebase origin main` before starting work.**
- Do not hand-edit `db/schema.rb` or `Gemfile.lock`; write migrations / edit the Gemfile.
- Adding a gem: edit the `Gemfile` only. Every CI job runs `bundle lock` before
  installing (setup-ruby uses deployment mode when a lockfile exists, which would reject a
  changed Gemfile), and the Rails job commits the updated `Gemfile.lock`.

## Domain notes

- `/v1/contratacoes/proposta` = tenders with proposals still open (needs `dataFinal`,
  `codigoModalidadeContratacao`, `pagina`). It does **not** accept `dataInicial`.
- `/v1/contratacoes/publicacao` = tenders published in a window (`dataInicial`, `dataFinal`).
- HTTP 204 means "no results". Page size max is 500.
- Keyword filters are ignored by the API — search happens in our database.
- Dates are Brasília local time without offset; `valorTotalEstimado == 0` usually means
  a confidential estimate, not a free purchase.
- Public page of a tender: `https://pncp.gov.br/app/editais/{cnpj}/{ano}/{sequencial}`.

## Search notes

- `tenders.searchable` is a stored generated `tsvector` (Portuguese config) over object,
  additional info, agency and unit names, with accents folded by `translate()`.
  `unaccent()` can't be used there (not immutable) and custom SQL functions or text
  search configurations would not survive `db/schema.rb`. Any query text must be folded
  with `Tender.fold_accents` before reaching `websearch_to_tsquery`/`to_tsquery`.
- `Tenders::Search` is the single entry point for searching (UI today; API and saved
  searches later). It only returns tenders open for proposals.
- Niche presets live in `config/niches.yml`. Portuguese stemming is aggressive: check
  new keywords with `SELECT to_tsvector('portuguese', 'palavra')` — e.g. "publicidade"
  and "pública" share the stem `public`, so niches use phrases instead of that word.
- `bin/rails db:seed` loads 30 fictional tenders (idempotent) for working offline.

## Accounts and saved searches

- Authentication is the Rails 8 generator's design, written by hand: `User`
  (`has_secure_password`, e-mail normalized to lowercase), `Session` rows referenced by a
  signed http-only cookie, `Current.user`, and the `Authentication` concern. **Every
  controller requires login by default**; public ones call `allow_unauthenticated_access`.
- Login, sign-up and password-reset requests are rate limited (10 per 3 minutes per IP)
  with Rails' `rate_limit`, which counts in `Rails.cache`. Tests use a memory store that is
  cleared before every integration test; in production the cache must be shared by all
  app processes (the default file store is, on a single host).
- Integration tests sign in with `sign_in_as(user)` (no login request, so no rate limit);
  `create_user` and `create_open_tender` live in `test/test_helpers/`.
- The default locale is `pt-BR` (`config/locales/pt-BR.yml`: validation messages and
  attribute names). Missing keys fall back to Rails' English, so number/date helpers keep
  their explicit formats — add Portuguese keys only for what the UI shows.
- `SavedSearch` stores the `Tenders::Search` params: `query` (= `q`), `niche_slug`
  (= `niche`) and the other filters in `filters` jsonb. They are normalized by
  `Tenders::Search` before validation; `saved_search.search` rebuilds the search.
- `SavedSearches::Matcher` = matches of the saved search (open tenders only) that were
  published, updated on the PNCP or first synced since `last_notified_at` (no limit when
  nil) and have no `Notification` row for that search yet. `Notification.record!` writes
  those rows in bulk; the unique index guarantees a tender is never alerted twice per search.

## Daily digest and background jobs

- `SavedSearches::Digest.new(user)` builds one e-mail per user: a section per active
  saved search with `notify_daily`, the 20 most urgent new matches plus a count of the
  rest. `#deliver` sends `DigestMailer#daily` (with `deliver_now`: the sections are not
  serializable and the job already runs in the background), records the tenders shown
  as `Notification`s and sets `last_notified_at` = the moment the matches were looked up,
  for every checked search (even without news). Matches beyond the 20 are **not** recorded
  and fall out of the "since" window: the e-mail says how many there were and links to the
  full results.
- `SendDailyDigestsJob` loops over the users with notifiable searches; one failing user is
  reported to `Rails.error` and does not stop the others. Re-running it only sends news.
- Unsubscribe: `generates_token_for :digest_unsubscribe` (saved search) and
  `:digest_unsubscribe_all` (user); `/unsubscribe/:token` shows a confirmation on GET and
  unsubscribes on POST (also the RFC 8058 one-click POST, so that action skips CSRF).
- Solid Queue runs jobs in production with its tables **in the primary database** (the
  `CreateSolidQueueTables` migration mirrors the gem's `queue_schema.rb`; no
  `connects_to`). When upgrading `solid_queue`, check its release notes for schema changes
  and add a migration. Development keeps the default async adapter; run `bin/jobs` to try
  the recurring schedule. `test/config/recurring_schedule_test.rb` validates
  `config/recurring.yml` with Solid Queue itself and checks the run times.

## JSON API

- `Api::V1::BaseController < ActionController::API`: no cookies/CSRF; `Authorization:
  Bearer <token>` resolved by `ApiToken.authenticate` (SHA-256 digest lookup, `last_used_at`
  written at most once a minute); `rate_limit` 300 / 5 min per token; JSON errors
  `{ error: { code, message, details } }`; `wrap_parameters false` (bodies must use the
  `saved_search` root key).
- Serializers are plain Ruby classes in `app/serializers/api/v1/` taking the record and
  the controller (for URL helpers). Decimal values are strings; times ISO 8601.
- Tender filters are exactly `Tenders::Search`'s; invalid values are ignored and
  `meta.filters` echoes what was applied. Saved search criteria use the same names
  (`q` ↔ `query`, `niche` ↔ `niche_slug`).
- Update `docs/API.md` with every API change.
