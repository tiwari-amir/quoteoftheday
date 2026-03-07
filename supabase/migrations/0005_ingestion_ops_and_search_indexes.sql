-- 0005_ingestion_ops_and_search_indexes.sql
-- Operational safety columns + explicit search/index additions.

create extension if not exists pg_trgm;

alter table public.pages_queue
  add column if not exists retry_count integer not null default 0,
  add column if not exists skipped boolean not null default false,
  add column if not exists last_error text;

create index if not exists idx_pages_queue_ops
on public.pages_queue(processed, skipped, retry_count, last_checked);

-- Requested indexes (exact names).
create index if not exists idx_quotes_author on public.quotes(author);
create index if not exists idx_quotes_categories on public.quotes using gin(categories);
create index if not exists idx_quotes_moods on public.quotes using gin(moods);
create index if not exists idx_quotes_text_search
on public.quotes using gin(to_tsvector('simple', text));

-- Keep hash dedupe unique for SHA1(text)-based ingestion.
create unique index if not exists idx_quotes_hash_unique_sha1 on public.quotes(hash);
