# Wikiquote Ingestion Pipeline

This folder contains the ingestion pipeline that grows the Supabase quote
dataset from Wikiquote through the MediaWiki API.

Pipeline:

Wikimedia canonical snapshots -> parser/mapper -> Supabase (`quotes`, `pages_queue`)

## Files

- `wikiquote_ingest.py`: queue-driven ingestion runner.
- `wikiquote_parser.py`: wikitext quote extraction and cleanup.
- `wikiquote_category_mapper.py`: category + mood mapping layer.
- `db.py`: PostgreSQL/Supabase connection helper.

## Source Model

QuoteFlow now treats Wikimedia as the canonical source and Supabase as the
product source:

- Wikimedia page snapshots are cached locally in `importer/.canonical_wikimedia/wikiquote`
  by default.
- The importer parses those canonical snapshots and writes only the filtered,
  product-ready rows into Supabase.
- Cached snapshots are refreshed automatically when stale, or can be force-refreshed
  with `--refresh-canonical-cache`.

## Requirements

Install dependencies:

```bash
pip install -r requirements.txt
```

Configure `.env` with:

- `DATABASE_URL=postgresql://...`
- `PGSSLMODE=require` (recommended for Supabase)

## Dry Run

Dry-run mode fetches seed categories and parses pages without DB writes:

```bash
python wikiquote_ingest.py --limit 20
```

Force-refresh canonical Wikimedia snapshots during a run:

```bash
python wikiquote_ingest.py --limit 20 --refresh-canonical-cache
```

## Commit Mode

Commit mode writes to Supabase, updates `pages_queue`, and upserts quotes:

```bash
python wikiquote_ingest.py --commit
```

First ingestion (seed + larger one-time limit):

```bash
python wikiquote_ingest.py --seed --limit 120 --commit
```

Incremental daily/weekly ingestion (safe batch size):

```bash
python wikiquote_ingest.py --limit 40 --commit
```

## Scheduler

Run daily or weekly via cron / task scheduler:

```bash
# daily at 03:00
0 3 * * * cd /path/to/repo/importer && /path/to/python wikiquote_ingest.py --commit
```

## Data Guarantees

- Uses MediaWiki API (`https://en.wikiquote.org/w/api.php`), no HTML scraping.
- Caches canonical Wikimedia page snapshots locally before transforming them.
- Stores `source_url` for attribution.
- Stores `license = CC BY-SA 4.0`.
- Deduplicates using `SHA1(normalized_quote_text)` in `quotes.hash`.
- Maintains and expands `pages_queue` from discovered internal links.
- Rate-limits API traffic to roughly 1 request/sec with additional 429 backoff.
- Retries failed pages up to 3 times, then marks them skipped.
