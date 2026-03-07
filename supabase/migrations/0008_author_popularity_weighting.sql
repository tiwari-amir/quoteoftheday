-- 0008_author_popularity_weighting.sql
-- Adds author-level aggregate scoring and mirrors author_score onto quotes.

create table if not exists public.authors (
  id bigserial primary key,
  name text not null,
  canonical_name text not null,
  total_quotes integer not null default 0,
  avg_popularity_score double precision not null default 0,
  total_likes integer not null default 0,
  author_score double precision not null default 0,
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'authors_canonical_name_key'
      and conrelid = 'public.authors'::regclass
  ) then
    alter table public.authors
      add constraint authors_canonical_name_key unique (canonical_name);
  end if;
end
$$;

create unique index if not exists idx_authors_canonical_name
on public.authors(canonical_name);

alter table public.quotes
  add column if not exists author_score double precision not null default 0;

create index if not exists idx_quotes_author_score
on public.quotes(author_score desc);

create or replace function public.compute_author_score(
  p_total_quotes integer,
  p_avg_popularity_score double precision,
  p_total_likes integer
)
returns double precision
language sql
immutable
as $$
  select
    (ln(greatest(coalesce(p_total_quotes, 0), 0) + 1) * 0.4) +
    (greatest(coalesce(p_avg_popularity_score, 0), 0) * 0.4) +
    (greatest(coalesce(p_total_likes, 0), 0) * 0.2);
$$;

create or replace function public.refresh_author_stats_for_names(p_canonical_names text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_names text[];
begin
  select coalesce(
    array_agg(distinct public.normalize_canonical_author(item)),
    array[]::text[]
  )
  into normalized_names
  from unnest(coalesce(p_canonical_names, array[]::text[])) as item
  where btrim(coalesce(item, '')) <> '';

  if coalesce(array_length(normalized_names, 1), 0) = 0 then
    return;
  end if;

  insert into public.authors (
    name,
    canonical_name,
    total_quotes,
    avg_popularity_score,
    total_likes,
    author_score,
    updated_at
  )
  select
    coalesce(
      (
        array_agg(q.author order by char_length(q.author) desc, q.author asc)
        filter (where btrim(coalesce(q.author, '')) <> '')
      )[1],
      initcap(q.canonical_author)
    ) as name,
    q.canonical_author as canonical_name,
    count(*)::integer as total_quotes,
    coalesce(avg(q.popularity_score), 0)::double precision as avg_popularity_score,
    coalesce(sum(q.likes_count), 0)::integer as total_likes,
    public.compute_author_score(
      count(*)::integer,
      coalesce(avg(q.popularity_score), 0)::double precision,
      coalesce(sum(q.likes_count), 0)::integer
    ) as author_score,
    now() as updated_at
  from public.quotes q
  where q.canonical_author = any(normalized_names)
    and btrim(coalesce(q.canonical_author, '')) <> ''
  group by q.canonical_author
  on conflict (canonical_name) do update
  set name = excluded.name,
      total_quotes = excluded.total_quotes,
      avg_popularity_score = excluded.avg_popularity_score,
      total_likes = excluded.total_likes,
      author_score = excluded.author_score,
      updated_at = now();

  delete from public.authors a
  where a.canonical_name = any(normalized_names)
    and not exists (
      select 1
      from public.quotes q
      where q.canonical_author = a.canonical_name
    );

  update public.quotes q
  set author_score = coalesce(a.author_score, 0)
  from public.authors a
  where q.canonical_author = a.canonical_name
    and q.canonical_author = any(normalized_names);

  update public.quotes q
  set author_score = 0
  where q.canonical_author = any(normalized_names)
    and not exists (
      select 1
      from public.authors a
      where a.canonical_name = q.canonical_author
    );
end;
$$;

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

create or replace function public.adjust_quote_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_author text;
begin
  if tg_op = 'INSERT' then
    update public.quotes
    set likes_count = likes_count + 1,
        popularity_score = popularity_score + 1
    where id = new.quote_id
    returning canonical_author into affected_author;

    perform public.refresh_author_stats_for_names(array[affected_author]);
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.quotes
    set likes_count = greatest(0, likes_count - 1),
        popularity_score = greatest(0, popularity_score - 1)
    where id = old.quote_id
    returning canonical_author into affected_author;

    perform public.refresh_author_stats_for_names(array[affected_author]);
    return old;
  end if;

  return null;
end;
$$;
