-- 0011_quote_similarity_clustering.sql
-- Adds quote clustering metadata for near-duplicate suppression.

alter table public.quotes
  add column if not exists quote_cluster_id text,
  add column if not exists cluster_size integer not null default 1;

update public.quotes
set cluster_size = greatest(coalesce(cluster_size, 0), 1)
where cluster_size is null
   or cluster_size < 1;

update public.quotes
set quote_cluster_id = coalesce(
  nullif(quote_cluster_id, ''),
  nullif(normalized_quote_hash, ''),
  nullif(quote_hash, ''),
  nullif(hash, ''),
  id::text
)
where coalesce(quote_cluster_id, '') = '';

create index if not exists idx_quotes_quote_cluster_id
on public.quotes(quote_cluster_id);
