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
- [ ] Docker image, deploy guide

## Phase 2 — React portal

- [ ] React + TypeScript single-page portal consuming the JSON API
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

- Webhooks for alerts
- E-mail address confirmation before the first digest
- API v1: update a saved search (`PATCH`), list the tenders already e-mailed for a search
- CSV/Excel export
- Public stats page (open tenders per state, per niche)
- i18n of the UI (pt-BR first, English and Spanish later)
