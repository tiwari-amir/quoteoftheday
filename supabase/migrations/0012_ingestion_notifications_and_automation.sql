-- 0012_ingestion_notifications_and_automation.sql
-- Discovery run tracking, public app notifications, and daily dispatch helpers.

create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.ingestion_runs (
  id bigserial primary key,
  run_type text not null check (
    run_type in ('discover', 'bootstrap', 'seed', 'cleanup', 'dedupe', 'cluster', 'reset')
  ),
  trigger_source text not null default 'manual',
  pages_processed integer not null default 0,
  quotes_inserted integer not null default 0,
  quotes_total integer not null default 0,
  pruned_quotes integer not null default 0,
  duplicates_skipped integer not null default 0,
  new_pages_discovered integer not null default 0,
  database_size_bytes bigint,
  quotes_table_bytes bigint,
  started_at timestamptz not null default now(),
  completed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_ingestion_runs_run_type_completed_at
on public.ingestion_runs(run_type, completed_at desc);

create table if not exists public.app_notifications (
  id bigserial primary key,
  notification_type text not null,
  title text not null,
  body text not null,
  action_route text not null default '/updates',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_notifications_created_at
on public.app_notifications(created_at desc);

create index if not exists idx_app_notifications_type_created_at
on public.app_notifications(notification_type, created_at desc);

grant select on public.app_notifications to anon, authenticated;

alter table public.ingestion_runs enable row level security;
alter table public.app_notifications enable row level security;

drop policy if exists ingestion_runs_no_select_client on public.ingestion_runs;
create policy ingestion_runs_no_select_client
on public.ingestion_runs
for select
to anon, authenticated
using (false);

drop policy if exists ingestion_runs_no_insert_client on public.ingestion_runs;
create policy ingestion_runs_no_insert_client
on public.ingestion_runs
for insert
to anon, authenticated
with check (false);

drop policy if exists ingestion_runs_no_update_client on public.ingestion_runs;
create policy ingestion_runs_no_update_client
on public.ingestion_runs
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists ingestion_runs_no_delete_client on public.ingestion_runs;
create policy ingestion_runs_no_delete_client
on public.ingestion_runs
for delete
to anon, authenticated
using (false);

drop policy if exists app_notifications_read_all on public.app_notifications;
create policy app_notifications_read_all
on public.app_notifications
for select
to anon, authenticated
using (true);

drop policy if exists app_notifications_no_insert_client on public.app_notifications;
create policy app_notifications_no_insert_client
on public.app_notifications
for insert
to anon, authenticated
with check (false);

drop policy if exists app_notifications_no_update_client on public.app_notifications;
create policy app_notifications_no_update_client
on public.app_notifications
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists app_notifications_no_delete_client on public.app_notifications;
create policy app_notifications_no_delete_client
on public.app_notifications
for delete
to anon, authenticated
using (false);

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    begin
      alter publication supabase_realtime add table public.app_notifications;
    exception
      when duplicate_object then null;
    end;
  end if;
end
$$;

create or replace function public.unschedule_quoteflow_daily_discovery_dispatch()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'quoteflow_daily_discovery_dispatch'
  limit 1;

  if existing_job_id is null then
    return false;
  end if;

  perform cron.unschedule(existing_job_id);
  return true;
end;
$$;

-- The schedule expression is interpreted in the pg_cron timezone, which is UTC on Supabase by default.
create or replace function public.schedule_quoteflow_daily_discovery_dispatch(
  p_function_url text,
  p_bearer_token text,
  p_hour integer default 15,
  p_minute integer default 0,
  p_limit integer default 200
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  safe_url text := btrim(coalesce(p_function_url, ''));
  safe_token text := btrim(coalesce(p_bearer_token, ''));
  safe_hour integer := greatest(0, least(coalesce(p_hour, 15), 23));
  safe_minute integer := greatest(0, least(coalesce(p_minute, 0), 59));
  safe_limit integer := greatest(1, least(coalesce(p_limit, 200), 1000));
  schedule_text text;
  command_text text;
  job_id bigint;
begin
  if safe_url = '' then
    raise exception 'p_function_url is required';
  end if;

  if safe_token = '' then
    raise exception 'p_bearer_token is required';
  end if;

  perform public.unschedule_quoteflow_daily_discovery_dispatch();

  schedule_text := format('%s %s * * *', safe_minute, safe_hour);
  command_text := format(
    $job$
      select net.http_post(
        url := %L,
        headers := jsonb_build_object(
          'Authorization',
          %L,
          'Content-Type',
          'application/json'
        ),
        body := jsonb_build_object(
          'trigger',
          'supabase_cron',
          'limit',
          %s
        )
      ) as request_id;
    $job$,
    safe_url,
    format('Bearer %s', safe_token),
    safe_limit
  );

  select cron.schedule(
    'quoteflow_daily_discovery_dispatch',
    schedule_text,
    command_text
  )
  into job_id;

  return job_id;
end;
$$;

revoke all on function public.schedule_quoteflow_daily_discovery_dispatch(text, text, integer, integer, integer) from public;
revoke all on function public.unschedule_quoteflow_daily_discovery_dispatch() from public;
grant execute on function public.schedule_quoteflow_daily_discovery_dispatch(text, text, integer, integer, integer) to service_role;
grant execute on function public.unschedule_quoteflow_daily_discovery_dispatch() to service_role;
