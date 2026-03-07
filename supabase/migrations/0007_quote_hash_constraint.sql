do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.quotes'::regclass
      and conname = 'quotes_quote_hash_key'
  ) then
    return;
  end if;

  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'idx_quotes_quote_hash_unique'
      and c.relkind = 'i'
  ) then
    alter table public.quotes
      add constraint quotes_quote_hash_key
      unique using index idx_quotes_quote_hash_unique;
  else
    alter table public.quotes
      add constraint quotes_quote_hash_key
      unique (quote_hash);
  end if;
end $$;
