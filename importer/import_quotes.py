from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from dotenv import load_dotenv

from db import chunked, get_connection
from normalize import (
    classify_tag,
    display_name_from_slug,
    get_case_insensitive,
    normalize_author,
    normalize_quote_text,
    parse_revised_tags,
    quote_hash,
    slugify_tag,
)


@dataclass
class ImportStats:
    total_rows: int = 0
    quotes_inserted: int = 0
    quotes_duplicates: int = 0
    tags_upserted: int = 0
    relations_inserted: int = 0


@dataclass
class NormalizedRow:
    text: str
    author: str | None
    hash: str
    tags: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import quotes into Supabase Postgres")
    parser.add_argument("--input", required=True, help="Path to CSV or JSON file")
    parser.add_argument("--batch-size", type=int, default=1000)
    parser.add_argument("--dry-run", action="store_true", help="Parse only, no database writes")
    parser.add_argument("--commit", action="store_true", help="Write to database")
    return parser.parse_args()


def iter_input_rows(path: Path) -> Iterable[dict[str, Any]]:
    suffix = path.suffix.lower()

    if suffix == ".csv":
        with path.open("r", encoding="utf-8", newline="") as fp:
            reader = csv.DictReader(fp)
            for row in reader:
                yield dict(row)
        return

    if suffix == ".json":
        with path.open("r", encoding="utf-8") as fp:
            payload = json.load(fp)
        if isinstance(payload, list):
            for row in payload:
                if isinstance(row, dict):
                    yield row
        elif isinstance(payload, dict):
            candidates = payload.get("data")
            if isinstance(candidates, list):
                for row in candidates:
                    if isinstance(row, dict):
                        yield row
        return

    if suffix == ".jsonl":
        with path.open("r", encoding="utf-8") as fp:
            for line in fp:
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                if isinstance(row, dict):
                    yield row
        return

    raise ValueError("Input must be .csv, .json, or .jsonl")


def normalize_row(raw: dict[str, Any]) -> NormalizedRow | None:
    quote_raw = get_case_insensitive(raw, "Quote")
    if quote_raw is None:
        quote_raw = get_case_insensitive(raw, "quote")

    author_raw = get_case_insensitive(raw, "Author")
    if author_raw is None:
        author_raw = get_case_insensitive(raw, "author")

    revised_tags_raw = get_case_insensitive(raw, "revised_tags")

    text = normalize_quote_text(quote_raw)
    if not text:
        return None

    author = normalize_author(author_raw)
    row_hash = quote_hash(text, author)

    parsed_tags = parse_revised_tags(revised_tags_raw)
    slugs: list[str] = []
    seen = set()
    for tag in parsed_tags:
        slug = slugify_tag(tag)
        if not slug or slug in seen:
            continue
        seen.add(slug)
        slugs.append(slug)

    return NormalizedRow(text=text, author=author, hash=row_hash, tags=slugs)


def dry_run(rows: list[NormalizedRow]) -> ImportStats:
    stats = ImportStats()
    stats.total_rows = len(rows)

    unique_hashes = {row.hash for row in rows}
    unique_tags = {tag for row in rows for tag in row.tags}
    unique_relations = {(row.hash, tag) for row in rows for tag in row.tags}

    stats.quotes_inserted = len(unique_hashes)
    stats.quotes_duplicates = stats.total_rows - stats.quotes_inserted
    stats.tags_upserted = len(unique_tags)
    stats.relations_inserted = len(unique_relations)
    return stats


def ensure_tags(
    cur: Any,
    tag_slugs: set[str],
    tag_id_cache: dict[str, str],
    stats: ImportStats,
) -> None:
    missing = [slug for slug in sorted(tag_slugs) if slug not in tag_id_cache]
    if missing:
        rows = [
            (slug, display_name_from_slug(slug), classify_tag(slug)) for slug in missing
        ]
        cur.execute(
            """
            with src(slug, display_name, type) as (
              values """
            + ", ".join(["(%s, %s, %s)"] * len(rows))
            + """
            )
            insert into public.tags (slug, display_name, type)
            select slug, display_name, type from src
            on conflict (slug)
            do update set
              display_name = excluded.display_name,
              type = excluded.type,
              is_active = true
            """,
            [value for row in rows for value in row],
        )
        stats.tags_upserted += len(missing)

    cur.execute(
        "select slug, id::text as id from public.tags where slug = any(%s)",
        (sorted(tag_slugs),),
    )
    for row in cur.fetchall():
        tag_id_cache[row["slug"]] = row["id"]


def upsert_quotes(
    cur: Any,
    rows: list[NormalizedRow],
    quote_id_cache: dict[str, str],
    stats: ImportStats,
) -> None:
    by_hash: dict[str, NormalizedRow] = {}
    for row in rows:
        by_hash.setdefault(row.hash, row)

    missing_hashes = [h for h in by_hash if h not in quote_id_cache]
    if missing_hashes:
        quote_rows = [
            (
                by_hash[h].text,
                by_hash[h].author,
                "en",
                "kaggle",
                None,
                h,
            )
            for h in missing_hashes
        ]

        query = (
            "insert into public.quotes (text, author, language, source, source_ref, hash) values "
            + ", ".join(["(%s, %s, %s, %s, %s, %s)"] * len(quote_rows))
            + " on conflict (hash) do nothing returning id::text as id, hash"
        )
        cur.execute(query, [value for row in quote_rows for value in row])
        inserted = cur.fetchall()
        stats.quotes_inserted += len(inserted)

        cur.execute(
            "select hash, id::text as id from public.quotes where hash = any(%s)",
            (missing_hashes,),
        )
        for row in cur.fetchall():
            quote_id_cache[row["hash"]] = row["id"]


def insert_quote_tags(
    cur: Any,
    rows: list[NormalizedRow],
    quote_id_cache: dict[str, str],
    tag_id_cache: dict[str, str],
    stats: ImportStats,
) -> None:
    relation_rows: list[tuple[str, str, int]] = []
    seen_relations = set()

    for row in rows:
        quote_id = quote_id_cache.get(row.hash)
        if not quote_id:
            continue
        for slug in row.tags:
            tag_id = tag_id_cache.get(slug)
            if not tag_id:
                continue
            key = (quote_id, tag_id)
            if key in seen_relations:
                continue
            seen_relations.add(key)
            relation_rows.append((quote_id, tag_id, 1))

    if not relation_rows:
        return

    query = (
        "insert into public.quote_tags (quote_id, tag_id, weight) values "
        + ", ".join(["(%s::uuid, %s::uuid, %s)"] * len(relation_rows))
        + " on conflict (quote_id, tag_id) do nothing returning quote_id"
    )
    cur.execute(query, [value for row in relation_rows for value in row])
    inserted = cur.fetchall()
    stats.relations_inserted += len(inserted)


def run_commit(batch_size: int, rows: list[NormalizedRow]) -> ImportStats:
    stats = ImportStats(total_rows=len(rows))
    quote_id_cache: dict[str, str] = {}
    tag_id_cache: dict[str, str] = {}

    with get_connection() as conn:
        with conn.cursor() as cur:
            for idx, batch in enumerate(chunked(rows, batch_size), start=1):
                batch = list(batch)
                tag_slugs = {tag for row in batch for tag in row.tags}

                if tag_slugs:
                    ensure_tags(cur, tag_slugs, tag_id_cache, stats)

                upsert_quotes(cur, batch, quote_id_cache, stats)
                insert_quote_tags(cur, batch, quote_id_cache, tag_id_cache, stats)

                conn.commit()

                processed = min(idx * batch_size, len(rows))
                if processed % 1000 == 0 or processed == len(rows):
                    print(f"Processed {processed}/{len(rows)} rows")

    stats.quotes_duplicates = stats.total_rows - stats.quotes_inserted
    return stats


def print_summary(stats: ImportStats, dry_run_mode: bool) -> None:
    mode = "DRY-RUN" if dry_run_mode else "COMMIT"
    print(f"\n[{mode}] Import summary")
    print(f"total_rows={stats.total_rows}")
    print(f"quotes_inserted={stats.quotes_inserted}")
    print(f"quotes_duplicates={stats.quotes_duplicates}")
    print(f"tags_upserted={stats.tags_upserted}")
    print(f"relations_inserted={stats.relations_inserted}")


def main() -> None:
    load_dotenv()
    args = parse_args()

    if args.commit and args.dry_run:
        raise SystemExit("Use either --commit or --dry-run, not both")

    dry_run_mode = True
    if args.commit:
        dry_run_mode = False
    elif args.dry_run:
        dry_run_mode = True

    path = Path(args.input)
    if not path.exists():
        raise SystemExit(f"Input file not found: {path}")

    normalized_rows: list[NormalizedRow] = []
    raw_count = 0

    for raw in iter_input_rows(path):
        raw_count += 1
        row = normalize_row(raw)
        if row is None:
            continue
        normalized_rows.append(row)

        if raw_count % 1000 == 0:
            print(f"Parsed {raw_count} input rows")

    if dry_run_mode:
        stats = dry_run(normalized_rows)
    else:
        stats = run_commit(args.batch_size, normalized_rows)

    print_summary(stats, dry_run_mode)


if __name__ == "__main__":
    main()
