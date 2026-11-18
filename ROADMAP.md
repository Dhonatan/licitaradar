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
- [ ] Public search page: keywords, state, modality, value range, "closing soon"
- [ ] Niche presets (marketing & communication, events, IT services)
- [ ] Accounts, saved searches and match engine
- [ ] Daily digest e-mail + recurring jobs (Solid Queue)
- [ ] JSON API v1 (token auth) for the future portal
- [ ] Docker image, deploy guide, seeds with fictional data

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
- CSV/Excel export
- Public stats page (open tenders per state, per niche)
- i18n of the UI (pt-BR first, English and Spanish later)
