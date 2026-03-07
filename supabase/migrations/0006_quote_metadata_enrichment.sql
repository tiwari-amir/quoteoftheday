-- 0006_quote_metadata_enrichment.sql
-- Adds quote metadata fields used by ingestion and future ranking.

create extension if not exists pgcrypto;

alter table public.quotes
  add column if not exists canonical_author text,
  add column if not exists length_tier text,
  add column if not exists popularity_score integer not null default 0,
  add column if not exists quote_hash text;

alter table public.quotes
  drop constraint if exists quotes_length_tier_check;

alter table public.quotes
  add constraint quotes_length_tier_check
  check (length_tier in ('short', 'medium', 'long'));

create index if not exists idx_quotes_canonical_author
on public.quotes(canonical_author);

create index if not exists idx_quotes_popularity_score
on public.quotes(popularity_score desc, likes_count desc, created_at desc);

create or replace function public.normalize_quote_hash_text(p_text text)
returns text
language sql
immutable
as $$
  select btrim(
    regexp_replace(
      regexp_replace(lower(coalesce(p_text, '')), '[[:punct:]]+', ' ', 'g'),
      '\s+',
      ' ',
      'g'
    )
  );
$$;

create or replace function public.normalize_canonical_author(p_author text)
returns text
language sql
immutable
as $$
  with cleaned as (
    select btrim(
      regexp_replace(
        regexp_replace(lower(coalesce(p_author, '')), '[[:punct:]]+', ' ', 'g'),
        '\s+',
        ' ',
        'g'
      )
    ) as value
  )
  select case
    when value = 'a einstein' then 'albert einstein'
    else value
  end
  from cleaned;
$$;

create or replace function public.quote_length_quality_score(p_length_tier text)
returns integer
language sql
immutable
as $$
  select case
    when lower(coalesce(p_length_tier, '')) = 'medium' then 5
    when lower(coalesce(p_length_tier, '')) = 'short' then 3
    when lower(coalesce(p_length_tier, '')) = 'long' then 2
    else 1
  end;
$$;

create or replace function public.quote_category_weight(p_categories text[])
returns integer
language sql
immutable
as $$
  select coalesce(
    max(
      case
        when lower(item) in ('success', 'motivation', 'love', 'life') then 5
        when lower(item) in ('wisdom', 'philosophy') then 3
        when btrim(item) <> '' then 1
        else 0
      end
    ),
    1
  )
  from unnest(coalesce(p_categories, '{}'::text[])) as item;
$$;

update public.quotes
set canonical_author = public.normalize_canonical_author(author)
where coalesce(canonical_author, '') = '';

update public.quotes
set length_tier = case
  when char_length(btrim(coalesce(text, ''))) < 80 then 'short'
  when char_length(btrim(coalesce(text, ''))) <= 160 then 'medium'
  else 'long'
end
where coalesce(length_tier, '') not in ('short', 'medium', 'long');

update public.quotes
set quote_hash = encode(
  digest(public.normalize_quote_hash_text(text), 'sha1'),
  'hex'
)
where coalesce(quote_hash, '') = '';

do $$
begin
  create temporary table _quote_hash_duplicates
  on commit drop
  as
  with ranked as (
    select
      id,
      quote_hash,
      first_value(id) over (
        partition by quote_hash
        order by created_at asc, id asc
      ) as keep_id,
      row_number() over (
        partition by quote_hash
        order by created_at asc, id asc
      ) as rn
    from public.quotes
    where quote_hash is not null
  )
  select id as duplicate_id, keep_id
  from ranked
  where rn > 1;

  insert into public.quote_tags (quote_id, tag_id, weight)
  select d.keep_id, qt.tag_id, qt.weight
  from _quote_hash_duplicates d
  join public.quote_tags qt on qt.quote_id = d.duplicate_id
  on conflict (quote_id, tag_id) do nothing;

  delete from public.quote_tags qt
  using _quote_hash_duplicates d
  where qt.quote_id = d.duplicate_id;

  insert into public.user_saved_quotes (user_id, quote_id, created_at)
  select usq.user_id, d.keep_id, usq.created_at
  from _quote_hash_duplicates d
  join public.user_saved_quotes usq on usq.quote_id = d.duplicate_id
  on conflict (user_id, quote_id) do nothing;

  delete from public.user_saved_quotes usq
  using _quote_hash_duplicates d
  where usq.quote_id = d.duplicate_id;

  insert into public.user_liked_quotes (user_id, quote_id, created_at)
  select ulq.user_id, d.keep_id, ulq.created_at
  from _quote_hash_duplicates d
  join public.user_liked_quotes ulq on ulq.quote_id = d.duplicate_id
  on conflict (user_id, quote_id) do nothing;

  delete from public.user_liked_quotes ulq
  using _quote_hash_duplicates d
  where ulq.quote_id = d.duplicate_id;

  update public.daily_quotes dq
  set quote_id = d.keep_id
  from _quote_hash_duplicates d
  where dq.quote_id = d.duplicate_id;

  update public.quote_events qe
  set quote_id = d.keep_id
  from _quote_hash_duplicates d
  where qe.quote_id = d.duplicate_id;

  delete from public.quotes q
  using _quote_hash_duplicates d
  where q.id = d.duplicate_id;
end
$$;

update public.quotes
set hash = quote_hash
where quote_hash is not null
  and hash is distinct from quote_hash;

update public.quotes
set popularity_score =
  coalesce(likes_count, 0) +
  public.quote_length_quality_score(length_tier) +
  public.quote_category_weight(categories);

alter table public.quotes
  alter column quote_hash set not null;

create unique index if not exists idx_quotes_quote_hash_unique
on public.quotes(quote_hash);

create or replace function public.adjust_quote_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.quotes
    set likes_count = likes_count + 1,
        popularity_score = popularity_score + 1
    where id = new.quote_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.quotes
    set likes_count = greatest(0, likes_count - 1),
        popularity_score = greatest(0, popularity_score - 1)
    where id = old.quote_id;
    return old;
  end if;

  return null;
end;
$$;
