-- 0004_wikiquote_pipeline.sql
-- Wikiquote-native quote schema + ingestion queue + likes_count maintenance.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

alter table public.quotes
  alter column hash type text using btrim(hash);

alter table public.quotes
  add column if not exists source_url text,
  add column if not exists license text not null default 'CC BY-SA 4.0',
  add column if not exists categories text[] not null default '{}'::text[],
  add column if not exists moods text[] not null default '{}'::text[],
  add column if not exists likes_count bigint not null default 0;

alter table public.quotes
  alter column source set default 'wikiquote';

create unique index if not exists idx_quotes_hash_unique on public.quotes(hash);
create index if not exists idx_quotes_created_at on public.quotes(created_at);
create index if not exists idx_quotes_likes_count on public.quotes(likes_count desc, created_at desc);
create index if not exists idx_quotes_categories_gin on public.quotes using gin(categories);
create index if not exists idx_quotes_moods_gin on public.quotes using gin(moods);
create index if not exists idx_quotes_text_trgm on public.quotes using gin(text gin_trgm_ops);
create index if not exists idx_quotes_author_trgm on public.quotes using gin(author gin_trgm_ops);

-- Backfill category/mood arrays from existing tag relations when available.
with category_rows as (
  select
    qt.quote_id,
    array_agg(distinct lower(t.slug) order by lower(t.slug)) as categories
  from public.quote_tags qt
  join public.tags t on t.id = qt.tag_id
  where t.type in ('category', 'topic', 'other')
  group by qt.quote_id
)
update public.quotes q
set categories = coalesce(cr.categories, '{}'::text[])
from category_rows cr
where q.id = cr.quote_id
  and coalesce(array_length(q.categories, 1), 0) = 0;

with mood_rows as (
  select
    qt.quote_id,
    array_agg(distinct lower(t.slug) order by lower(t.slug)) as moods
  from public.quote_tags qt
  join public.tags t on t.id = qt.tag_id
  where t.type = 'mood'
  group by qt.quote_id
)
update public.quotes q
set moods = coalesce(mr.moods, '{}'::text[])
from mood_rows mr
where q.id = mr.quote_id
  and coalesce(array_length(q.moods, 1), 0) = 0;

update public.quotes
set categories = '{}'::text[]
where categories is null;

update public.quotes
set moods = '{}'::text[]
where moods is null;

create table if not exists public.pages_queue (
  id bigserial primary key,
  page_title text not null unique,
  page_type text not null check (page_type in ('author', 'topic')),
  processed boolean not null default false,
  last_checked timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_pages_queue_processed_checked
on public.pages_queue(processed, last_checked);

alter table public.pages_queue enable row level security;

drop policy if exists pages_queue_no_select_client on public.pages_queue;
create policy pages_queue_no_select_client
on public.pages_queue
for select
to anon, authenticated
using (false);

drop policy if exists pages_queue_no_insert_client on public.pages_queue;
create policy pages_queue_no_insert_client
on public.pages_queue
for insert
to anon, authenticated
with check (false);

drop policy if exists pages_queue_no_update_client on public.pages_queue;
create policy pages_queue_no_update_client
on public.pages_queue
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists pages_queue_no_delete_client on public.pages_queue;
create policy pages_queue_no_delete_client
on public.pages_queue
for delete
to anon, authenticated
using (false);

create or replace function public.adjust_quote_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.quotes
    set likes_count = likes_count + 1
    where id = new.quote_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.quotes
    set likes_count = greatest(0, likes_count - 1)
    where id = old.quote_id;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_adjust_quote_likes_count on public.user_liked_quotes;
create trigger trg_adjust_quote_likes_count
after insert or delete on public.user_liked_quotes
for each row
execute function public.adjust_quote_likes_count();

update public.quotes q
set likes_count = coalesce(src.like_count, 0)
from (
  select quote_id, count(*)::bigint as like_count
  from public.user_liked_quotes
  group by quote_id
) src
where q.id = src.quote_id;

update public.quotes
set likes_count = 0
where likes_count is null;

create or replace function public.get_top_liked_quotes(limit_count int default 12)
returns table (
  quote_id uuid,
  like_count bigint
)
language sql
security definer
set search_path = public
as $$
  select
    q.id as quote_id,
    q.likes_count as like_count
  from public.quotes q
  where q.likes_count > 0
  order by q.likes_count desc, q.created_at desc, q.id
  limit greatest(1, least(limit_count, 50));
$$;

grant execute on function public.get_top_liked_quotes(int) to anon, authenticated;

create or replace function public.set_daily_quote(
  p_date date default current_date,
  algorithm text default 'deterministic_v2'
)
returns public.daily_quotes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote_id uuid;
  v_row public.daily_quotes;
begin
  select q.id
  into v_quote_id
  from public.quotes q
  order by md5(p_date::text || q.id::text)
  limit 1;

  if v_quote_id is null then
    raise exception 'No quotes available in public.quotes';
  end if;

  insert into public.daily_quotes(date, quote_id, algorithm)
  values (p_date, v_quote_id, algorithm)
  on conflict (date)
  do update
    set quote_id = excluded.quote_id,
        generated_at = now(),
        algorithm = excluded.algorithm
  returning * into v_row;

  return v_row;
end;
$$;
