-- 0002_social_likes.sql
-- Adds persistent likes and aggregate likes RPC for client consumption.

create table if not exists public.user_liked_quotes (
  user_id uuid not null references auth.users(id) on delete cascade,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, quote_id)
);

create index if not exists idx_user_liked_quotes_quote on public.user_liked_quotes(quote_id, created_at desc);
create index if not exists idx_user_liked_quotes_user_created on public.user_liked_quotes(user_id, created_at desc);

grant select, insert, delete on public.user_liked_quotes to authenticated;

alter table public.user_liked_quotes enable row level security;

drop policy if exists user_liked_quotes_select_own on public.user_liked_quotes;
create policy user_liked_quotes_select_own
on public.user_liked_quotes
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_liked_quotes_insert_own on public.user_liked_quotes;
create policy user_liked_quotes_insert_own
on public.user_liked_quotes
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists user_liked_quotes_delete_own on public.user_liked_quotes;
create policy user_liked_quotes_delete_own
on public.user_liked_quotes
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.get_top_liked_quotes(limit_count int default 12)
returns table (
  quote_id uuid,
  like_count bigint
)
language sql
security definer
set search_path = public
as $$
  select ulq.quote_id, count(*) as like_count
  from public.user_liked_quotes ulq
  group by ulq.quote_id
  order by like_count desc, ulq.quote_id
  limit greatest(1, least(limit_count, 50));
$$;

grant execute on function public.get_top_liked_quotes(int) to anon, authenticated;
