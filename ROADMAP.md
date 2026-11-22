# Roadmap

Work is organized in phases. Phase 1 is a one-week bootstrap sprint (day-by-day plan in
[`docs/sprint/PLAN.md`](docs/sprint/PLAN.md)); everything after it is the work ahead.

## Phase 1 — Core product (Nov 17–22, 2026)

- [x] Rails 8.1 skeleton, CI (lib tests, Rails tests, RuboCop, Brakeman)
- [x] PNCP API client: pagination, retries with backoff, 204 handling
- [x] Normalizer: Brasília times, decimals, CNPJ, public PNCP URL
- [x] LGPD: mask CPF numbers in free text
- [x] `tenders` table with Portuguese full-text search column
- [x] Idempotent sync (upsert by PNCP control number) + `SyncRun` audit log
- [x] Public search page: keywords, state, modality, value range, "closing soon"
- [x] Niche presets (marketing & communication, events, IT services)
- [x] Accounts, saved searches and match engine
- [x] Daily digest e-mail + recurring jobs (Solid Queue)
- [x] JSON API v1 (token auth) for the future portal ([`docs/API.md`](docs/API.md))
- [x] Seeds with fictional data
- [x] Sync retries, admin alert e-mail, status page, friendly error pages
- [x] Docker image, deploy guide ([`docs/DEPLOY.md`](docs/DEPLOY.md))

Released as **v0.1.0** ([`CHANGELOG.md`](CHANGELOG.md)); sprint report in
[`docs/sprint/REPORT.md`](docs/sprint/REPORT.md).

## Before a public launch

- [ ] E-mail confirmation before the first digest ([#2](https://github.com/Dhonatan/licitaradar/issues/2))
- [ ] First deploy with real configuration, live sync check, screenshots ([#7](https://github.com/Dhonatan/licitaradar/issues/7))
- [ ] Error reporting service ([#6](https://github.com/Dhonatan/licitaradar/issues/6))
- [ ] Shared cache store for rate limits with more than one web container ([#5](https://github.com/Dhonatan/licitaradar/issues/5))

## Phase 2 — React portal ([#1](https://github.com/Dhonatan/licitaradar/issues/1))

- [ ] React + TypeScript single-page portal consuming the JSON API
- [ ] API additions for the portal: `PATCH` saved searches, niches and modalities lists,
      browser-safe authentication, CORS if on another origin ([#3](https://github.com/Dhonatan/licitaradar/issues/3))
- [ ] Dashboard: open opportunities, deadlines calendar, saved searches
- [ ] Tender detail with documents list (PNCP `/arquivos` endpoint)
- [ ] Shareable filtered views for consultants and their clients

## Phase 3 — Deeper data

- [ ] Download and index tender documents (edital PDFs) for full-text search
- [ ] Results: who won, at what price (contracts and price registration minutes)
- [ ] Market analysis per niche: average prices, most active agencies, competitors
- [ ] Coverage report: which municipalities are (not yet) publishing on the PNCP

## Phase 4 — Business

- [ ] Plans and billing (free tier + paid alerts)
- [ ] WhatsApp / Telegram alerts
- [ ] Document checklist and certificate expiry reminders (CND, FGTS, etc.)
- [ ] Team accounts for consultancies

## Ideas / backlog

- Archive or purge tenders closed for a long time ([#4](https://github.com/Dhonatan/licitaradar/issues/4))
- Webhooks for alerts, CSV/Excel export, public stats page, i18n of the UI (pt-BR first,
  English and Spanish later) ([#8](https://github.com/Dhonatan/licitaradar/issues/8))
- API v1: list the tenders already e-mailed for a search ([#3](https://github.com/Dhonatan/licitaradar/issues/3))
