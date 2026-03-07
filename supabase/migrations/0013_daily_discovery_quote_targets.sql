drop function if exists public.schedule_quoteflow_daily_discovery_dispatch(
  text,
  text,
  integer,
  integer,
  integer
);

-- The schedule expression is interpreted in the pg_cron timezone, which is UTC on Supabase by default.
create or replace function public.schedule_quoteflow_daily_discovery_dispatch(
  p_function_url text,
  p_bearer_token text,
  p_hour integer default 15,
  p_minute integer default 0,
  p_limit integer default 500,
  p_min_quotes_goal integer default 50
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
  safe_limit integer := greatest(1, least(coalesce(p_limit, 500), 1000));
  safe_min_quotes_goal integer := greatest(0, least(coalesce(p_min_quotes_goal, 50), 250));
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
          %s,
          'min_quotes_goal',
          %s
        )
      ) as request_id;
    $job$,
    safe_url,
    format('Bearer %s', safe_token),
    safe_limit,
    safe_min_quotes_goal
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

revoke all on function public.schedule_quoteflow_daily_discovery_dispatch(text, text, integer, integer, integer, integer) from public;
grant execute on function public.schedule_quoteflow_daily_discovery_dispatch(text, text, integer, integer, integer, integer) to service_role;
