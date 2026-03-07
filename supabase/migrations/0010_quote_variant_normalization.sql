-- 0010_quote_variant_normalization.sql
-- Adds canonical normalized quote fields and merges punctuation-only variants.

create extension if not exists pgcrypto;

alter table public.quotes
  add column if not exists normalized_text text,
  add column if not exists normalized_quote_hash text,
  add column if not exists normalized_quote text,
  add column if not exists occurrence_count integer not null default 1;

update public.quotes
set normalized_text = public.normalize_quote_hash_text(text)
where coalesce(normalized_text, '') = '';

update public.quotes
set normalized_quote = normalized_text
where coalesce(normalized_quote, '') = ''
  and coalesce(normalized_text, '') <> '';

update public.quotes
set normalized_quote_hash = encode(
  digest(coalesce(normalized_text, ''), 'sha1'),
  'hex'
)
where coalesce(normalized_quote_hash, '') = ''
  and coalesce(normalized_text, '') <> '';

update public.quotes
set occurrence_count = greatest(coalesce(occurrence_count, 0), 1)
where occurrence_count is null
   or occurrence_count < 1;

do $$
begin
  create temporary table _normalized_quote_ranked
  on commit drop
  as
  with ranked as (
    select
      q.id,
      q.normalized_quote_hash,
      first_value(q.id) over (
        partition by q.normalized_quote_hash
        order by
          coalesce(q.popularity_score, 0) desc,
          coalesce(q.likes_count, 0) desc,
          greatest(coalesce(q.occurrence_count, 1), 1) desc,
          q.created_at asc,
          q.id asc
      ) as keep_id,
      row_number() over (
        partition by q.normalized_quote_hash
        order by
          coalesce(q.popularity_score, 0) desc,
          coalesce(q.likes_count, 0) desc,
          greatest(coalesce(q.occurrence_count, 1), 1) desc,
          q.created_at asc,
          q.id asc
      ) as rn
    from public.quotes q
    where coalesce(q.normalized_quote_hash, '') <> ''
  )
  select *
  from ranked;

  create temporary table _normalized_quote_keepers
  on commit drop
  as
  with grouped as (
    select
      r.keep_id,
      r.normalized_quote_hash,
      sum(greatest(coalesce(q.occurrence_count, 1), 1)) as total_occurrence,
      max(coalesce(q.popularity_score, 0)) as max_popularity
    from _normalized_quote_ranked r
    join public.quotes q on q.id = r.id
    group by r.keep_id, r.normalized_quote_hash
  ),
  categories as (
    select
      r.keep_id,
      coalesce(array_agg(distinct item order by item), '{}'::text[]) as merged_categories
    from _normalized_quote_ranked r
    join public.quotes q on q.id = r.id
    left join lateral unnest(coalesce(q.categories, '{}'::text[])) as item on true
    group by r.keep_id
  ),
  moods as (
    select
      r.keep_id,
      coalesce(array_agg(distinct item order by item), '{}'::text[]) as merged_moods
    from _normalized_quote_ranked r
    join public.quotes q on q.id = r.id
    left join lateral unnest(coalesce(q.moods, '{}'::text[])) as item on true
    group by r.keep_id
  )
  select
    g.keep_id,
    g.normalized_quote_hash,
    g.total_occurrence,
    g.max_popularity,
    c.merged_categories,
    m.merged_moods
  from grouped g
  left join categories c on c.keep_id = g.keep_id
  left join moods m on m.keep_id = g.keep_id;

  create temporary table _normalized_quote_duplicates
  on commit drop
  as
  select id as duplicate_id, keep_id
  from _normalized_quote_ranked
  where rn > 1;

  update public.quotes q
  set normalized_text = public.normalize_quote_hash_text(q.text),
      normalized_quote = public.normalize_quote_hash_text(q.text),
      normalized_quote_hash = k.normalized_quote_hash,
      occurrence_count = greatest(k.total_occurrence, 1),
      popularity_score = greatest(coalesce(q.popularity_score, 0), k.max_popularity),
      categories = coalesce(k.merged_categories, '{}'::text[]),
      moods = coalesce(k.merged_moods, '{}'::text[])
  from _normalized_quote_keepers k
  where q.id = k.keep_id;

  insert into public.quote_tags (quote_id, tag_id, weight)
  select d.keep_id, qt.tag_id, max(qt.weight)
  from _normalized_quote_duplicates d
  join public.quote_tags qt on qt.quote_id = d.duplicate_id
  group by d.keep_id, qt.tag_id
  on conflict (quote_id, tag_id) do update set
    weight = greatest(public.quote_tags.weight, excluded.weight);

  delete from public.quote_tags qt
  using _normalized_quote_duplicates d
  where qt.quote_id = d.duplicate_id;

  insert into public.user_saved_quotes (user_id, quote_id, created_at)
  select usq.user_id, d.keep_id, usq.created_at
  from _normalized_quote_duplicates d
  join public.user_saved_quotes usq on usq.quote_id = d.duplicate_id
  on conflict (user_id, quote_id) do nothing;

  delete from public.user_saved_quotes usq
  using _normalized_quote_duplicates d
  where usq.quote_id = d.duplicate_id;

  insert into public.user_liked_quotes (user_id, quote_id, created_at)
  select ulq.user_id, d.keep_id, ulq.created_at
  from _normalized_quote_duplicates d
  join public.user_liked_quotes ulq on ulq.quote_id = d.duplicate_id
  on conflict (user_id, quote_id) do nothing;

  delete from public.user_liked_quotes ulq
  using _normalized_quote_duplicates d
  where ulq.quote_id = d.duplicate_id;

  update public.daily_quotes dq
  set quote_id = d.keep_id
  from _normalized_quote_duplicates d
  where dq.quote_id = d.duplicate_id;

  update public.quote_events qe
  set quote_id = d.keep_id
  from _normalized_quote_duplicates d
  where qe.quote_id = d.duplicate_id;

  delete from public.quotes q
  using _normalized_quote_duplicates d
  where q.id = d.duplicate_id;
end
$$;

update public.quotes
set normalized_text = public.normalize_quote_hash_text(text),
    normalized_quote = public.normalize_quote_hash_text(text),
    normalized_quote_hash = encode(
      digest(public.normalize_quote_hash_text(text), 'sha1'),
      'hex'
    )
where coalesce(normalized_text, '') = ''
   or coalesce(normalized_quote_hash, '') = ''
   or coalesce(normalized_quote, '') = '';

update public.quotes
set quote_hash = normalized_quote_hash,
    hash = normalized_quote_hash
where coalesce(normalized_quote_hash, '') <> ''
  and (
    quote_hash is distinct from normalized_quote_hash
    or hash is distinct from normalized_quote_hash
  );

create index if not exists idx_quotes_normalized_text
on public.quotes(normalized_text);

create unique index if not exists idx_quotes_normalized_hash
on public.quotes(normalized_quote_hash);
