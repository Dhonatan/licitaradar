# LicitaRadar

**Open public tenders for your niche, without combing through government portals one by one.**

LicitaRadar watches Brazil's national public procurement portal — the
[PNCP (Portal Nacional de Contratações Públicas)](https://pncp.gov.br) — and turns its
raw open data into something a small business can actually use: a searchable list of
tenders that are **still open for proposals**, filtered for a niche (e.g. marketing,
events, IT services), plus daily e-mail alerts before the deadline.

> 🇧🇷 **Resumo:** o LicitaRadar coleta diariamente as licitações abertas no PNCP, faz busca
> em português (a API oficial ignora filtros de palavra-chave) e manda alertas por e-mail
> para empresas pequenas que querem vender para o governo sem pagar caro por isso.

## Who it is for

- Small and medium Brazilian companies (agencies, event producers, IT and service
  providers) that want to sell to the government but can't afford enterprise
  procurement-monitoring tools.
- Consultants who track tenders for several clients.

## Why

Since Law 14.133/2021, every public purchase in Brazil has to be published on the PNCP,
which exposes a free, open query API. In practice the API is hard to use directly:

- keyword filters are silently ignored — you get every tender, not the ones you asked for;
- results are split by modality and paginated, and the service is slow and flaky;
- dates come in Brasília local time without offsets, values are sometimes `0` (confidential);
- free-text fields occasionally contain personal data (CPF numbers).

LicitaRadar handles all of that once, so users only see relevant, clean opportunities.

## Status

🚧 **Early development (started November 2026).** See [`ROADMAP.md`](ROADMAP.md) and the
day-by-day log in [`docs/sprint/`](docs/sprint).

| Area | State |
| --- | --- |
| PNCP API client (pagination, retries, 204 handling) | ✅ done, tested |
| Record normalization (Brasília times, decimals, CNPJ, public URL) | ✅ done, tested |
| LGPD: CPF masking in free-text fields | ✅ done, tested |
| Persistence + daily sync | ⏳ in progress |
| Search UI, saved searches, e-mail alerts | 🗓️ planned |
| JSON API + React portal | 🗓️ planned |

## Built with

- **Ruby 3.3 / Rails 8.1** (Hotwire, Propshaft, import maps — no Node build step)
- **PostgreSQL** (Portuguese full-text search)
- **Minitest** + WebMock, **RuboCop** (rails-omakase), **Brakeman**
- GitHub Actions CI

The PNCP integration lives in [`lib/pncp`](lib/pncp) as plain Ruby with **no Rails
dependency**, so it can be tested and reused on its own.

## Getting started

Requirements: Ruby 3.3.6, PostgreSQL 14+.

```bash
git clone https://github.com/Dhonatan/licitaradar.git
cd licitaradar
cp .env.example .env        # adjust DB credentials if needed
bin/setup                   # installs gems and prepares the database
bin/rails server            # http://localhost:3000
```

Try the PNCP client against the real API (no database needed):

```bash
bin/pncp-probe          # open "Pregão Eletrônico" tenders
bin/pncp-probe 8 PE     # open "Dispensa" tenders in Pernambuco
```

## Running tests

```bash
bin/test-lib            # fast, framework-independent tests (plain Ruby + Minitest)
bin/rails test          # full suite (needs PostgreSQL)
bin/rubocop             # style
bin/brakeman            # security scan
```

## Project layout

```
lib/pncp/            PNCP API client, normalizer, PII scrubber (no Rails)
app/                 Rails app (models, jobs, controllers, views)
test/lib/            tests for lib/ — run with bin/test-lib
test/                Rails tests
docs/sprint/         day-by-day plan and log of the bootstrap sprint
```

## Data & privacy

- Only **public** procurement data from the PNCP is collected (open government data,
  Lei 14.133/2021, art. 174).
- CPF numbers found in free-text fields are masked before storage.
- The repository contains **only fictional sample data** (see `test/fixtures`).

## Contributing

Issues and pull requests are welcome. Please run `bin/test-lib`, `bin/rails test` and
`bin/rubocop` before opening a PR.

## License

[MIT](LICENSE) © 2026 Dhonatan
