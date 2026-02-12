# Supabase Backend Setup + Kaggle Importer

This guide sets up the Supabase backend and imports Kaggle quotes using `revised_tags` only.

## 1) Create Supabase project

1. Go to Supabase dashboard and create a new project.
2. Wait for DB provisioning to finish.
3. Open **Project Settings -> Database**.
4. Copy the **Connection string** in URI format.

You will use this as `DATABASE_URL`.

## 2) Apply SQL migration

Migration file:
- `supabase/migrations/0001_init.sql`

### Option A: Supabase SQL Editor
1. Open **SQL Editor**.
2. Paste content of `supabase/migrations/0001_init.sql`.
3. Run query.

### Option B: Supabase CLI
1. Install CLI: https://supabase.com/docs/guides/cli
2. Link project:
   ```bash
   supabase link --project-ref <PROJECT_REF>
   ```
3. Push migration:
   ```bash
   supabase db push
   ```

## 3) Setup importer (Python 3.11)

From repo root:

```bash
cd importer
python -m venv .venv
```

Activate venv:

- macOS/Linux:
  ```bash
  source .venv/bin/activate
  ```
- Windows PowerShell:
  ```powershell
  .\.venv\Scripts\Activate.ps1
  ```

Install deps:

```bash
pip install -r requirements.txt
```

Create `.env` from example:

```bash
cp .env.example .env
```

Set:
- `DATABASE_URL=postgresql://postgres:<PASSWORD>@db.<PROJECT-REF>.supabase.co:5432/postgres`
- `PGSSLMODE=require`

## 4) Run importer

### Dry run (no writes)

```bash
python import_quotes.py --input ../data/kaggle_quotes.csv --dry-run
```

### Commit mode (writes to DB)

```bash
python import_quotes.py --input ../data/kaggle_quotes.csv --commit
```

JSON input also supported:

```bash
python import_quotes.py --input ../data/kaggle_quotes.json --commit
python import_quotes.py --input ../data/kaggle_quotes.jsonl --commit
```

Optional batch size:

```bash
python import_quotes.py --input ../data/kaggle_quotes.csv --commit --batch-size 1000
```

## 5) Verify data

Run in SQL editor:

```sql
select count(*) as quotes_count from public.quotes;
select count(*) as tags_count from public.tags;
select count(*) as quote_tags_count from public.quote_tags;

select type, count(*)
from public.tags
group by type
order by type;

select q.id, q.author, left(q.text, 80) as sample_text
from public.quotes q
order by q.created_at desc
limit 10;
```

## Importer behavior

- Uses `revised_tags` only.
- Supports `revised_tags` as comma string, JSON list string, or list.
- Tag normalization:
  - lowercase
  - split comma / JSON parse
  - dedupe and remove empties
  - slugify (`spaces/_ -> -`, remove non-alnum except `-`)
- Tag type classification:
  - mood allowlist -> `mood`
  - otherwise -> `category`
- Quote de-duplication:
  - normalize quote whitespace
  - trim author; empty author stored as `NULL`
  - hash = `sha256(normalized_quote + '|' + normalized_author_or_empty)`
  - insert with `ON CONFLICT (hash) DO NOTHING`
- `quote_tags` relation insert uses `ON CONFLICT DO NOTHING`.
- Logs progress every 1000 rows.
- Prints summary:
  - `total_rows`
  - `quotes_inserted`
  - `quotes_duplicates`
  - `tags_upserted`
  - `relations_inserted`
