# Performance notes

How the search queries use the database, what the tests guard and what to watch as the
data grows. Measured on Nov 22, 2026 with PostgreSQL 16 and a synthetic `tenders` table
of **60,000 rows** (72% open for proposals, 8 kinds of objects, 8 states), built with the
same generated `searchable` column and indexes as `db/schema.rb`.

## Indexes on `tenders`

| Index | Used by |
| --- | --- |
| `index_tenders_on_searchable` (GIN) | keyword search (`websearch_to_tsquery`) and niches (`to_tsquery`) |
| `index_tenders_on_proposals_close_at` | `open_for_proposals`, `closing_within`, default sort (closing date) |
| `index_tenders_on_state`, `..._modality_id`, `..._status_id` | filters, when selective |
| `index_tenders_on_pncp_control_number` (unique) | `upsert_all` in `Tenders::Sync` |

`notifications` has a unique index on `(saved_search_id, tender_id)`, used by
`SavedSearches::Matcher` to skip tenders already e-mailed.

## Query plans (EXPLAIN ANALYZE, 60k rows)

| Query (as built by `Tenders::Search`) | Plan | Time |
| --- | --- | --- |
| Open tenders, sorted by closing date, page 1 | Index Scan on `proposals_close_at` + incremental sort, stops after 25 rows | 2.4 ms |
| Same + `states=PE,PB` + `closing_within=7` | Index Scan on `proposals_close_at` (range) | 0.7 ms |
| Keyword "agencia de publicidade", by relevance | Bitmap Index Scan on `searchable` (GIN) + top-N sort by `ts_rank` | 13 ms |
| Niche (OR of phrases), by relevance | Bitmap Index Scan on `searchable` (GIN) | 17 ms |
| `COUNT(*)` of a keyword search | Bitmap Index Scan on `searchable` | 4.6 ms |
| `COUNT(*)` of all open tenders | Seq Scan (72% of the rows match, cheaper than an index) | 21 ms |
| Sorted by value | Seq Scan + top-N heapsort (no index on `estimated_value`) | 14 ms |

Everything stays well under 50 ms, so no index was added. The keyword search confirms
that the query text (folded with `Tender.fold_accents`) matches the generated column's
expression: the GIN index is used.

## What the tests guard

- `test/db/search_query_plan_test.rb` disables sequential scans for the transaction and
  checks that keyword and niche searches use the GIN index, that every kind of search
  can be answered with an index, and that the matcher uses the notifications index.
  It fails if someone changes the `searchable` expression or the SQL in a way that
  stops matching the index.
- `test/integration/query_counts_test.rb` (N+1 guard) checks that the results page and
  the API indexes run the same number of queries for 1 or 25 records.

Known, accepted per-record queries:

- "Minhas buscas" runs one `COUNT` per saved search to show "Ver N licitações abertas"
  (at most `SavedSearch::MAX_PER_USER` = 20 searches).
- The daily digest runs the matcher per saved search (one query for the tenders, one
  `COUNT` when there are more than 20 matches), per user, in a background job.

## What to watch as the data grows

- **Closed tenders are never deleted.** The PNCP has tens of thousands of open tenders at
  any time; after months the table will be mostly closed ones (with their `raw` jsonb).
  The `proposals_close_at` index keeps the open-tender queries fast, but table size,
  backups and `VACUUM` grow. A purge or archive task for tenders closed for more than N
  months is in the backlog.
- If sorting by value gets slow (hundreds of thousands of open rows), add a partial index
  `ON tenders (estimated_value DESC NULLS LAST) WHERE status_id = 1`.
- `COUNT(*)` of all open tenders (home page and results without filters) is a sequential
  scan; with much more data, cache it for a few minutes (`Rails.cache`).
- Deep pagination uses `OFFSET` (capped at page 400 by `Tenders::Search::MAX_PAGE`).
- Re-run the plans with real data: `EXPLAIN (ANALYZE, BUFFERS)` on the SQL logged in
  development (`bin/rails server`, then search).
