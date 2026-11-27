# LicitaRadar API v1

JSON API over the same data as the website: search the tenders that are open for
proposals, manage your saved searches (whose new matches arrive in the daily e-mail) and
the tenders you watch.
It is the base for the future React portal and for integrations (CRMs, spreadsheets, bots).

- Base URL: `https://<your-host>/api/v1` (locally `http://localhost:3000/api/v1`)
- Requests and responses are JSON (`Content-Type: application/json` when sending a body).
- Times are ISO 8601 in Brasília time (`2026-11-25T14:00:00-03:00`).
- Money values are **decimal strings** (`"15000.0"`) so no precision is lost.

## Authentication

Every request needs a personal API token. Create one while signed in at **`/api_tokens`**
(menu "API"). The token (`lr_…`) is shown **only once**; only a hash is stored. Revoke it on
the same page at any time.

Send it in the `Authorization` header:

```bash
export LR_TOKEN="lr_..."   # your token
curl -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/tenders
```

Missing, unknown or revoked tokens get `401 Unauthorized` with a
`WWW-Authenticate: Bearer realm="LicitaRadar"` header.

## Rate limit

300 requests per 5 minutes per token. Above that the API answers `429 Too Many Requests`;
wait a few minutes and try again.

## Errors

Errors always have the same shape:

```json
{ "error": { "code": "not_found", "message": "Registro não encontrado." } }
```

| Status | `code` | When |
| --- | --- | --- |
| 400 | `bad_request` | Invalid JSON or missing `saved_search` object |
| 401 | `unauthorized` | Missing or invalid token |
| 404 | `not_found` | Unknown id, or a saved search of another account |
| 422 | `invalid` | Validation failed; `details` lists the messages per field |
| 429 | `rate_limited` | Too many requests |

Messages are in Portuguese (they can be shown to end users as they are).

---

## Tenders

### `GET /api/v1/tenders`

Searches the tenders **open for proposals**, exactly like the website's search.

| Param | Example | Notes |
| --- | --- | --- |
| `q` | `buffet`, `"agência de publicidade"`, `buffet -casamento`, `palco OR som` | Free text, web-search syntax, accents ignored, Portuguese stemming |
| `niche` | `marketing-comunicacao`, `eventos`, `tecnologia-informacao` | Niche preset (`config/niches.yml`) |
| `states[]` or `states` | `states[]=PE&states[]=PB` or `states=PE,PB` | UFs |
| `modality_ids[]` or `modality_ids` | `modality_ids=6,8` | PNCP modality ids (6 = Pregão eletrônico, 8 = Dispensa, …) |
| `min_value`, `max_value` | `1500`, `1500.50`, `1.500,50` | Estimated value in BRL |
| `closing_within` | `7` | Proposals close in the next N days |
| `sort` | `relevance`, `closing`, `value` | Default: `relevance` with `q`/`niche`, otherwise `closing` (closest deadline first) |
| `page` | `2` | 1-based |
| `per_page` | `50` | 1–100, default 25 |

Invalid values are **ignored**, not rejected (like on the website): check `meta.filters`
to see what was applied.

```bash
curl -H "Authorization: Bearer $LR_TOKEN" \
  "http://localhost:3000/api/v1/tenders?q=buffet&states=PE,PB&closing_within=15&per_page=2"
```

```json
{
  "data": [
    {
      "id": 42,
      "pncp_control_number": "00000000000191-1-000123/2026",
      "year": 2026,
      "sequence": 123,
      "purchase_number": "90012/2026",
      "process_number": "2026.0001",
      "object": "Contratação de serviço de buffet para eventos institucionais",
      "additional_info": null,
      "modality": { "id": 6, "name": "Pregão - Eletrônico" },
      "dispute_mode": "Aberto",
      "status": { "id": 1, "name": "Divulgada no PNCP" },
      "open_for_proposals": true,
      "price_registration": true,
      "estimated_value": "48000.0",
      "confidential_value": false,
      "awarded_value": null,
      "proposals_open_at": "2026-11-20T08:00:00-03:00",
      "proposals_close_at": "2026-11-28T09:00:00-03:00",
      "published_at": "2026-11-19T17:12:03-03:00",
      "source_updated_at": "2026-11-19T17:12:03-03:00",
      "agency": { "cnpj": "00000000000191", "name": "Prefeitura Municipal de Exemplópolis", "sphere": "M", "power": "E" },
      "unit": { "code": "001", "name": "Secretaria de Administração" },
      "location": { "city": "Exemplópolis", "state": "PE", "ibge_code": "2600000" },
      "links": {
        "self": "http://localhost:3000/api/v1/tenders/42",
        "page": "http://localhost:3000/tenders/42",
        "pncp": "https://pncp.gov.br/app/editais/00000000000191/2026/123",
        "origin": "https://compras.example.com/edital/123"
      }
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 2,
    "total_count": 7,
    "total_pages": 4,
    "next_page": 2,
    "previous_page": null,
    "sort": "relevance",
    "filters": { "q": "buffet", "states": ["PE", "PB"], "closing_within": 15 }
  }
}
```

Field notes:

- `estimated_value` is `null` and `confidential_value` is `true` when the agency did not
  publish the estimate (the PNCP sends `0` for "orçamento sigiloso").
- `agency.sphere`: `F` federal, `E` state, `M` municipal, `D` district;
  `agency.power`: `E` executive, `L` legislative, `J` judiciary.
- `links.origin` is the agency's purchasing system (only `http(s)` URLs); `links.page` is
  the tender's page on LicitaRadar.

### `GET /api/v1/tenders/:id`

One tender, open or not: the same fields as above, inside `data`, plus its **documents**
and **items** as published on the PNCP.

```bash
curl -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/tenders/42
```

```json
{
  "data": {
    "id": 42,
    "…": "same fields as in the list",
    "details": { "status": "available", "fetched_at": "2026-11-26T10:00:00-03:00" },
    "documents": [
      {
        "sequence": 1,
        "title": "Edital do Pregão Eletrônico 45/2026",
        "type": { "id": 2, "name": "Edital" },
        "url": "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/123/arquivos/1",
        "published_at": "2026-11-19T17:12:03-03:00"
      }
    ],
    "items": [
      {
        "number": 1,
        "description": "Serviço de buffet tipo coquetel para 200 pessoas",
        "kind": "service",
        "quantity": "4.0",
        "unit": "Evento",
        "unit_estimated_value": "12000.0",
        "total_estimated_value": "48000.0",
        "confidential_value": false,
        "status": "Em Andamento",
        "judgment_criterion": "Menor preço",
        "benefit": "Sem benefício",
        "category": "Não se aplica",
        "source_updated_at": "2026-11-19T17:12:03-03:00"
      }
    ]
  }
}
```

Documents and items are fetched from the PNCP **on demand**, in the background: the first
request for a tender (here or on its web page) starts the fetch, and a new one starts when
the tender changes on the PNCP (at most once every 10 minutes per tender).

| `details.status` | Meaning | `documents` / `items` |
| --- | --- | --- |
| `available` | Fetched and current | lists (`[]` when the PNCP has none) |
| `refreshing` | Fetched, but the tender changed on the PNCP since; a new fetch is under way | the previous lists |
| `pending` | Never fetched; the fetch is under way — ask again in a few seconds | `null` |
| `unavailable` | The PNCP reference (agency CNPJ, year, sequence) is incomplete, nothing to fetch | `null` |

Field notes:

- `documents[].url` downloads the file from the PNCP (only `http(s)` URLs; `null` otherwise).
  Documents the PNCP marks as removed are not listed.
- `items[].kind`: `material` or `service`. Values are decimal strings; `unit_estimated_value`
  and `total_estimated_value` are `null` and `confidential_value` is `true` when the item's
  budget is confidential ("orçamento sigiloso").
- The list endpoint (`GET /api/v1/tenders`) does not include `details`, `documents` or
  `items`. Its `q` and `niche` filters do match item descriptions of tenders whose items
  were already fetched.

---

## Saved searches

A saved search stores search criteria; when `notify_daily` is on (and `active`), its new
matches are e-mailed every morning. Accounts can have up to 20 saved searches. Only the
token owner's searches are visible.

### `GET /api/v1/saved_searches`

```bash
curl -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/saved_searches
```

```json
{
  "data": [
    {
      "id": 7,
      "name": "Buffet em PE",
      "criteria": {
        "q": "buffet",
        "niche": "eventos",
        "states": ["PE"],
        "modality_ids": [],
        "min_value": null,
        "max_value": "50000",
        "closing_within": null
      },
      "active": true,
      "notify_daily": true,
      "last_notified_at": "2026-11-21T07:00:04-03:00",
      "created_at": "2026-11-20T10:31:00-03:00",
      "updated_at": "2026-11-21T07:00:04-03:00",
      "links": {
        "self": "http://localhost:3000/api/v1/saved_searches/7",
        "tenders": "http://localhost:3000/api/v1/tenders?max_value=50000&niche=eventos&q=buffet&states%5B%5D=PE",
        "page": "http://localhost:3000/tenders?max_value=50000&niche=eventos&q=buffet&states%5B%5D=PE"
      }
    }
  ]
}
```

`links.tenders` lists the search's current open tenders through `GET /api/v1/tenders`.

### `GET /api/v1/saved_searches/:id`

One saved search (same fields, inside `data`).

### `POST /api/v1/saved_searches`

The body must have a `saved_search` object. Criteria use the same names as the tenders
filters (`q`, `niche`, `states`, `modality_ids`, `min_value`, `max_value`,
`closing_within`) — at least one is required. Optional: `name` (default: built from the
criteria), `notify_daily` (default `true`), `active` (default `true`).

```bash
curl -X POST http://localhost:3000/api/v1/saved_searches \
  -H "Authorization: Bearer $LR_TOKEN" -H "Content-Type: application/json" \
  -d '{ "saved_search": { "name": "Eventos no Nordeste", "niche": "eventos", "states": ["PE", "PB"], "max_value": "50000" } }'
```

`201 Created` with the saved search in `data` and its URL in the `Location` header.
Validation errors return `422`:

```json
{
  "error": {
    "code": "invalid",
    "message": "Nicho não está incluído na lista",
    "details": { "niche": ["não está incluído na lista"] }
  }
}
```

### `DELETE /api/v1/saved_searches/:id`

```bash
curl -X DELETE -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/saved_searches/7
```

`204 No Content`.

## Watches

The tenders the token owner follows ("Minhas licitações" on the website), up to 500 per
account. Watched tenders get deadline reminders by e-mail (setting on "Minha conta") and
appear in the user's calendar feed. Only the token owner's watches are visible.

### `GET /api/v1/watches`

All watches, tenders still open for proposals first (closest deadline first), then the
closed ones (most recently closed first). Not paginated.

```bash
curl -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/watches
```

```json
{
  "data": [
    {
      "id": 31,
      "tender_id": 1042,
      "proposals_status": "open",
      "note": "Pedir certidões até sexta",
      "reminded_close_at": null,
      "created_at": "2026-11-27T09:12:44-03:00",
      "tender": { "id": 1042, "object": "Contratação de empresa para organização de eventos", "...": "same fields as GET /api/v1/tenders" },
      "links": { "self": "http://localhost:3000/api/v1/watches/31" }
    }
  ]
}
```

- `proposals_status`: `open`, `closing_today` (still open, closes today in Brasília
  time), `closed` or `unknown` (published without a deadline).
- `note`: the user's private note (plain text, up to 5,000 characters) or `null`.
- `reminded_close_at`: the deadline the last reminder e-mail was about (`null` if none
  was sent). A deadline moved by the PNCP is reminded again.

### `POST /api/v1/watches`

The body must have a `watch` object with `tender_id` and, optionally, `note`.

```bash
curl -X POST http://localhost:3000/api/v1/watches \
  -H "Authorization: Bearer $LR_TOKEN" -H "Content-Type: application/json" \
  -d '{ "watch": { "tender_id": 1042, "note": "Pedir certidões até sexta" } }'
```

`201 Created` with the watch in `data` and its URL in the `Location` header. Watching a
tender that is already watched answers `200 OK` with the existing watch; its note is
replaced only when the body has a `note` (send `null` to remove it). Unknown tenders
answer `404`; a note that is too long or the 500-watch limit answer `422` (`invalid`).

### `DELETE /api/v1/watches/:id`

`:id` is the watch id (`data[].id`), not the tender id.

```bash
curl -X DELETE -H "Authorization: Bearer $LR_TOKEN" http://localhost:3000/api/v1/watches/31
```

`204 No Content`.

---

## Not in v1 yet

Updating a saved search (`PATCH`), listing the tenders already e-mailed for a search, and
creating tokens through the API (tokens are managed on the website). See `ROADMAP.md`.
