-- 0009_quote_virality_scoring.sql
-- Adds quote interaction counters and virality scoring.

alter table public.quotes
  add column if not exists views_count integer not null default 0,
  add column if not exists shares_count integer not null default 0,
  add column if not exists saves_count integer not null default 0,
  add column if not exists virality_score double precision not null default 0;

create index if not exists idx_quotes_virality_score
on public.quotes (virality_score desc);

create or replace function public.compute_quote_virality_score(
  p_views_count bigint,
  p_likes_count bigint,
  p_saves_count bigint,
  p_shares_count bigint
)
returns double precision
language sql
immutable
as $$
  select
    (greatest(coalesce(p_views_count, 0), 0) * 0.1) +
    (greatest(coalesce(p_likes_count, 0), 0) * 1.5) +
    (greatest(coalesce(p_saves_count, 0), 0) * 2.0) +
    (greatest(coalesce(p_shares_count, 0), 0) * 3.0);
$$;

create or replace function public.refresh_quote_engagement_metrics(
  p_quote_id uuid,
  p_refresh_author_stats boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_author text;
  next_likes_count integer := 0;
  next_saves_count integer := 0;
  next_views_count integer := 0;
  next_shares_count integer := 0;
begin
  if p_quote_id is null then
    return;
  end if;

  select canonical_author
  into affected_author
  from public.quotes
  where id = p_quote_id;

  if not found then
    return;
  end if;

  select count(*)::integer
  into next_likes_count
  from public.user_liked_quotes
  where quote_id = p_quote_id;

  select count(*)::integer
  into next_saves_count
  from public.user_saved_quotes
  where quote_id = p_quote_id;

  select count(*)::integer
  into next_views_count
  from public.quote_events
  where quote_id = p_quote_id
    and event_type = 'view';

  select count(*)::integer
  into next_shares_count
  from public.quote_events
  where quote_id = p_quote_id
    and event_type = 'share';

  update public.quotes q
  set likes_count = next_likes_count,
      saves_count = next_saves_count,
      views_count = next_views_count,
      shares_count = next_shares_count,
      popularity_score =
        next_likes_count +
        public.quote_length_quality_score(q.length_tier) +
        public.quote_category_weight(q.categories),
      virality_score = public.compute_quote_virality_score(
        next_views_count,
        next_likes_count,
        next_saves_count,
        next_shares_count
      )
  where q.id = p_quote_id;

  if p_refresh_author_stats then
    perform public.refresh_author_stats_for_names(array[affected_author]);
  end if;
end;
$$;

create or replace function public.adjust_quote_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_quote_id uuid;
begin
  if tg_op = 'DELETE' then
    target_quote_id := old.quote_id;
  else
    target_quote_id := new.quote_id;
  end if;
  perform public.refresh_quote_engagement_metrics(target_quote_id, true);
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.adjust_quote_saves_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_quote_id uuid;
begin
  if tg_op = 'DELETE' then
    target_quote_id := old.quote_id;
  else
    target_quote_id := new.quote_id;
  end if;
  perform public.refresh_quote_engagement_metrics(target_quote_id, false);
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.adjust_quote_event_counters()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_quote_id uuid;
  target_event_type text;
begin
  if tg_op = 'DELETE' then
    target_quote_id := old.quote_id;
    target_event_type := old.event_type;
  else
    target_quote_id := new.quote_id;
    target_event_type := new.event_type;
  end if;

  if target_event_type not in ('view', 'share') then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  perform public.refresh_quote_engagement_metrics(target_quote_id, false);
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.sync_quote_scores_on_counter_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.likes_count := greatest(coalesce(new.likes_count, 0), 0);
  new.saves_count := greatest(coalesce(new.saves_count, 0), 0);
  new.views_count := greatest(coalesce(new.views_count, 0), 0);
  new.shares_count := greatest(coalesce(new.shares_count, 0), 0);

  new.popularity_score :=
    new.likes_count +
    public.quote_length_quality_score(new.length_tier) +
    public.quote_category_weight(new.categories);

  new.virality_score := public.compute_quote_virality_score(
    new.views_count,
    new.likes_count,
    new.saves_count,
    new.shares_count
  );

  return new;
end;
$$;

drop trigger if exists trg_adjust_quote_likes_count on public.user_liked_quotes;
create trigger trg_adjust_quote_likes_count
after insert or delete on public.user_liked_quotes
for each row
execute function public.adjust_quote_likes_count();

drop trigger if exists trg_adjust_quote_saves_count on public.user_saved_quotes;
create trigger trg_adjust_quote_saves_count
after insert or delete on public.user_saved_quotes
for each row
execute function public.adjust_quote_saves_count();

drop trigger if exists trg_adjust_quote_event_counters on public.quote_events;
create trigger trg_adjust_quote_event_counters
after insert or delete on public.quote_events
for each row
execute function public.adjust_quote_event_counters();

drop trigger if exists trg_sync_quote_scores_on_counter_update on public.quotes;
create trigger trg_sync_quote_scores_on_counter_update
before update of views_count, shares_count, saves_count, likes_count, length_tier, categories
on public.quotes
for each row
execute function public.sync_quote_scores_on_counter_update();

update public.quotes q
set likes_count = (
      select count(*)::integer
      from public.user_liked_quotes ulq
      where ulq.quote_id = q.id
    ),
    saves_count = (
      select count(*)::integer
      from public.user_saved_quotes usq
      where usq.quote_id = q.id
    ),
    views_count = (
      select count(*)::integer
      from public.quote_events qe
      where qe.quote_id = q.id
        and qe.event_type = 'view'
    ),
    shares_count = (
      select count(*)::integer
      from public.quote_events qe
      where qe.quote_id = q.id
        and qe.event_type = 'share'
    ),
    popularity_score =
      (
        select count(*)::integer
        from public.user_liked_quotes ulq
        where ulq.quote_id = q.id
      ) +
      public.quote_length_quality_score(q.length_tier) +
      public.quote_category_weight(q.categories),
    virality_score = public.compute_quote_virality_score(
      (
        select count(*)::integer
        from public.quote_events qe
        where qe.quote_id = q.id
          and qe.event_type = 'view'
      ),
      (
        select count(*)::integer
        from public.user_liked_quotes ulq
        where ulq.quote_id = q.id
      ),
      (
        select count(*)::integer
        from public.user_saved_quotes usq
        where usq.quote_id = q.id
      ),
      (
        select count(*)::integer
        from public.quote_events qe
        where qe.quote_id = q.id
          and qe.event_type = 'share'
      )
    )
where true;

do $$
declare
  all_author_names text[];
begin
  select coalesce(
    array_agg(distinct canonical_author),
    array[]::text[]
  )
  into all_author_names
  from public.quotes
  where btrim(coalesce(canonical_author, '')) <> '';

  perform public.refresh_author_stats_for_names(all_author_names);
end
$$;
