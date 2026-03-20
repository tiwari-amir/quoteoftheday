-- 0015_security_hardening.sql
-- Tightens public-schema exposure and fixes mutable function search_path warnings.

grant select on public.authors to anon, authenticated;
revoke insert, update, delete on public.authors from anon, authenticated;

alter table public.authors enable row level security;

drop policy if exists authors_read_all on public.authors;
create policy authors_read_all
on public.authors
for select
to anon, authenticated
using (true);

drop policy if exists authors_no_insert_client on public.authors;
create policy authors_no_insert_client
on public.authors
for insert
to anon, authenticated
with check (false);

drop policy if exists authors_no_update_client on public.authors;
create policy authors_no_update_client
on public.authors
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists authors_no_delete_client on public.authors;
create policy authors_no_delete_client
on public.authors
for delete
to anon, authenticated
using (false);

revoke all on public.quotes_removed_non_english from anon, authenticated;

alter table public.quotes_removed_non_english enable row level security;

drop policy if exists quotes_removed_non_english_no_select_client on public.quotes_removed_non_english;
create policy quotes_removed_non_english_no_select_client
on public.quotes_removed_non_english
for select
to anon, authenticated
using (false);

drop policy if exists quotes_removed_non_english_no_insert_client on public.quotes_removed_non_english;
create policy quotes_removed_non_english_no_insert_client
on public.quotes_removed_non_english
for insert
to anon, authenticated
with check (false);

drop policy if exists quotes_removed_non_english_no_update_client on public.quotes_removed_non_english;
create policy quotes_removed_non_english_no_update_client
on public.quotes_removed_non_english
for update
to anon, authenticated
using (false)
with check (false);

drop policy if exists quotes_removed_non_english_no_delete_client on public.quotes_removed_non_english;
create policy quotes_removed_non_english_no_delete_client
on public.quotes_removed_non_english
for delete
to anon, authenticated
using (false);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_likely_english_quote_text(p_text text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  ch text;
  codepoint int;
  letters int := 0;
  latin_letters int := 0;
begin
  if p_text is null or btrim(p_text) = '' then
    return false;
  end if;

  for ch in
    select regexp_split_to_table(p_text, '')
  loop
    if ch = '' then
      continue;
    end if;

    codepoint := ascii(ch);

    if (codepoint between 65 and 90) or (codepoint between 97 and 122) then
      letters := letters + 1;
      latin_letters := latin_letters + 1;
      continue;
    end if;

    if codepoint between 192 and 591 then
      letters := letters + 1;
      latin_letters := latin_letters + 1;
      continue;
    end if;

    if (codepoint between 880 and 1023)
       or (codepoint between 1024 and 1279)
       or (codepoint between 1424 and 1535)
       or (codepoint between 1536 and 1791)
       or (codepoint between 19968 and 40959) then
      letters := letters + 1;
      continue;
    end if;
  end loop;

  if letters = 0 then
    return false;
  end if;

  return (latin_letters::numeric / letters::numeric) >= 0.78;
end;
$$;

create or replace function public.normalize_quote_hash_text(p_text text)
returns text
language sql
immutable
set search_path = public
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
set search_path = public
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
set search_path = public
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
set search_path = public
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

create or replace function public.compute_author_score(
  p_total_quotes integer,
  p_avg_popularity_score double precision,
  p_total_likes integer
)
returns double precision
language sql
immutable
set search_path = public
as $$
  select
    (ln(greatest(coalesce(p_total_quotes, 0), 0) + 1) * 0.4) +
    (greatest(coalesce(p_avg_popularity_score, 0), 0) * 0.4) +
    (greatest(coalesce(p_total_likes, 0), 0) * 0.2);
$$;

create or replace function public.compute_quote_virality_score(
  p_views_count bigint,
  p_likes_count bigint,
  p_saves_count bigint,
  p_shares_count bigint
)
returns double precision
language sql
immutable
set search_path = public
as $$
  select
    (greatest(coalesce(p_views_count, 0), 0) * 0.1) +
    (greatest(coalesce(p_likes_count, 0), 0) * 1.5) +
    (greatest(coalesce(p_saves_count, 0), 0) * 2.0) +
    (greatest(coalesce(p_shares_count, 0), 0) * 3.0);
$$;
