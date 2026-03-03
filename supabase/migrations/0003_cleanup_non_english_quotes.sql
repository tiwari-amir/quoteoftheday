-- 0003_cleanup_non_english_quotes.sql
-- Database-level cleanup for non-English quotes.
-- Safe to run multiple times:
-- 1) Archives removed rows in public.quotes_removed_non_english.
-- 2) Removes dependent daily_quotes rows for those quote ids.
-- 3) Deletes non-English rows from public.quotes.

create table if not exists public.quotes_removed_non_english (
  id uuid primary key,
  text text not null,
  author text,
  language varchar(8) not null,
  source text not null,
  source_ref text,
  hash char(64) not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  removed_at timestamptz not null default now(),
  removal_reason text not null
);

create or replace function public.is_likely_english_quote_text(p_text text)
returns boolean
language plpgsql
immutable
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

    -- ASCII Latin letters
    if (codepoint between 65 and 90) or (codepoint between 97 and 122) then
      letters := letters + 1;
      latin_letters := latin_letters + 1;
      continue;
    end if;

    -- Extended Latin letters (U+00C0..U+024F)
    if codepoint between 192 and 591 then
      letters := letters + 1;
      latin_letters := latin_letters + 1;
      continue;
    end if;

    -- Additional script blocks used for denominator to detect non-Latin-heavy text
    if (codepoint between 880 and 1023)      -- Greek
       or (codepoint between 1024 and 1279)  -- Cyrillic
       or (codepoint between 1424 and 1535)  -- Hebrew
       or (codepoint between 1536 and 1791)  -- Arabic
       or (codepoint between 19968 and 40959) then -- CJK Unified Ideographs
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

do $$
declare
  v_to_remove_count int := 0;
  v_archived_count int := 0;
  v_daily_removed_count int := 0;
  v_quotes_removed_count int := 0;
begin
  create temporary table _cleanup_non_english_ids
  on commit drop
  as
  with candidates as (
    select
      q.id,
      case
        when lower(coalesce(q.language, '')) not in ('en', 'en-us', 'en-gb', 'eng')
          then 'language_code'
        else 'content_heuristic'
      end as removal_reason
    from public.quotes q
    where lower(coalesce(q.language, '')) not in ('en', 'en-us', 'en-gb', 'eng')
       or not public.is_likely_english_quote_text(coalesce(q.text, '') || ' ' || coalesce(q.author, ''))
  )
  select * from candidates;

  select count(*) into v_to_remove_count from _cleanup_non_english_ids;

  insert into public.quotes_removed_non_english (
    id,
    text,
    author,
    language,
    source,
    source_ref,
    hash,
    created_at,
    updated_at,
    removed_at,
    removal_reason
  )
  select
    q.id,
    q.text,
    q.author,
    q.language,
    q.source,
    q.source_ref,
    q.hash,
    q.created_at,
    q.updated_at,
    now(),
    c.removal_reason
  from public.quotes q
  join _cleanup_non_english_ids c on c.id = q.id
  on conflict (id) do nothing;

  get diagnostics v_archived_count = row_count;

  delete from public.daily_quotes dq
  where dq.quote_id in (select id from _cleanup_non_english_ids);

  get diagnostics v_daily_removed_count = row_count;

  delete from public.quotes q
  where q.id in (select id from _cleanup_non_english_ids);

  get diagnostics v_quotes_removed_count = row_count;

  raise notice 'Non-English cleanup summary: candidates=%, archived=%, daily_quotes_removed=%, quotes_removed=%',
    v_to_remove_count,
    v_archived_count,
    v_daily_removed_count,
    v_quotes_removed_count;
end
$$;

