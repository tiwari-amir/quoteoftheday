create or replace function public.prune_app_notifications(
  p_keep_latest integer default 10
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  safe_keep integer := greatest(coalesce(p_keep_latest, 10), 0);
  deleted_count integer := 0;
begin
  with stale as (
    select id
    from public.app_notifications
    order by created_at desc, id desc
    offset safe_keep
  ),
  deleted as (
    delete from public.app_notifications
    where id in (select id from stale)
    returning 1
  )
  select count(*)::integer into deleted_count
  from deleted;

  return deleted_count;
end;
$$;

create or replace function public.enforce_app_notifications_retention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.prune_app_notifications(10);
  return null;
end;
$$;

drop trigger if exists trg_app_notifications_keep_latest on public.app_notifications;

create trigger trg_app_notifications_keep_latest
after insert on public.app_notifications
for each statement
execute function public.enforce_app_notifications_retention();

select public.prune_app_notifications(10);
