-- 0001_init.sql
-- Supabase schema + indexes + RLS policies

create extension if not exists pgcrypto;

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  author text,
  language varchar(8) not null default 'en',
  source text not null default 'kaggle',
  source_ref text,
  hash char(64) not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  display_name text not null,
  type text not null check (type in ('category', 'mood', 'topic', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.quote_tags (
  quote_id uuid not null references public.quotes(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  weight smallint not null default 1,
  primary key (quote_id, tag_id)
);

create table if not exists public.daily_quotes (
  date date primary key,
  quote_id uuid not null references public.quotes(id),
  generated_at timestamptz not null default now(),
  algorithm text
);

create table if not exists public.user_saved_quotes (
  user_id uuid not null references auth.users(id) on delete cascade,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, quote_id)
);

create table if not exists public.quote_events (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete set null,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  event_type text not null check (event_type in ('view', 'share', 'save', 'unsave', 'like', 'unlike', 'session_start')),
  tag_context text,
  feed_type text check (feed_type in ('category', 'mood', 'saved', 'daily')),
  client_ts timestamptz,
  server_ts timestamptz not null default now(),
  metadata jsonb
);

create index if not exists idx_quote_tags_tag_quote on public.quote_tags(tag_id, quote_id);
create index if not exists idx_tags_type on public.tags(type);
create index if not exists idx_user_saved_quotes_user_created on public.user_saved_quotes(user_id, created_at desc);
create index if not exists idx_quote_events_quote_event_type on public.quote_events(quote_id, event_type);
create index if not exists idx_quote_events_user_server_ts on public.quote_events(user_id, server_ts desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_quotes_set_updated_at on public.quotes;
create trigger trg_quotes_set_updated_at
before update on public.quotes
for each row
execute function public.set_updated_at();

create or replace function public.set_daily_quote(
  p_date date default current_date,
  algorithm text default 'random_v1'
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
  order by random()
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

grant usage on schema public to anon, authenticated;

grant select on public.quotes to anon, authenticated;
grant select on public.tags to anon, authenticated;
grant select on public.quote_tags to anon, authenticated;
grant select on public.daily_quotes to anon, authenticated;
grant select, insert, delete on public.user_saved_quotes to authenticated;
grant insert on public.quote_events to anon, authenticated;
grant execute on function public.set_daily_quote(date, text) to service_role;

alter table public.quotes enable row level security;
alter table public.tags enable row level security;
alter table public.quote_tags enable row level security;
alter table public.daily_quotes enable row level security;
alter table public.user_saved_quotes enable row level security;
alter table public.quote_events enable row level security;

-- quotes
 drop policy if exists quotes_read_all on public.quotes;
create policy quotes_read_all
on public.quotes
for select
to anon, authenticated
using (true);

drop policy if exists quotes_no_insert_client on public.quotes;
create policy quotes_no_insert_client
on public.quotes
for insert
to anon, authenticated
with check (false);

drop policy if exists quotes_no_update_client on public.quotes;
create policy quotes_no_update_client
on public.quotes
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists quotes_no_delete_client on public.quotes;
create policy quotes_no_delete_client
on public.quotes
for delete
to anon, authenticated
using (false);

-- tags
 drop policy if exists tags_read_all on public.tags;
create policy tags_read_all
on public.tags
for select
to anon, authenticated
using (true);

drop policy if exists tags_no_insert_client on public.tags;
create policy tags_no_insert_client
on public.tags
for insert
to anon, authenticated
with check (false);

drop policy if exists tags_no_update_client on public.tags;
create policy tags_no_update_client
on public.tags
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists tags_no_delete_client on public.tags;
create policy tags_no_delete_client
on public.tags
for delete
to anon, authenticated
using (false);

-- quote_tags
 drop policy if exists quote_tags_read_all on public.quote_tags;
create policy quote_tags_read_all
on public.quote_tags
for select
to anon, authenticated
using (true);

drop policy if exists quote_tags_no_insert_client on public.quote_tags;
create policy quote_tags_no_insert_client
on public.quote_tags
for insert
to anon, authenticated
with check (false);

drop policy if exists quote_tags_no_update_client on public.quote_tags;
create policy quote_tags_no_update_client
on public.quote_tags
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists quote_tags_no_delete_client on public.quote_tags;
create policy quote_tags_no_delete_client
on public.quote_tags
for delete
to anon, authenticated
using (false);

-- daily_quotes
 drop policy if exists daily_quotes_read_all on public.daily_quotes;
create policy daily_quotes_read_all
on public.daily_quotes
for select
to anon, authenticated
using (true);

drop policy if exists daily_quotes_no_insert_client on public.daily_quotes;
create policy daily_quotes_no_insert_client
on public.daily_quotes
for insert
to anon, authenticated
with check (false);

drop policy if exists daily_quotes_no_update_client on public.daily_quotes;
create policy daily_quotes_no_update_client
on public.daily_quotes
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists daily_quotes_no_delete_client on public.daily_quotes;
create policy daily_quotes_no_delete_client
on public.daily_quotes
for delete
to anon, authenticated
using (false);

-- user_saved_quotes
 drop policy if exists user_saved_quotes_select_own on public.user_saved_quotes;
create policy user_saved_quotes_select_own
on public.user_saved_quotes
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_saved_quotes_insert_own on public.user_saved_quotes;
create policy user_saved_quotes_insert_own
on public.user_saved_quotes
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists user_saved_quotes_delete_own on public.user_saved_quotes;
create policy user_saved_quotes_delete_own
on public.user_saved_quotes
for delete
to authenticated
using (auth.uid() = user_id);

-- quote_events
 drop policy if exists quote_events_insert_auth_own on public.quote_events;
create policy quote_events_insert_auth_own
on public.quote_events
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists quote_events_insert_anon_null_user on public.quote_events;
create policy quote_events_insert_anon_null_user
on public.quote_events
for insert
to anon
with check (user_id is null);

drop policy if exists quote_events_no_select_client on public.quote_events;
create policy quote_events_no_select_client
on public.quote_events
for select
to anon, authenticated
using (false);

drop policy if exists quote_events_no_update_client on public.quote_events;
create policy quote_events_no_update_client
on public.quote_events
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists quote_events_no_delete_client on public.quote_events;
create policy quote_events_no_delete_client
on public.quote_events
for delete
to anon, authenticated
using (false);
