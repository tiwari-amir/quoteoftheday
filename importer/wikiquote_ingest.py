from __future__ import annotations

import argparse
import json
import math
import os
import re
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote as urlquote

import requests
from dotenv import load_dotenv

from db import chunked, get_connection
from wikiquote_category_mapper import infer_page_type, map_page_tags, normalize_text
from wikiquote_parser import (
    QuoteCandidate,
    canonicalize_author,
    classify_length_tier,
    compute_quote_hash_from_normalized,
    evaluate_quote_candidate,
    extract_quote_candidates,
    extract_page_categories,
    jaccard_similarity,
    normalize_quote_text,
    quote_similarity_tokens,
    sanitize_quote_text,
    validate_author_name,
)

WIKIQUOTE_API_URL = "https://en.wikiquote.org/w/api.php"
WIKIQUOTE_LICENSE = "CC BY-SA 4.0"
DISCOVERY_NOTIFICATION_TYPE = "discovery_summary"
DISCOVERY_NOTIFICATION_ROUTE = "/updates"
APP_NOTIFICATION_RETENTION_LIMIT = 10
REQUEST_INTERVAL_SECONDS = 0.5
MAX_PARSE_WIKITEXT_CHARS = 300_000
MAX_PARSE_WIKITEXT_LINES = 6_000
MAX_PAGES_QUEUE_SIZE = 50_000
MAX_NEW_PAGES_PER_RUN = 200
DEFAULT_SEEDS = [
    "Love",
    "Life",
    "Philosophy",
    "Humor",
    "Films",
    "Television",
    "Religion",
    "Poetry",
]
SOURCE_PRESTIGE = {
    "authors": 5,
    "speeches": 5,
    "literature": 4,
    "films": 4,
    "tv_shows": 3,
    "topics": 3,
}
SEED_REGISTRY = {
    "authors": [
        "Albert Einstein",
        "Mahatma Gandhi",
        "Nelson Mandela",
        "Martin Luther King Jr.",
        "Steve Jobs",
        "Oscar Wilde",
        "Mark Twain",
        "Friedrich Nietzsche",
        "Confucius",
        "Laozi",
        "Buddha",
        "Dalai Lama",
        "Winston Churchill",
        "Theodore Roosevelt",
        "Abraham Lincoln",
        "Benjamin Franklin",
        "Rumi",
        "William Shakespeare",
        "George Orwell",
        "Leo Tolstoy",
        "Maya Angelou",
        "Marcus Aurelius",
        "Epictetus",
        "Seneca",
        "Voltaire",
        "Ralph Waldo Emerson",
        "Henry David Thoreau",
        "Carl Jung",
        "Sigmund Freud",
        "Plato",
        "Aristotle",
    ],
    "films": [
        "The Godfather",
        "The Dark Knight",
        "Rocky",
        "Dead Poets Society",
        "Forrest Gump",
        "The Lord of the Rings",
        "Star Wars",
        "Interstellar",
        "The Matrix",
        "Good Will Hunting",
    ],
    "tv_shows": [
        "Game of Thrones",
        "Breaking Bad",
        "BoJack Horseman",
        "The Office",
        "Friends",
        "Sherlock",
        "The Sopranos",
    ],
    "literature": [
        "Hamlet",
        "Macbeth",
        "The Prophet",
        "Meditations",
        "Tao Te Ching",
        "The Art of War",
        "Bhagavad Gita",
    ],
    "speeches": [
        "I Have a Dream",
        "Gettysburg Address",
        "We Shall Fight on the Beaches",
        "Tear Down This Wall",
    ],
    "topics": [
        "Life",
        "Success",
        "Happiness",
        "Change",
        "Courage",
        "Hope",
        "Failure",
        "Time",
        "Ambition",
        "Balance",
        "Inspiration",
        "Motivation",
        "Work",
        "Leadership",
        "Attitude",
        "Determination",
        "Focus",
        "Preparation",
        "Excellence",
        "Hard Work",
        "Love",
        "Friendship",
        "Family",
        "Kindness",
        "Forgiveness",
        "Trust",
        "Loneliness",
        "Beauty",
        "Gratitude",
        "Empathy",
        "Wisdom",
        "Education",
        "Science",
        "Art",
        "Politics",
        "Religion",
        "War",
        "Truth",
        "Freedom",
        "Justice",
        "Funny",
        "Movies",
        "Television",
        "Books",
        "Sports",
        "Music",
        "Proverbs",
        "Epitaphs",
        "Slogans",
        "Misquotations",
    ],
}
TOP_QUOTES_PER_PAGE = 3
TOP_QUOTES_PER_PAGE_BOOTSTRAP = 3
MIN_GLOBAL_POPULARITY_SCORE = 10
MIN_QUOTE_SCORE_BOOTSTRAP = 10
DISCOVERY_ENABLE_QUOTE_THRESHOLD = 1000
DISCOVERY_PRIME_QUEUE_SIZE = 500
DISCOVERY_LINKS_PER_PRESTIGE_PAGE = 40
HIGH_CULTURAL_SOURCE_TYPES = {"speeches", "literature", "films"}
MEDIUM_CULTURAL_SOURCE_TYPES = {"authors", "tv_shows"}
HIGH_QUALITY_LINK_BONUS = 2
TOPIC_PAGE_MATCH_BONUS = 2
CLUSTER_SIMILARITY_THRESHOLD = 0.75
SAFE_DATABASE_STORAGE_BYTES = int(0.49 * (1024**3))
STORAGE_RECLAIM_BUFFER_BYTES = 2 * 1024 * 1024
FALLBACK_AVG_QUOTE_STORAGE_BYTES = 2_048
MIN_PRUNE_BATCH_SIZE = 5
MAX_PRUNE_BATCH_SIZE = 400
SOURCE_PRESTIGE_HINTS = {
    "speeches": (
        "speech",
        "speeches",
        "address",
        "addresses",
        "oration",
        "lecture",
        "lectures",
        "remarks",
        "sermon",
        "sermons",
        "talk",
        "talks",
    ),
    "literature": (
        "literature",
        "book",
        "books",
        "novel",
        "novels",
        "poem",
        "poetry",
        "play",
        "plays",
        "writer",
        "writers",
    ),
    "films": ("film", "films", "movie", "movies", "cinema"),
    "tv_shows": (
        "tv",
        "tv show",
        "tv shows",
        "television",
        "series",
        "sitcom",
        "episode",
        "episodes",
        "season",
        "seasons",
    ),
}


@dataclass(frozen=True)
class SeedPage:
    title: str
    source_type: str
    page_type: str
    prestige: int


@dataclass
class QuoteRecord:
    text: str
    normalized_text: str
    normalized_quote_hash: str
    quote_cluster_id: str
    cluster_size: int
    token_signature: tuple[str, ...]
    author: str
    canonical_author: str
    source_ref: str
    source_url: str
    categories: list[str]
    moods: list[str]
    length_tier: str
    popularity_score: int
    occurrence_count: int
    quote_hash: str
    hash: str


@dataclass
class IngestStats:
    seed_pages_enqueued: int = 0
    pages_processed: int = 0
    new_pages_discovered: int = 0
    pages_failed: int = 0
    pages_skipped: int = 0
    quotes_parsed: int = 0
    quotes_inserted: int = 0
    inserted_top_quotes: int = 0
    duplicates_skipped: int = 0
    quotes_rejected: int = 0
    rejected_bad_author: int = 0
    rejected_commentary: int = 0
    rejected_metadata: int = 0
    rejected_title_like: int = 0
    rejected_low_confidence: int = 0
    rejected_low_score: int = 0
    pruned_quotes: int = 0
    quotes_total_after: int = 0
    database_size_bytes_before: int = 0
    database_size_bytes_after: int = 0
    quotes_table_bytes_after: int = 0


@dataclass
class QuoteBuildResult:
    records: list[QuoteRecord]
    rejected_total: int = 0
    inserted_top_quotes: int = 0
    rejected_bad_author: int = 0
    rejected_commentary: int = 0
    rejected_metadata: int = 0
    rejected_title_like: int = 0
    rejected_low_confidence: int = 0
    rejected_low_score: int = 0


@dataclass(frozen=True)
class GlobalPopularityBreakdown:
    total: int
    occurrence_count: int
    iconic_phrase_score: int
    aphorism_structure_score: int
    cultural_source_score: int
    author_reputation_score: int
    cross_page_frequency_score: int
    parser_quality_score: int


@dataclass(frozen=True)
class StorageMetrics:
    database_bytes: int
    quotes_table_bytes: int
    quote_count: int
    avg_quote_bytes: int


@dataclass(frozen=True)
class StoragePruneResult:
    deleted_count: int
    deleted_quote_ids: list[str]
    deleted_canonical_authors: list[str]


@dataclass(frozen=True)
class ExistingQuoteState:
    normalized_text: str
    normalized_quote_hash: str
    occurrence_count: int
    popularity_score: int


@dataclass
class QuoteClusterState:
    cluster_id: str
    quote_id: str | None
    text: str
    normalized_text: str
    normalized_quote_hash: str
    author: str
    canonical_author: str
    source_ref: str
    source_url: str
    categories: list[str]
    moods: list[str]
    length_tier: str
    popularity_score: int
    occurrence_count: int
    cluster_size: int
    token_signature: tuple[str, ...]
    member_hashes: set[str]


@dataclass(frozen=True)
class DiscoveredPage:
    page_title: str
    page_type: str
    page_priority: int


class QuoteClusterIndex:
    def __init__(self) -> None:
        self._clusters: dict[str, QuoteClusterState] = {}
        self._token_index: dict[str, set[str]] = {}
        self._hash_to_cluster_id: dict[str, str] = {}

    @property
    def clusters(self) -> dict[str, QuoteClusterState]:
        return self._clusters

    def known_hash(self, normalized_quote_hash: str) -> bool:
        return normalized_quote_hash in self._hash_to_cluster_id

    def owner_quote_id(self, normalized_quote_hash: str) -> str | None:
        cluster_id = self._hash_to_cluster_id.get(normalized_quote_hash)
        if not cluster_id:
            return None
        cluster = self._clusters.get(cluster_id)
        if cluster is None:
            return None
        return cluster.quote_id

    def get_cluster(self, cluster_id: str) -> QuoteClusterState | None:
        return self._clusters.get(cluster_id)

    def find_best_match(
        self,
        normalized_quote_hash: str,
        token_signature: tuple[str, ...],
    ) -> tuple[QuoteClusterState | None, float]:
        direct_cluster_id = self._hash_to_cluster_id.get(normalized_quote_hash)
        if direct_cluster_id:
            direct_cluster = self._clusters.get(direct_cluster_id)
            if direct_cluster is not None:
                return (direct_cluster, 1.0)

        if not token_signature:
            return (None, 0.0)

        candidate_cluster_ids: set[str] = set()
        for token in token_signature:
            candidate_cluster_ids.update(self._token_index.get(token, set()))
        if not candidate_cluster_ids:
            return (None, 0.0)

        best_cluster: QuoteClusterState | None = None
        best_similarity = 0.0
        for cluster_id in candidate_cluster_ids:
            cluster = self._clusters.get(cluster_id)
            if cluster is None:
                continue
            similarity = jaccard_similarity(token_signature, cluster.token_signature)
            if similarity < CLUSTER_SIMILARITY_THRESHOLD:
                continue
            if (
                best_cluster is None
                or similarity > best_similarity
                or (
                    similarity == best_similarity
                    and (
                        cluster.popularity_score,
                        cluster.occurrence_count,
                        cluster.cluster_size,
                    )
                    > (
                        best_cluster.popularity_score,
                        best_cluster.occurrence_count,
                        best_cluster.cluster_size,
                    )
                )
            ):
                best_cluster = cluster
                best_similarity = similarity
        return (best_cluster, best_similarity)

    def register_cluster(self, cluster: QuoteClusterState) -> None:
        self._clusters[cluster.cluster_id] = cluster
        for token in cluster.token_signature:
            self._token_index.setdefault(token, set()).add(cluster.cluster_id)
        for member_hash in cluster.member_hashes:
            if member_hash:
                self._hash_to_cluster_id[member_hash] = cluster.cluster_id

    def replace_cluster(self, cluster: QuoteClusterState) -> None:
        previous = self._clusters.get(cluster.cluster_id)
        if previous is not None:
            for token in previous.token_signature:
                cluster_ids = self._token_index.get(token)
                if cluster_ids:
                    cluster_ids.discard(cluster.cluster_id)
                    if not cluster_ids:
                        self._token_index.pop(token, None)
            for member_hash in previous.member_hashes:
                if self._hash_to_cluster_id.get(member_hash) == cluster.cluster_id:
                    self._hash_to_cluster_id.pop(member_hash, None)
        self.register_cluster(cluster)


class QuoteFrequencyTracker:
    def __init__(self) -> None:
        self._pages_by_normalized_hash: dict[str, set[str]] = {}

    def register_page_quotes(self, page_title: str, normalized_quote_hashes: set[str]) -> None:
        normalized_page = normalize_text(page_title)
        if not normalized_page:
            return
        for normalized_quote_hash in normalized_quote_hashes:
            if not normalized_quote_hash:
                continue
            self._pages_by_normalized_hash.setdefault(normalized_quote_hash, set()).add(
                normalized_page
            )

    def occurrence_count(self, normalized_quote_hash: str) -> int:
        return len(self._pages_by_normalized_hash.get(normalized_quote_hash, set()))


def build_seed_registry_entries() -> list[SeedPage]:
    entries: list[SeedPage] = []
    for source_type, titles in SEED_REGISTRY.items():
        prestige = SOURCE_PRESTIGE[source_type]
        page_type = "author" if source_type == "authors" else "topic"
        for title in titles:
            entries.append(
                SeedPage(
                    title=title,
                    source_type=source_type,
                    page_type=page_type,
                    prestige=prestige,
                )
            )
    entries.sort(key=lambda item: (-item.prestige, item.source_type, item.title))
    return entries


SEED_ENTRIES = build_seed_registry_entries()
SEED_ENTRY_BY_TITLE = {
    normalize_text(entry.title): entry
    for entry in SEED_ENTRIES
}
GLOBAL_AUTHOR_REPUTATION = {
    canonicalize_author(author_name)
    for author_name in SEED_REGISTRY["authors"]
    if canonicalize_author(author_name)
}
TOPIC_PRIORITY_TITLES = {
    normalize_text(title)
    for title in [*DEFAULT_SEEDS, *SEED_REGISTRY["topics"]]
}


UPSERT_QUOTE_SQL = """
insert into public.quotes (
  text,
  normalized_text,
  normalized_quote_hash,
  normalized_quote,
  quote_cluster_id,
  cluster_size,
  author,
  canonical_author,
  language,
  source,
  source_ref,
  source_url,
  license,
  categories,
  moods,
  length_tier,
  popularity_score,
  occurrence_count,
  quote_hash,
  hash
)
values (
  %(text)s,
  %(normalized_text)s,
  %(normalized_quote_hash)s,
  %(normalized_quote)s,
  %(quote_cluster_id)s,
  %(cluster_size)s,
  %(author)s,
  %(canonical_author)s,
  'en',
  'wikiquote',
  %(source_ref)s,
  %(source_url)s,
  'CC BY-SA 4.0',
  %(categories)s::text[],
  %(moods)s::text[],
  %(length_tier)s,
  %(popularity_score)s,
  %(occurrence_count)s,
  %(quote_hash)s,
  %(hash)s
)
on conflict (quote_hash)
do update set
  normalized_text = excluded.normalized_text,
  normalized_quote_hash = excluded.normalized_quote_hash,
  normalized_quote = excluded.normalized_quote,
  quote_cluster_id = excluded.quote_cluster_id,
  cluster_size = greatest(
    coalesce(public.quotes.cluster_size, 1),
    coalesce(excluded.cluster_size, 1)
  ),
  text = case
    when coalesce(nullif(public.quotes.text, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.text
    else public.quotes.text
  end,
  author = case
    when coalesce(nullif(public.quotes.author, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.author
    else public.quotes.author
  end,
  canonical_author = case
    when coalesce(nullif(public.quotes.canonical_author, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.canonical_author
    else public.quotes.canonical_author
  end,
  source = 'wikiquote',
  source_ref = case
    when coalesce(nullif(public.quotes.source_ref, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.source_ref
    else public.quotes.source_ref
  end,
  source_url = case
    when coalesce(nullif(public.quotes.source_url, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.source_url
    else public.quotes.source_url
  end,
  license = excluded.license,
  length_tier = case
    when coalesce(nullif(public.quotes.length_tier, ''), '') = ''
      or coalesce(excluded.popularity_score, 0) > coalesce(public.quotes.popularity_score, 0)
    then excluded.length_tier
    else public.quotes.length_tier
  end,
  occurrence_count = greatest(
    coalesce(public.quotes.occurrence_count, 1),
    excluded.occurrence_count
  ),
  popularity_score = greatest(
    coalesce(public.quotes.popularity_score, 0),
    coalesce(excluded.popularity_score, 0)
  ),
  quote_hash = excluded.quote_hash,
  hash = excluded.hash,
  categories = (
    select coalesce(array_agg(distinct item order by item), '{}'::text[])
    from unnest(
      coalesce(public.quotes.categories, '{}'::text[]) ||
      coalesce(excluded.categories, '{}'::text[])
    ) as item
    where item is not null and btrim(item) <> ''
  ),
  moods = (
    select coalesce(array_agg(distinct item order by item), '{}'::text[])
    from unnest(
      coalesce(public.quotes.moods, '{}'::text[]) ||
      coalesce(excluded.moods, '{}'::text[])
    ) as item
    where item is not null and btrim(item) <> ''
  )
returning id::text as id, (xmax = 0) as inserted
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Incremental Wikiquote -> Supabase ingestion"
    )
    parser.add_argument("--commit", action="store_true", help="Write to database")
    parser.add_argument(
        "--reset-dataset",
        action="store_true",
        help="Delete rows from quotes, authors, and pages_queue while keeping schema",
    )
    parser.add_argument(
        "--cleanup-strict",
        action="store_true",
        help="Delete already-stored rows that fail the strict parser rules",
    )
    parser.add_argument(
        "--dedupe-quotes",
        action="store_true",
        help="Merge stored quote variants that share the same normalized quote hash",
    )
    parser.add_argument(
        "--cluster-quotes",
        action="store_true",
        help="Cluster near-duplicate quotes and keep only the strongest version",
    )
    parser.add_argument(
        "--bootstrap",
        action="store_true",
        help="Process only curated seed registry pages with stricter scoring",
    )
    parser.add_argument(
        "--seed",
        action="store_true",
        help="Fetch seed categories into pages_queue before processing",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=40,
        help="Maximum number of pages to process in this run",
    )
    parser.add_argument(
        "--discover",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Discover linked pages from parsed pages and add them to pages_queue",
    )
    parser.add_argument(
        "--stats",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Print ingestion summary after completion",
    )
    parser.add_argument(
        "--seed-categories",
        default=",".join(DEFAULT_SEEDS),
        help="Comma-separated seed categories",
    )
    parser.add_argument(
        "--max-pages-per-run",
        type=int,
        default=0,
        help="Override page processing limit",
    )
    parser.add_argument(
        "--max-seed-members",
        type=int,
        default=0,
        help="Override number of pages fetched per seed category",
    )
    parser.add_argument(
        "--max-quotes-per-page",
        type=int,
        default=45,
        help="Maximum quotes extracted from one page",
    )
    parser.add_argument(
        "--max-discovered-links",
        type=int,
        default=80,
        help="Maximum discovered links enqueued per page",
    )
    parser.add_argument(
        "--recheck-days",
        type=int,
        default=7,
        help="Recheck already processed pages older than this threshold",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=3,
        help="Max retries before page is marked skipped",
    )
    parser.add_argument(
        "--min-score",
        type=int,
        default=MIN_GLOBAL_POPULARITY_SCORE,
        help="Minimum global popularity score required for insertion",
    )
    parser.add_argument(
        "--min-quotes-goal",
        type=int,
        default=0,
        help="Keep crawling until at least this many new quotes are inserted or no more high-signal pages can be primed",
    )
    parser.add_argument(
        "--user-agent",
        default="QuoteFlowIngest/2.1 (Wikiquote MediaWiki API; rate-limited)",
        help="User-Agent for MediaWiki API requests",
    )
    return parser.parse_args()


def quote_frequency_columns_available(cur: Any) -> bool:
    cur.execute(
        """
        select count(*) as count
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'quotes'
          and column_name in (
            'normalized_text',
            'normalized_quote_hash',
            'occurrence_count'
          )
        """
    )
    row = cur.fetchone() or {}
    return int(row.get("count") or 0) == 3


def ensure_quote_frequency_schema(cur: Any) -> None:
    cur.execute(
        """
        alter table public.quotes
          add column if not exists normalized_text text,
          add column if not exists normalized_quote_hash text,
          add column if not exists normalized_quote text,
          add column if not exists occurrence_count integer not null default 1
        """
    )
    cur.execute(
        """
        update public.quotes
        set normalized_text = btrim(
          regexp_replace(
            regexp_replace(lower(coalesce(text, '')), '[[:punct:]]+', ' ', 'g'),
            '\\s+',
            ' ',
            'g'
          )
        )
        where coalesce(normalized_text, '') = ''
        """
    )
    cur.execute(
        """
        update public.quotes
        set normalized_quote = normalized_text
        where coalesce(normalized_quote, '') = ''
          and coalesce(normalized_text, '') <> ''
        """
    )
    cur.execute(
        """
        update public.quotes
        set normalized_quote_hash = encode(
          digest(coalesce(normalized_text, ''), 'sha1'),
          'hex'
        )
        where coalesce(normalized_quote_hash, '') = ''
          and coalesce(normalized_text, '') <> ''
        """
    )
    cur.execute(
        """
        update public.quotes
        set quote_hash = normalized_quote_hash
        where coalesce(normalized_quote_hash, '') <> ''
          and coalesce(quote_hash, '') = ''
        """
    )
    cur.execute(
        """
        update public.quotes
        set hash = normalized_quote_hash
        where coalesce(normalized_quote_hash, '') <> ''
          and coalesce(hash, '') = ''
        """
    )
    cur.execute(
        """
        update public.quotes
        set occurrence_count = greatest(coalesce(occurrence_count, 0), 1)
        where occurrence_count is null or occurrence_count < 1
        """
    )
    cur.execute(
        """
        create index if not exists idx_quotes_normalized_text
        on public.quotes(normalized_text)
        """
    )
    cur.execute(
        """
        create index if not exists idx_quotes_normalized_quote_hash_lookup
        on public.quotes(normalized_quote_hash)
        """
    )
    cur.execute(
        """
        create index if not exists idx_quotes_normalized_quote
        on public.quotes(normalized_quote)
        """
    )


def ensure_quote_cluster_schema(cur: Any) -> None:
    cur.execute(
        """
        alter table public.quotes
          add column if not exists quote_cluster_id text,
          add column if not exists cluster_size integer not null default 1
        """
    )
    cur.execute(
        """
        update public.quotes
        set cluster_size = greatest(coalesce(cluster_size, 0), 1)
        where cluster_size is null or cluster_size < 1
        """
    )
    cur.execute(
        """
        update public.quotes
        set quote_cluster_id = coalesce(
          nullif(quote_cluster_id, ''),
          nullif(normalized_quote_hash, ''),
          nullif(quote_hash, ''),
          nullif(hash, ''),
          id::text
        )
        where coalesce(quote_cluster_id, '') = ''
        """
    )
    cur.execute(
        """
        create index if not exists idx_quotes_quote_cluster_id
        on public.quotes(quote_cluster_id)
        """
    )


def ensure_pages_queue_priority_schema(cur: Any) -> None:
    cur.execute(
        """
        alter table public.pages_queue
          add column if not exists page_priority integer not null default 0,
          add column if not exists quote_density integer not null default 0
        """
    )
    cur.execute(
        """
        update public.pages_queue
        set page_priority = greatest(coalesce(page_priority, 0), 0),
            quote_density = greatest(coalesce(quote_density, 0), 0)
        where page_priority is null
           or quote_density is null
           or page_priority < 0
           or quote_density < 0
        """
    )
    cur.execute(
        """
        create index if not exists idx_pages_queue_priority
        on public.pages_queue(page_priority desc, processed, skipped, retry_count, last_checked)
        """
    )
    cur.execute(
        """
        select id, page_title, page_type, coalesce(quote_density, 0) as quote_density
        from public.pages_queue
        where coalesce(page_priority, 0) = 0
        """
    )
    rows = list(cur.fetchall() or [])
    for row in rows:
        page_id = int(row.get("id"))
        page_title = str(row.get("page_title") or "")
        page_type = str(row.get("page_type") or "")
        quote_density = max(0, int(row.get("quote_density") or 0))
        page_priority = compute_page_priority(
            page_title=page_title,
            page_type=page_type,
            source_prestige=resolve_source_prestige(page_title=page_title, page_type=page_type),
            quote_density=quote_density,
            linked_from_high_quality_page=False,
        )
        cur.execute(
            "update public.pages_queue set page_priority = %s where id = %s",
            (page_priority, page_id),
        )


def ensure_ingestion_notification_schema(cur: Any) -> None:
    cur.execute(
        """
        create table if not exists public.ingestion_runs (
          id bigserial primary key,
          run_type text not null,
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
        )
        """
    )
    cur.execute(
        """
        create index if not exists idx_ingestion_runs_run_type_completed_at
        on public.ingestion_runs(run_type, completed_at desc)
        """
    )
    cur.execute(
        """
        create table if not exists public.app_notifications (
          id bigserial primary key,
          notification_type text not null,
          title text not null,
          body text not null,
          action_route text not null default '/updates',
          metadata jsonb not null default '{}'::jsonb,
          created_at timestamptz not null default now()
        )
        """
    )
    cur.execute(
        """
        create index if not exists idx_app_notifications_created_at
        on public.app_notifications(created_at desc)
        """
    )
    cur.execute(
        """
        create index if not exists idx_app_notifications_type_created_at
        on public.app_notifications(notification_type, created_at desc)
        """
    )
    cur.execute(
        """
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
        """
    )
    cur.execute(
        f"""
        create or replace function public.enforce_app_notifications_retention()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $$
        begin
          perform public.prune_app_notifications({APP_NOTIFICATION_RETENTION_LIMIT});
          return null;
        end;
        $$;
        """,
    )
    cur.execute(
        "drop trigger if exists trg_app_notifications_keep_latest on public.app_notifications"
    )
    cur.execute(
        """
        create trigger trg_app_notifications_keep_latest
        after insert on public.app_notifications
        for each statement
        execute function public.enforce_app_notifications_retention()
        """
    )
    cur.execute(
        "select public.prune_app_notifications(%s)",
        (APP_NOTIFICATION_RETENTION_LIMIT,),
    )


class WikiquoteApi:
    def __init__(
        self,
        user_agent: str,
        min_interval_seconds: float = REQUEST_INTERVAL_SECONDS,
    ) -> None:
        self._session = requests.Session()
        self._session.headers.update({"User-Agent": user_agent})
        self._min_interval_seconds = min_interval_seconds
        self._last_request_time = 0.0

    def get_json(self, params: dict[str, Any]) -> dict[str, Any]:
        self._throttle()
        payload = {"format": "json", **params}
        response = self._session.get(WIKIQUOTE_API_URL, params=payload, timeout=18)
        response.raise_for_status()
        decoded = response.json()
        if not isinstance(decoded, dict):
            raise RuntimeError("Unexpected MediaWiki response type")
        return decoded

    def _throttle(self) -> None:
        now = time.monotonic()
        elapsed = now - self._last_request_time
        wait_for = self._min_interval_seconds - elapsed
        if wait_for > 0:
            time.sleep(wait_for)
        self._last_request_time = time.monotonic()

    def fetch_category_members(self, category: str, limit: int) -> list[str]:
        output: list[str] = []
        continuation: dict[str, Any] = {}

        while len(output) < limit:
            query = {
                "action": "query",
                "list": "categorymembers",
                "cmtitle": f"Category:{category}",
                "cmnamespace": 0,
                "cmlimit": min(500, limit - len(output)),
            }
            query.update(continuation)
            payload = self.get_json(query)

            rows = (payload.get("query") or {}).get("categorymembers", [])
            if not isinstance(rows, list):
                break

            for row in rows:
                if not isinstance(row, dict):
                    continue
                title = str(row.get("title") or "").strip()
                if title and title not in output:
                    output.append(title)
                    if len(output) >= limit:
                        break

            continuation = payload.get("continue") or {}
            if not continuation:
                break

        return output

    def fetch_page(self, title: str) -> tuple[str, list[str]]:
        payload = self.get_json(
            {
                "action": "query",
                "prop": "revisions|categories",
                "rvslots": "main",
                "rvprop": "content",
                "cllimit": "max",
                "titles": title,
            }
        )

        pages = ((payload.get("query") or {}).get("pages") or {})
        if not isinstance(pages, dict) or not pages:
            return ("", [])

        page = next(iter(pages.values()))
        if not isinstance(page, dict):
            return ("", [])

        revisions = page.get("revisions") or []
        if not isinstance(revisions, list) or not revisions:
            return ("", [])

        revision0 = revisions[0] if isinstance(revisions[0], dict) else {}
        slots = revision0.get("slots") or {}
        slot_main = slots.get("main") if isinstance(slots, dict) else None
        text = ""
        if isinstance(slot_main, dict):
            text = str(slot_main.get("*") or "").strip()
        elif "*" in revision0:
            text = str(revision0.get("*") or "").strip()

        api_categories: list[str] = []
        for row in page.get("categories") or []:
            if not isinstance(row, dict):
                continue
            title_value = str(row.get("title") or "").strip()
            if not title_value.lower().startswith("category:"):
                continue
            api_categories.append(normalize_text(title_value.split(":", 1)[1]))

        return (text, api_categories)

    def fetch_page_links(self, title: str, limit: int) -> list[str]:
        output: list[str] = []
        continuation: dict[str, Any] = {}

        while len(output) < limit:
            query = {
                "action": "query",
                "prop": "links",
                "titles": title,
                "plnamespace": 0,
                "pllimit": min(500, limit - len(output)),
            }
            query.update(continuation)
            payload = self.get_json(query)

            pages = ((payload.get("query") or {}).get("pages") or {})
            if not isinstance(pages, dict) or not pages:
                break

            page = next(iter(pages.values()))
            if not isinstance(page, dict):
                break

            rows = page.get("links") or []
            if not isinstance(rows, list):
                break

            for row in rows:
                if not isinstance(row, dict):
                    continue
                title_value = str(row.get("title") or "").strip()
                if title_value and title_value not in output:
                    output.append(title_value)
                    if len(output) >= limit:
                        break

            continuation = payload.get("continue") or {}
            if not continuation:
                break

        return output


def main() -> None:
    load_dotenv()
    args = parse_args()
    max_pages_per_run, max_seed_members = resolve_limits(args)
    run_started_at = datetime.now(timezone.utc)
    trigger_source = os.getenv("QUOTEFLOW_INGEST_TRIGGER", "manual").strip() or "manual"

    seeds = [
        value.strip()
        for value in args.seed_categories.split(",")
        if value.strip()
    ] or DEFAULT_SEEDS

    api = WikiquoteApi(
        user_agent=args.user_agent,
        min_interval_seconds=REQUEST_INTERVAL_SECONDS,
    )
    stats = IngestStats()
    min_quotes_goal = resolve_min_quotes_goal(args)
    min_score = max(args.min_score, MIN_GLOBAL_POPULARITY_SCORE)
    if args.bootstrap:
        min_score = max(min_score, MIN_QUOTE_SCORE_BOOTSTRAP)
    top_quotes_limit = TOP_QUOTES_PER_PAGE_BOOTSTRAP if args.bootstrap else TOP_QUOTES_PER_PAGE

    if args.reset_dataset:
        with get_connection() as conn:
            with conn.cursor() as cur:
                if args.commit:
                    ensure_quote_frequency_schema(cur)
                    ensure_quote_cluster_schema(cur)
                    ensure_pages_queue_priority_schema(cur)
                    ensure_ingestion_notification_schema(cur)
                run_reset_dataset(cur=cur, commit=args.commit)
                if args.commit:
                    conn.commit()
        return

    if args.cleanup_strict:
        with get_connection() as conn:
            with conn.cursor() as cur:
                frequency_columns_available = quote_frequency_columns_available(cur)
                if args.commit and not frequency_columns_available:
                    ensure_quote_frequency_schema(cur)
                    frequency_columns_available = True
                if args.commit:
                    ensure_quote_cluster_schema(cur)
                    ensure_pages_queue_priority_schema(cur)
                    ensure_ingestion_notification_schema(cur)
                run_strict_cleanup(
                    cur=cur,
                    min_score=min_score,
                    commit=args.commit,
                    frequency_columns_available=frequency_columns_available,
                )
                if args.commit:
                    conn.commit()
        return

    if args.dedupe_quotes:
        with get_connection() as conn:
            with conn.cursor() as cur:
                ensure_quote_frequency_schema(cur)
                ensure_quote_cluster_schema(cur)
                ensure_ingestion_notification_schema(cur)
                run_dedupe_quotes(cur=cur, commit=args.commit)
                if args.commit:
                    conn.commit()
        return

    if args.cluster_quotes:
        with get_connection() as conn:
            with conn.cursor() as cur:
                ensure_quote_frequency_schema(cur)
                ensure_quote_cluster_schema(cur)
                ensure_ingestion_notification_schema(cur)
                run_cluster_quotes(cur=cur, commit=True)
                conn.commit()
        return

    if not args.commit:
        if args.bootstrap:
            run_bootstrap_dry(
                api=api,
                seeds=seeds,
                max_pages_per_run=max_pages_per_run,
                max_quotes_per_page=args.max_quotes_per_page,
                min_score=min_score,
                top_quotes_per_page=top_quotes_limit,
                stats=stats,
            )
        else:
            run_dry(
                api=api,
                seeds=seeds,
                max_pages_per_run=max_pages_per_run,
                max_seed_members=max_seed_members,
                max_quotes_per_page=args.max_quotes_per_page,
                max_discovered_links=args.max_discovered_links,
                min_score=min_score,
                discover=args.discover,
                stats=stats,
                top_quotes_per_page=top_quotes_limit,
            )
        if args.stats:
            print_summary(stats=stats, commit=False)
        return

    with get_connection() as conn:
        with conn.cursor() as cur:
            ensure_quote_frequency_schema(cur)
            ensure_quote_cluster_schema(cur)
            ensure_pages_queue_priority_schema(cur)
            ensure_ingestion_notification_schema(cur)
            conn.commit()
            cluster_index = load_quote_cluster_index(cur)
            start_metrics = get_storage_metrics(cur)
            stats.database_size_bytes_before = start_metrics.database_bytes
            if args.bootstrap:
                stats.seed_pages_enqueued = ensure_bootstrap_queue(
                    cur=cur,
                    replace_existing=True,
                )
                conn.commit()
            elif args.seed:
                stats.seed_pages_enqueued = ensure_seed_queue(
                    cur=cur,
                    api=api,
                    seeds=seeds,
                    max_seed_members=max_seed_members,
                )
                conn.commit()

            quote_count = get_quotes_count(cur)
            stale_before = datetime.now(timezone.utc) - timedelta(days=args.recheck_days)
            discovery_enabled = discovery_enabled_for_run(
                args=args,
                quote_count=quote_count,
            )
            pending_pages_available = has_pending_pages(
                cur=cur,
                stale_before=stale_before,
                max_retries=args.max_retries,
            )
            if discovery_enabled and min_quotes_goal > 0:
                seeded = ensure_target_discovery_queue(
                    cur=cur,
                    api=api,
                    limit=max(DISCOVERY_PRIME_QUEUE_SIZE, max_pages_per_run),
                )
                if seeded > 0:
                    stats.seed_pages_enqueued += seeded
                    conn.commit()
                    pending_pages_available = True
            elif discovery_enabled and not pending_pages_available:
                seeded = ensure_target_discovery_queue(
                    cur=cur,
                    api=api,
                    limit=max(DISCOVERY_PRIME_QUEUE_SIZE, max_pages_per_run),
                )
                if seeded > 0:
                    stats.seed_pages_enqueued += seeded
                    conn.commit()

            for index in range(max_pages_per_run):
                if min_quotes_goal > 0 and stats.quotes_inserted >= min_quotes_goal:
                    break

                discovery_enabled = discovery_enabled_for_run(
                    args=args,
                    quote_count=quote_count,
                )
                page_row = pull_next_page(
                    cur=cur,
                    stale_before=stale_before,
                    max_retries=args.max_retries,
                )
                if page_row is None:
                    if discovery_enabled:
                        seeded = ensure_target_discovery_queue(
                            cur=cur,
                            api=api,
                            limit=max(DISCOVERY_PRIME_QUEUE_SIZE, max_pages_per_run),
                        )
                        if seeded > 0:
                            stats.seed_pages_enqueued += seeded
                            conn.commit()
                            page_row = pull_next_page(
                                cur=cur,
                                stale_before=stale_before,
                                max_retries=args.max_retries,
                            )
                if page_row is None:
                    break

                quotes_before = stats.quotes_inserted
                process_page(
                    cur=cur,
                    api=api,
                    page_row=page_row,
                    seeds=seeds,
                    max_quotes_per_page=args.max_quotes_per_page,
                    top_quotes_per_page=top_quotes_limit,
                    max_discovered_links=args.max_discovered_links,
                    max_retries=args.max_retries,
                    min_score=min_score,
                    discover=discovery_enabled,
                    storage_guard_enabled=discovery_enabled,
                    cluster_index=cluster_index,
                    source_prestige=resolve_source_prestige(
                        page_title=str(page_row["page_title"]),
                        page_type=str(page_row.get("page_type") or ""),
                    ),
                    stats=stats,
                )
                conn.commit()
                quote_count += stats.quotes_inserted - quotes_before

                if (
                    min_quotes_goal > 0
                    and stats.quotes_inserted < min_quotes_goal
                    and (index + 1) % 25 == 0
                ):
                    discovery_enabled = discovery_enabled_for_run(
                        args=args,
                        quote_count=quote_count,
                    )
                    if discovery_enabled:
                        seeded = ensure_target_discovery_queue(
                            cur=cur,
                            api=api,
                            limit=max(DISCOVERY_PRIME_QUEUE_SIZE, max_pages_per_run),
                        )
                        if seeded > 0:
                            stats.seed_pages_enqueued += seeded
                            conn.commit()

                if (index + 1) % 10 == 0:
                    print(
                        "[progress] pages_processed=%s, quotes_inserted=%s, "
                        "new_pages_discovered=%s, duplicates_skipped=%s, pages_skipped=%s"
                        % (
                            stats.pages_processed,
                            stats.quotes_inserted,
                            stats.new_pages_discovered,
                            stats.duplicates_skipped,
                            stats.pages_skipped,
                        )
                    )

            end_metrics = get_storage_metrics(cur)
            stats.quotes_total_after = end_metrics.quote_count
            stats.database_size_bytes_after = end_metrics.database_bytes
            stats.quotes_table_bytes_after = end_metrics.quotes_table_bytes
            record_ingestion_run(
                cur=cur,
                run_type=resolve_run_type(args),
                trigger_source=trigger_source,
                stats=stats,
                min_quotes_goal=min_quotes_goal,
                started_at=run_started_at,
                completed_at=datetime.now(timezone.utc),
            )
            if not args.bootstrap and args.discover:
                create_discovery_app_notification(
                    cur=cur,
                    stats=stats,
                    trigger_source=trigger_source,
                    min_quotes_goal=min_quotes_goal,
                )
            conn.commit()

    if args.stats:
        print_summary(stats=stats, commit=True)


def resolve_limits(args: argparse.Namespace) -> tuple[int, int]:
    if args.bootstrap:
        default_limit = max(1, args.limit)
        if default_limit == 40:
            default_limit = len(SEED_ENTRIES)
    else:
        default_limit = max(1, args.limit)
    max_pages_per_run = args.max_pages_per_run if args.max_pages_per_run > 0 else default_limit
    max_seed_members = args.max_seed_members if args.max_seed_members > 0 else default_limit
    return (max_pages_per_run, max_seed_members)


def resolve_min_quotes_goal(args: argparse.Namespace) -> int:
    return max(0, int(args.min_quotes_goal or 0))


def discovery_enabled_for_run(
    *,
    args: argparse.Namespace,
    quote_count: int,
) -> bool:
    if args.bootstrap or not args.discover:
        return False
    return quote_count >= DISCOVERY_ENABLE_QUOTE_THRESHOLD or resolve_min_quotes_goal(args) > 0


def run_dry(
    api: WikiquoteApi,
    seeds: list[str],
    max_pages_per_run: int,
    max_seed_members: int,
    max_quotes_per_page: int,
    max_discovered_links: int,
    min_score: int,
    discover: bool,
    stats: IngestStats,
    top_quotes_per_page: int,
) -> None:
    queued: list[dict[str, Any]] = []
    seen = set()
    frequency_tracker = QuoteFrequencyTracker()
    for seed in seeds:
        members = api.fetch_category_members(category=seed, limit=max_seed_members)
        for title in members:
            if not should_queue_title(title):
                continue
            if title in seen:
                continue
            seen.add(title)
            page_type = infer_page_type(title, [seed])
            source_prestige = resolve_source_prestige(
                page_title=title,
                page_type=page_type,
                seed_categories=[seed],
            )
            queued.append(
                {
                    "id": len(queued) + 1,
                    "page_title": title,
                    "page_type": page_type,
                    "source_prestige": source_prestige,
                    "page_priority": compute_page_priority(
                        page_title=title,
                        page_type=page_type,
                        source_prestige=source_prestige,
                        quote_density=0,
                        linked_from_high_quality_page=False,
                        seed_categories=[seed],
                    ),
                }
            )

    queued.sort(
        key=lambda item: (
            int(item.get("page_priority") or 0),
            1 if str(item.get("page_type") or "") == "author" else 0,
            -len(str(item.get("page_title") or "")),
        ),
        reverse=True,
    )
    stats.seed_pages_enqueued = len(queued)

    for page_row in queued[:max_pages_per_run]:
        text, api_categories = api.fetch_page(page_row["page_title"])
        if not text:
            stats.pages_failed += 1
            continue
        parse_text = prepare_wikitext_for_parsing(text)
        all_categories = sorted(
            set(api_categories + extract_page_categories(parse_text))
        )
        page_seed_context = seed_context_for_page(
            page_title=page_row["page_title"],
            page_categories=all_categories,
            seeds=seeds,
        )
        mapping = map_page_tags(
            page_title=page_row["page_title"],
            seed_categories=page_seed_context,
            page_categories=all_categories,
        )
        resolved_source_prestige = max(
            int(page_row.get("source_prestige") or 0),
            resolve_source_prestige(
                page_title=page_row["page_title"],
                page_type=mapping.page_type,
                seed_categories=page_seed_context,
                page_categories=all_categories,
            ),
        )
        quote_candidates = extract_quote_candidates(
            parse_text,
            max_candidates=max_quotes_per_page,
        )
        candidate_normalized_hashes = collect_candidate_normalized_hashes(quote_candidates)
        build_result = build_quote_records(
            page_title=page_row["page_title"],
            page_type=mapping.page_type,
            quote_candidates=quote_candidates,
            categories=mapping.categories,
            moods=mapping.moods,
            min_score=min_score,
            top_quotes_per_page=top_quotes_per_page,
            source_prestige=resolved_source_prestige,
            existing_quote_states={},
            frequency_tracker=frequency_tracker,
        )
        frequency_tracker.register_page_quotes(
            page_row["page_title"],
            candidate_normalized_hashes,
        )
        accepted_quotes = build_result.inserted_top_quotes
        page_priority = compute_page_priority(
            page_title=page_row["page_title"],
            page_type=mapping.page_type,
            source_prestige=resolved_source_prestige,
            quote_density=accepted_quotes,
            linked_from_high_quality_page=False,
            seed_categories=page_seed_context,
            page_categories=all_categories,
        )
        discovered_count = 0
        if (
            discover
            and should_expand_from_page(accepted_quotes)
            and stats.new_pages_discovered < MAX_NEW_PAGES_PER_RUN
        ):
            discovered_links = api.fetch_page_links(
                page_row["page_title"],
                limit=min(
                    max_discovered_links,
                    max(0, MAX_NEW_PAGES_PER_RUN - stats.new_pages_discovered),
                ),
            )
            discovered_count = len(
                build_discovered_rows(
                    discovered_links=discovered_links,
                    parent_source_prestige=resolved_source_prestige,
                    parent_quote_density=accepted_quotes,
                    parent_page_priority=page_priority,
                )
            )

        stats.pages_processed += 1
        stats.quotes_parsed += len(quote_candidates)
        stats.quotes_inserted += len(build_result.records)
        stats.inserted_top_quotes += build_result.inserted_top_quotes
        stats.quotes_rejected += build_result.rejected_total
        stats.rejected_bad_author += build_result.rejected_bad_author
        stats.rejected_commentary += build_result.rejected_commentary
        stats.rejected_metadata += build_result.rejected_metadata
        stats.rejected_title_like += build_result.rejected_title_like
        stats.rejected_low_confidence += build_result.rejected_low_confidence
        stats.rejected_low_score += build_result.rejected_low_score
        stats.new_pages_discovered += discovered_count


def run_bootstrap_dry(
    api: WikiquoteApi,
    seeds: list[str],
    max_pages_per_run: int,
    max_quotes_per_page: int,
    min_score: int,
    top_quotes_per_page: int,
    stats: IngestStats,
) -> None:
    frequency_tracker = QuoteFrequencyTracker()
    queued = [
        {
            "id": index + 1,
            "page_title": entry.title,
            "page_type": entry.page_type,
            "source_type": entry.source_type,
            "source_prestige": entry.prestige,
        }
        for index, entry in enumerate(SEED_ENTRIES[:max_pages_per_run])
    ]
    stats.seed_pages_enqueued = len(queued)

    for page_row in queued:
        text, api_categories = api.fetch_page(page_row["page_title"])
        if not text:
            stats.pages_failed += 1
            continue
        parse_text = prepare_wikitext_for_parsing(text)
        all_categories = sorted(set(api_categories + extract_page_categories(parse_text)))
        mapping = map_page_tags(
            page_title=page_row["page_title"],
            seed_categories=seed_context_for_page(
                page_title=page_row["page_title"],
                page_categories=all_categories,
                seeds=seeds,
            ),
            page_categories=all_categories,
        )
        quote_candidates = extract_quote_candidates(
            parse_text,
            max_candidates=max_quotes_per_page,
        )
        candidate_normalized_hashes = collect_candidate_normalized_hashes(quote_candidates)
        build_result = build_quote_records(
            page_title=page_row["page_title"],
            page_type=mapping.page_type,
            quote_candidates=quote_candidates,
            categories=mapping.categories,
            moods=mapping.moods,
            min_score=min_score,
            top_quotes_per_page=top_quotes_per_page,
            source_prestige=int(page_row["source_prestige"]),
            existing_quote_states={},
            frequency_tracker=frequency_tracker,
        )
        frequency_tracker.register_page_quotes(
            page_row["page_title"],
            candidate_normalized_hashes,
        )

        stats.pages_processed += 1
        stats.quotes_parsed += len(quote_candidates)
        stats.quotes_inserted += len(build_result.records)
        stats.inserted_top_quotes += build_result.inserted_top_quotes
        stats.quotes_rejected += build_result.rejected_total
        stats.rejected_bad_author += build_result.rejected_bad_author
        stats.rejected_commentary += build_result.rejected_commentary
        stats.rejected_metadata += build_result.rejected_metadata
        stats.rejected_title_like += build_result.rejected_title_like
        stats.rejected_low_confidence += build_result.rejected_low_confidence
        stats.rejected_low_score += build_result.rejected_low_score


def queue_is_empty(cur: Any) -> bool:
    cur.execute("select 1 as present from public.pages_queue limit 1")
    row = cur.fetchone() or {}
    return not bool(row.get("present"))


def get_quotes_count(cur: Any) -> int:
    cur.execute("select count(*) as count from public.quotes")
    row = cur.fetchone() or {}
    return int(row.get("count") or 0)


def get_storage_metrics(cur: Any) -> StorageMetrics:
    cur.execute(
        """
        select
          pg_database_size(current_database()) as database_bytes,
          pg_total_relation_size('public.quotes') as quotes_table_bytes,
          (select count(*) from public.quotes) as quote_count
        """
    )
    row = cur.fetchone() or {}
    database_bytes = max(0, int(row.get("database_bytes") or 0))
    quotes_table_bytes = max(0, int(row.get("quotes_table_bytes") or 0))
    quote_count = max(0, int(row.get("quote_count") or 0))
    avg_quote_bytes = (
        max(FALLBACK_AVG_QUOTE_STORAGE_BYTES, math.ceil(quotes_table_bytes / quote_count))
        if quote_count > 0 and quotes_table_bytes > 0
        else FALLBACK_AVG_QUOTE_STORAGE_BYTES
    )
    return StorageMetrics(
        database_bytes=database_bytes,
        quotes_table_bytes=quotes_table_bytes,
        quote_count=quote_count,
        avg_quote_bytes=avg_quote_bytes,
    )


def _select_prunable_quotes(cur: Any, limit: int) -> list[dict[str, Any]]:
    if limit <= 0:
        return []
    cur.execute(
        """
        select
          q.id::text as id,
          q.canonical_author
        from public.quotes q
        where not exists (
          select 1
          from public.daily_quotes dq
          where dq.quote_id = q.id
        )
        order by
          coalesce(q.popularity_score, 0) asc,
          coalesce(q.likes_count, 0) asc,
          coalesce(q.saves_count, 0) asc,
          coalesce(q.views_count, 0) asc,
          greatest(coalesce(q.occurrence_count, 1), 1) asc,
          coalesce(q.virality_score, 0) asc,
          q.created_at asc,
          q.id asc
        limit %s
        """,
        (limit,),
    )
    return [dict(row) for row in list(cur.fetchall() or [])]


def prune_quotes_for_projected_growth(cur: Any, planned_new_quotes: int) -> StoragePruneResult:
    safe_planned_quotes = max(0, planned_new_quotes)
    if safe_planned_quotes <= 0:
        return StoragePruneResult(
            deleted_count=0,
            deleted_quote_ids=[],
            deleted_canonical_authors=[],
        )

    metrics = get_storage_metrics(cur)
    projected_database_bytes = (
        metrics.database_bytes + (safe_planned_quotes * max(1, metrics.avg_quote_bytes))
    )
    if projected_database_bytes <= SAFE_DATABASE_STORAGE_BYTES:
        return StoragePruneResult(
            deleted_count=0,
            deleted_quote_ids=[],
            deleted_canonical_authors=[],
        )

    bytes_to_reclaim = (
        projected_database_bytes - SAFE_DATABASE_STORAGE_BYTES + STORAGE_RECLAIM_BUFFER_BYTES
    )
    prune_count = math.ceil(bytes_to_reclaim / max(1, metrics.avg_quote_bytes))
    prune_count = max(MIN_PRUNE_BATCH_SIZE, prune_count)
    prune_count = min(MAX_PRUNE_BATCH_SIZE, prune_count, metrics.quote_count)
    candidates = _select_prunable_quotes(cur=cur, limit=prune_count)
    if not candidates:
        return StoragePruneResult(
            deleted_count=0,
            deleted_quote_ids=[],
            deleted_canonical_authors=[],
        )

    quote_ids = [str(row.get("id") or "").strip() for row in candidates if str(row.get("id") or "").strip()]
    canonical_authors = sorted(
        {
            str(row.get("canonical_author") or "").strip().lower()
            for row in candidates
            if str(row.get("canonical_author") or "").strip()
        }
    )
    if not quote_ids:
        return StoragePruneResult(
            deleted_count=0,
            deleted_quote_ids=[],
            deleted_canonical_authors=[],
        )

    for batch in chunked(quote_ids, 200):
        cur.execute(
            "delete from public.quotes where id = any(%s::uuid[])",
            (list(batch),),
        )

    if canonical_authors:
        cur.execute(
            "select public.refresh_author_stats_for_names(%s::text[])",
            (canonical_authors,),
        )

    return StoragePruneResult(
        deleted_count=len(quote_ids),
        deleted_quote_ids=quote_ids,
        deleted_canonical_authors=canonical_authors,
    )


def get_pages_queue_size(cur: Any) -> int:
    cur.execute("select count(*) as count from public.pages_queue")
    row = cur.fetchone() or {}
    return int(row.get("count") or 0)


def resolve_run_type(args: argparse.Namespace) -> str:
    if args.bootstrap:
        return "bootstrap"
    if args.cleanup_strict:
        return "cleanup"
    if args.dedupe_quotes:
        return "dedupe"
    if args.cluster_quotes:
        return "cluster"
    if args.reset_dataset:
        return "reset"
    if args.discover:
        return "discover"
    return "seed"


def build_discovery_notification_copy(
    *,
    quotes_added: int,
    total_quotes: int,
    pruned_quotes: int,
    min_quotes_goal: int,
) -> tuple[str, str]:
    safe_total = max(0, total_quotes)
    safe_added = max(0, quotes_added)
    safe_pruned = max(0, pruned_quotes)
    safe_goal = max(0, min_quotes_goal)
    goal_met = safe_goal == 0 or safe_added >= safe_goal

    if safe_added > 0:
        title = "Fresh discoveries arrived"
        body = (
            f"{safe_added} standout quote{'s' if safe_added != 1 else ''} joined the "
            f"library today. QuoteFlow now holds {safe_total:,} quotes."
        )
        if safe_goal > 0:
            if goal_met:
                body += f" That cleared the daily target of {safe_goal}."
            else:
                body += f" The crawl stopped short of the daily target of {safe_goal}."
    else:
        title = "Discovery run complete"
        body = (
            f"No new quotes cleared today's quality bar. QuoteFlow still holds "
            f"{safe_total:,} quotes."
        )
        if safe_goal > 0:
            body += f" The daily target of {safe_goal} was not reached."

    if safe_pruned > 0:
        body += (
            f" {safe_pruned} low-signal quote{'s were' if safe_pruned != 1 else ' was'} "
            "trimmed to keep the library lean."
        )
    return (title, body)


def record_ingestion_run(
    cur: Any,
    *,
    run_type: str,
    trigger_source: str,
    stats: IngestStats,
    min_quotes_goal: int,
    started_at: datetime,
    completed_at: datetime,
) -> None:
    goal_met = min_quotes_goal <= 0 or stats.quotes_inserted >= min_quotes_goal
    metadata = {
        "seed_pages_enqueued": stats.seed_pages_enqueued,
        "pages_failed": stats.pages_failed,
        "pages_skipped": stats.pages_skipped,
        "quotes_parsed": stats.quotes_parsed,
        "quotes_rejected": stats.quotes_rejected,
        "inserted_top_quotes": stats.inserted_top_quotes,
        "rejected_bad_author": stats.rejected_bad_author,
        "rejected_commentary": stats.rejected_commentary,
        "rejected_metadata": stats.rejected_metadata,
        "rejected_title_like": stats.rejected_title_like,
        "rejected_low_confidence": stats.rejected_low_confidence,
        "rejected_low_score": stats.rejected_low_score,
        "database_size_bytes_before": stats.database_size_bytes_before,
        "database_size_bytes_after": stats.database_size_bytes_after,
        "quotes_table_bytes_after": stats.quotes_table_bytes_after,
        "min_quotes_goal": min_quotes_goal,
        "goal_met": goal_met,
    }
    cur.execute(
        """
        insert into public.ingestion_runs (
          run_type,
          trigger_source,
          pages_processed,
          quotes_inserted,
          quotes_total,
          pruned_quotes,
          duplicates_skipped,
          new_pages_discovered,
          database_size_bytes,
          quotes_table_bytes,
          started_at,
          completed_at,
          metadata
        )
        values (
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s,
          %s::jsonb
        )
        """,
        (
          run_type,
          trigger_source,
          stats.pages_processed,
          stats.quotes_inserted,
          stats.quotes_total_after,
          stats.pruned_quotes,
          stats.duplicates_skipped,
          stats.new_pages_discovered,
          stats.database_size_bytes_after,
          stats.quotes_table_bytes_after,
          started_at,
          completed_at,
          json.dumps(metadata),
        ),
    )


def create_discovery_app_notification(
    cur: Any,
    *,
    stats: IngestStats,
    trigger_source: str,
    min_quotes_goal: int,
) -> None:
    title, body = build_discovery_notification_copy(
        quotes_added=stats.quotes_inserted,
        total_quotes=stats.quotes_total_after,
        pruned_quotes=stats.pruned_quotes,
        min_quotes_goal=min_quotes_goal,
    )
    goal_met = min_quotes_goal <= 0 or stats.quotes_inserted >= min_quotes_goal
    metadata = {
        "quotes_added": stats.quotes_inserted,
        "total_quotes": stats.quotes_total_after,
        "pruned_quotes": stats.pruned_quotes,
        "pages_processed": stats.pages_processed,
        "new_pages_discovered": stats.new_pages_discovered,
        "duplicates_skipped": stats.duplicates_skipped,
        "trigger_source": trigger_source,
        "database_size_bytes": stats.database_size_bytes_after,
        "quotes_table_bytes": stats.quotes_table_bytes_after,
        "min_quotes_goal": min_quotes_goal,
        "goal_met": goal_met,
    }
    cur.execute(
        """
        insert into public.app_notifications (
          notification_type,
          title,
          body,
          action_route,
          metadata
        )
        values (%s, %s, %s, %s, %s::jsonb)
        """,
        (
            DISCOVERY_NOTIFICATION_TYPE,
            title,
            body,
            DISCOVERY_NOTIFICATION_ROUTE,
            json.dumps(metadata),
        ),
    )
    cur.execute(
        "select public.prune_app_notifications(%s)",
        (APP_NOTIFICATION_RETENTION_LIMIT,),
    )


def run_reset_dataset(cur: Any, commit: bool) -> None:
    cur.execute("select count(*) as count from public.quotes")
    quotes_before = int((cur.fetchone() or {}).get("count") or 0)
    cur.execute("select count(*) as count from public.authors")
    authors_before = int((cur.fetchone() or {}).get("count") or 0)
    cur.execute("select count(*) as count from public.pages_queue")
    queue_before = int((cur.fetchone() or {}).get("count") or 0)

    if commit:
        cur.execute("delete from public.quotes")
        cur.execute("delete from public.authors")
        cur.execute("delete from public.pages_queue")

    mode = "COMMIT" if commit else "DRY-RUN"
    print(f"\n[{mode}] Dataset reset summary")
    print(f"quotes_before={quotes_before}")
    print(f"authors_before={authors_before}")
    print(f"pages_queue_before={queue_before}")
    if commit:
        print("quotes_remaining=0")
        print("authors_remaining=0")
        print("pages_queue_remaining=0")


def ensure_bootstrap_queue(cur: Any, replace_existing: bool) -> int:
    if replace_existing:
        cur.execute("delete from public.pages_queue")

    inserted = 0
    for entry in SEED_ENTRIES:
        cur.execute(
            """
            insert into public.pages_queue (
              page_title,
              page_type,
              page_priority,
              quote_density,
              processed,
              skipped,
              retry_count,
              last_checked,
              last_error
            )
            values (%s, %s, %s, 0, false, false, 0, null, null)
            on conflict (page_title) do nothing
            returning id
            """,
            (
                entry.title,
                entry.page_type,
                compute_page_priority(
                    page_title=entry.title,
                    page_type=entry.page_type,
                    source_prestige=entry.prestige,
                    quote_density=0,
                    linked_from_high_quality_page=False,
                ),
            ),
        )
        if cur.fetchone() is not None:
            inserted += 1
    return inserted


def ensure_seed_queue(
    cur: Any,
    api: WikiquoteApi,
    seeds: list[str],
    max_seed_members: int,
) -> int:
    rows: list[tuple[str, str, int]] = []
    seen = set()
    for seed in seeds:
        members = api.fetch_category_members(category=seed, limit=max_seed_members)
        for title in members:
            if not should_queue_title(title):
                continue
            if title in seen:
                continue
            seen.add(title)
            page_type = infer_page_type(title, [seed])
            rows.append(
                (
                    title,
                    page_type,
                    compute_page_priority(
                        page_title=title,
                        page_type=page_type,
                        source_prestige=resolve_source_prestige(
                            page_title=title,
                            page_type=page_type,
                            seed_categories=[seed],
                        ),
                        quote_density=0,
                        linked_from_high_quality_page=False,
                        seed_categories=[seed],
                    ),
                )
            )

    if not rows:
        return 0

    cur.executemany(
        """
        insert into public.pages_queue (
          page_title,
          page_type,
          page_priority,
          quote_density,
          processed,
          skipped,
          retry_count,
          last_checked,
          last_error
        )
        values (%s, %s, %s, 0, false, false, 0, null, null)
        on conflict (page_title) do nothing
        """,
        rows,
    )
    return len(rows)


def has_pending_pages(
    cur: Any,
    stale_before: datetime,
    max_retries: int,
) -> bool:
    cur.execute(
        """
        select 1 as present
        from public.pages_queue
        where skipped = false
          and retry_count < %s
          and (
            processed = false
            or coalesce(last_checked, to_timestamp(0)) < %s
          )
        limit 1
        """,
        (max_retries, stale_before),
    )
    row = cur.fetchone() or {}
    return bool(row.get("present"))


def pull_next_page(
    cur: Any,
    stale_before: datetime,
    max_retries: int,
) -> dict[str, Any] | None:
    cur.execute(
        """
        select
          id,
          page_title,
          page_type,
          page_priority,
          quote_density,
          processed,
          skipped,
          retry_count,
          last_checked
        from public.pages_queue
        where skipped = false
          and retry_count < %s
          and (
            processed = false
            or coalesce(last_checked, to_timestamp(0)) < %s
          )
        order by
          page_priority desc,
          processed asc,
          retry_count asc,
          coalesce(last_checked, to_timestamp(0)) asc,
          id asc
        limit 1
        """,
        (max_retries, stale_before),
    )
    row = cur.fetchone()
    if row is None:
        return None
    return dict(row)


def remaining_discovery_capacity(
    cur: Any,
    stats: IngestStats,
    max_discovered_links: int,
) -> int:
    run_remaining = max(0, MAX_NEW_PAGES_PER_RUN - stats.new_pages_discovered)
    if run_remaining <= 0:
        return 0
    queue_remaining = max(0, MAX_PAGES_QUEUE_SIZE - get_pages_queue_size(cur))
    if queue_remaining <= 0:
        return 0
    return min(max_discovered_links, run_remaining, queue_remaining)


def _context_matches_keyword(context: str, keywords: tuple[str, ...]) -> bool:
    return any(
        re.search(rf"(?<!\w){re.escape(keyword)}(?!\w)", context) is not None
        for keyword in keywords
    )


def resolve_source_prestige(
    page_title: str,
    page_type: str,
    *,
    seed_categories: list[str] | None = None,
    page_categories: list[str] | None = None,
) -> int:
    seed_entry = SEED_ENTRY_BY_TITLE.get(normalize_text(page_title))
    if seed_entry is not None:
        return seed_entry.prestige
    if page_type == "author":
        return SOURCE_PRESTIGE["authors"]

    context_parts = [
        normalize_text(page_title),
        *(normalize_text(item) for item in seed_categories or []),
        *(normalize_text(item) for item in page_categories or []),
    ]
    normalized_context = " | ".join(part for part in context_parts if part)
    for source_type in ("speeches", "literature", "films", "tv_shows"):
        if _context_matches_keyword(
            normalized_context,
            SOURCE_PRESTIGE_HINTS[source_type],
        ):
            return SOURCE_PRESTIGE[source_type]
    if page_type == "topic":
        return SOURCE_PRESTIGE["topics"]
    return 0


def topic_page_bonus(
    page_title: str,
    *,
    seed_categories: list[str] | None = None,
    page_categories: list[str] | None = None,
) -> int:
    normalized_title = normalize_text(page_title)
    if not normalized_title:
        return 0

    if normalized_title in TOPIC_PRIORITY_TITLES:
        return TOPIC_PAGE_MATCH_BONUS

    category_matches = {
        normalize_text(category)
        for category in [*(seed_categories or []), *(page_categories or [])]
        if normalize_text(category)
    }
    if normalized_title in category_matches:
        return TOPIC_PAGE_MATCH_BONUS
    return 0


def quote_density_score(quote_density: int) -> int:
    return max(0, min(quote_density, 4))


def link_from_high_quality_page_bonus(linked_from_high_quality_page: bool) -> int:
    return HIGH_QUALITY_LINK_BONUS if linked_from_high_quality_page else 0


def compute_page_priority(
    *,
    page_title: str,
    page_type: str,
    source_prestige: int,
    quote_density: int,
    linked_from_high_quality_page: bool,
    seed_categories: list[str] | None = None,
    page_categories: list[str] | None = None,
) -> int:
    return (
        max(0, source_prestige)
        + topic_page_bonus(
            page_title,
            seed_categories=seed_categories,
            page_categories=page_categories,
        )
        + link_from_high_quality_page_bonus(linked_from_high_quality_page)
        + quote_density_score(quote_density)
    )


def should_expand_from_page(accepted_quotes: int) -> bool:
    return accepted_quotes >= 2


def build_discovered_rows(
    discovered_links: list[str],
    *,
    parent_source_prestige: int = 0,
    parent_quote_density: int = 0,
    parent_page_priority: int = 0,
) -> list[DiscoveredPage]:
    rows: list[DiscoveredPage] = []
    seen_discovered = set()
    linked_from_high_quality_page = (
        parent_quote_density >= 2 or parent_page_priority >= 8 or parent_source_prestige >= 4
    )
    for title in discovered_links:
        if not should_queue_title(title):
            continue
        if title in seen_discovered:
            continue
        seen_discovered.add(title)
        page_type = classify_discovered_page_type(title)
        rows.append(
            DiscoveredPage(
                page_title=title,
                page_type=page_type,
                page_priority=compute_page_priority(
                    page_title=title,
                    page_type=page_type,
                    source_prestige=resolve_source_prestige(title, page_type),
                    quote_density=0,
                    linked_from_high_quality_page=linked_from_high_quality_page,
                ),
            )
        )
    rows.sort(
        key=lambda item: (
            item.page_priority,
            1 if item.page_type == "author" else 0,
            -len(item.page_title),
        ),
        reverse=True,
    )
    return rows


def enqueue_discovered_pages(
    cur: Any,
    discovered_rows: list[DiscoveredPage],
    limit: int,
) -> int:
    if limit <= 0 or not discovered_rows:
        return 0

    inserted = 0
    for discovered_page in discovered_rows:
        if inserted >= limit:
            break
        page_title = discovered_page.page_title
        page_type = discovered_page.page_type
        cur.execute(
            """
            insert into public.pages_queue (
              page_title,
              page_type,
              page_priority,
              quote_density,
              processed,
              skipped,
              retry_count,
              last_checked,
              last_error
            )
            values (%s, %s, %s, 0, false, false, 0, now(), null)
            on conflict (page_title) do update set
              page_priority = greatest(public.pages_queue.page_priority, excluded.page_priority)
            returning (xmax = 0) as inserted
            """,
            (page_title, page_type, discovered_page.page_priority),
        )
        row = cur.fetchone()
        if row is not None and bool(row.get("inserted")):
            inserted += 1
    return inserted


def ensure_prestige_discovery_queue(
    cur: Any,
    api: WikiquoteApi,
    limit: int,
) -> int:
    queue_remaining = max(0, MAX_PAGES_QUEUE_SIZE - get_pages_queue_size(cur))
    if queue_remaining <= 0 or limit <= 0:
        return 0

    budget = min(limit, queue_remaining)
    inserted_total = 0
    for entry in SEED_ENTRIES:
        if inserted_total >= budget:
            break
        discovered_links = api.fetch_page_links(
            entry.title,
            limit=min(DISCOVERY_LINKS_PER_PRESTIGE_PAGE, budget - inserted_total),
        )
        discovered_rows = build_discovered_rows(
            discovered_links=discovered_links,
            parent_source_prestige=entry.prestige,
            parent_quote_density=2,
            parent_page_priority=compute_page_priority(
                page_title=entry.title,
                page_type=entry.page_type,
                source_prestige=entry.prestige,
                quote_density=2,
                linked_from_high_quality_page=False,
            ),
        )
        inserted_total += enqueue_discovered_pages(
            cur=cur,
            discovered_rows=discovered_rows,
            limit=budget - inserted_total,
        )
    return inserted_total


def ensure_high_yield_discovery_queue(
    cur: Any,
    api: WikiquoteApi,
    limit: int,
    *,
    max_source_pages: int = 24,
    min_quote_density: int = 2,
) -> int:
    queue_remaining = max(0, MAX_PAGES_QUEUE_SIZE - get_pages_queue_size(cur))
    if queue_remaining <= 0 or limit <= 0:
        return 0

    budget = min(limit, queue_remaining)
    cur.execute(
        """
        select
          page_title,
          page_type,
          page_priority,
          quote_density
        from public.pages_queue
        where processed = true
          and skipped = false
          and coalesce(quote_density, 0) >= %s
        order by
          quote_density desc,
          page_priority desc,
          last_checked desc,
          id asc
        limit %s
        """,
        (min_quote_density, max_source_pages),
    )
    source_rows = [dict(row) for row in list(cur.fetchall() or [])]
    if not source_rows:
        return 0

    inserted_total = 0
    for source_row in source_rows:
        if inserted_total >= budget:
            break
        parent_title = str(source_row.get("page_title") or "").strip()
        if not parent_title:
            continue
        parent_page_type = str(source_row.get("page_type") or "").strip()
        parent_priority = max(0, int(source_row.get("page_priority") or 0))
        parent_density = max(0, int(source_row.get("quote_density") or 0))
        parent_source_prestige = resolve_source_prestige(
            page_title=parent_title,
            page_type=parent_page_type,
        )
        discovered_links = api.fetch_page_links(
            parent_title,
            limit=min(DISCOVERY_LINKS_PER_PRESTIGE_PAGE, budget - inserted_total),
        )
        discovered_rows = build_discovered_rows(
            discovered_links=discovered_links,
            parent_source_prestige=parent_source_prestige,
            parent_quote_density=parent_density,
            parent_page_priority=parent_priority,
        )
        inserted_total += enqueue_discovered_pages(
            cur=cur,
            discovered_rows=discovered_rows,
            limit=budget - inserted_total,
        )
    return inserted_total


def ensure_target_discovery_queue(
    cur: Any,
    api: WikiquoteApi,
    *,
    limit: int,
) -> int:
    if limit <= 0:
        return 0
    inserted = ensure_high_yield_discovery_queue(cur=cur, api=api, limit=limit)
    if inserted > 0:
        return inserted
    return ensure_prestige_discovery_queue(cur=cur, api=api, limit=limit)


def process_page(
    cur: Any,
    api: WikiquoteApi,
    page_row: dict[str, Any],
    seeds: list[str],
    max_quotes_per_page: int,
    top_quotes_per_page: int,
    max_discovered_links: int,
    max_retries: int,
    min_score: int,
    discover: bool,
    storage_guard_enabled: bool,
    cluster_index: QuoteClusterIndex,
    source_prestige: int,
    stats: IngestStats,
) -> None:
    page_id = int(page_row["id"])
    page_title = str(page_row["page_title"])

    try:
        wikitext, api_categories = api.fetch_page(page_title)
        if not wikitext:
            raise RuntimeError("empty_wikitext")
    except Exception as error:  # pragma: no cover
        stats.pages_failed += 1
        mark_page_failure(cur=cur, page_id=page_id, max_retries=max_retries, error=error)
        if _is_page_marked_skipped(cur=cur, page_id=page_id):
            stats.pages_skipped += 1
        return

    parse_text = prepare_wikitext_for_parsing(wikitext)
    parsed_categories = extract_page_categories(parse_text)
    all_categories = sorted(set(api_categories + parsed_categories))
    page_seed_context = seed_context_for_page(
        page_title=page_title,
        page_categories=all_categories,
        seeds=seeds,
    )

    mapping = map_page_tags(
        page_title=page_title,
        seed_categories=page_seed_context,
        page_categories=all_categories,
    )
    resolved_source_prestige = max(
        source_prestige,
        resolve_source_prestige(
            page_title=page_title,
            page_type=mapping.page_type,
            seed_categories=page_seed_context,
            page_categories=all_categories,
        ),
    )

    quote_candidates = extract_quote_candidates(
        parse_text,
        max_candidates=max_quotes_per_page,
    )
    candidate_normalized_hashes = collect_candidate_normalized_hashes(quote_candidates)
    build_result = build_quote_records(
        page_title=page_title,
        page_type=mapping.page_type,
        quote_candidates=quote_candidates,
        categories=mapping.categories,
        moods=mapping.moods,
        min_score=min_score,
        top_quotes_per_page=top_quotes_per_page,
        source_prestige=resolved_source_prestige,
        existing_quote_states=load_existing_quote_states(
            cur=cur,
            normalized_quote_hashes=candidate_normalized_hashes,
        ),
        frequency_tracker=None,
    )

    if storage_guard_enabled and build_result.records:
        prune_result = prune_quotes_for_projected_growth(
            cur=cur,
            planned_new_quotes=len(build_result.records),
        )
        stats.pruned_quotes += prune_result.deleted_count

    inserted, duplicates = upsert_quotes(
        cur=cur,
        records=build_result.records,
        cluster_index=cluster_index,
    )
    refresh_author_stats(cur=cur, records=build_result.records)
    accepted_quotes = build_result.inserted_top_quotes
    page_priority = compute_page_priority(
        page_title=page_title,
        page_type=mapping.page_type,
        source_prestige=resolved_source_prestige,
        quote_density=accepted_quotes,
        linked_from_high_quality_page=False,
        seed_categories=page_seed_context,
        page_categories=all_categories,
    )
    stats.pages_processed += 1
    stats.quotes_parsed += len(quote_candidates)
    stats.quotes_inserted += inserted
    stats.inserted_top_quotes += accepted_quotes
    stats.duplicates_skipped += duplicates
    stats.quotes_rejected += build_result.rejected_total
    stats.rejected_bad_author += build_result.rejected_bad_author
    stats.rejected_commentary += build_result.rejected_commentary
    stats.rejected_metadata += build_result.rejected_metadata
    stats.rejected_title_like += build_result.rejected_title_like
    stats.rejected_low_confidence += build_result.rejected_low_confidence
    stats.rejected_low_score += build_result.rejected_low_score

    discovery_budget = (
        remaining_discovery_capacity(
            cur=cur,
            stats=stats,
            max_discovered_links=max_discovered_links,
        )
        if discover and should_expand_from_page(accepted_quotes)
        else 0
    )
    if discovery_budget > 0:
        discovered_links = api.fetch_page_links(page_title, limit=discovery_budget)
        discovered_rows = build_discovered_rows(
            discovered_links=discovered_links,
            parent_source_prestige=resolved_source_prestige,
            parent_quote_density=accepted_quotes,
            parent_page_priority=page_priority,
        )
        inserted_pages = enqueue_discovered_pages(
            cur=cur,
            discovered_rows=discovered_rows,
            limit=discovery_budget,
        )
        stats.new_pages_discovered += inserted_pages

    mark_page_success(
        cur=cur,
        page_id=page_id,
        page_type=mapping.page_type,
        page_priority=page_priority,
        quote_density=accepted_quotes,
    )


def prepare_wikitext_for_parsing(wikitext: str) -> str:
    return _trim_wikitext(
        wikitext,
        max_chars=MAX_PARSE_WIKITEXT_CHARS,
        max_lines=MAX_PARSE_WIKITEXT_LINES,
    )

def _trim_wikitext(wikitext: str, *, max_chars: int, max_lines: int) -> str:
    if not wikitext:
        return ""
    lines = wikitext.splitlines()
    if len(lines) > max_lines:
        lines = lines[:max_lines]
    trimmed = "\n".join(lines)
    if len(trimmed) > max_chars:
        trimmed = trimmed[:max_chars]
    return trimmed


def build_normalized_quote_identity(text: str) -> tuple[str, str]:
    normalized_text = normalize_quote_text(text)
    if not normalized_text:
        return ("", "")
    return (
        normalized_text,
        compute_quote_hash_from_normalized(normalized_text),
    )


def build_quote_token_signature(text: str) -> tuple[str, ...]:
    return quote_similarity_tokens(text)


def build_quote_cluster_id(
    token_signature: tuple[str, ...],
    normalized_quote_hash: str,
) -> str:
    if token_signature:
        return compute_quote_hash_from_normalized("cluster|" + " ".join(token_signature))
    return normalized_quote_hash


def collect_candidate_normalized_hashes(quote_candidates: list[QuoteCandidate]) -> set[str]:
    normalized_hashes: set[str] = set()
    for candidate in quote_candidates:
        cleaned_text = clean_quote_display_text(candidate.text)
        normalized_text, normalized_quote_hash = build_normalized_quote_identity(cleaned_text)
        if not normalized_text or not normalized_quote_hash:
            continue
        normalized_hashes.add(normalized_quote_hash)
    return normalized_hashes


def load_existing_quote_states(
    cur: Any,
    normalized_quote_hashes: set[str],
) -> dict[str, ExistingQuoteState]:
    if not normalized_quote_hashes:
        return {}

    cur.execute(
        """
        select normalized_text, normalized_quote_hash, occurrence_count, popularity_score
        from public.quotes
        where normalized_quote_hash = any(%s::text[])
        """,
        (sorted(normalized_quote_hashes),),
    )
    rows = list(cur.fetchall() or [])
    existing_quotes: dict[str, ExistingQuoteState] = {}
    for row in rows:
        normalized_quote_hash = str(row.get("normalized_quote_hash") or "").strip()
        if not normalized_quote_hash:
            continue
        existing_quotes[normalized_quote_hash] = ExistingQuoteState(
            normalized_text=str(row.get("normalized_text") or "").strip(),
            normalized_quote_hash=normalized_quote_hash,
            occurrence_count=max(1, int(row.get("occurrence_count") or 1)),
            popularity_score=max(0, int(row.get("popularity_score") or 0)),
        )
    return existing_quotes


def cultural_source_score(page_title: str, page_type: str, source_prestige: int) -> int:
    seed_entry = SEED_ENTRY_BY_TITLE.get(normalize_text(page_title))
    if seed_entry is not None:
        if seed_entry.source_type in HIGH_CULTURAL_SOURCE_TYPES:
            return 2
        if seed_entry.source_type in MEDIUM_CULTURAL_SOURCE_TYPES:
            return 1
        return 0
    if page_type == "author" and source_prestige >= 1:
        return 1
    return 0


def author_reputation_score(canonical_author: str, page_title: str, page_type: str) -> int:
    if canonical_author in GLOBAL_AUTHOR_REPUTATION:
        return 2
    page_author = canonicalize_author(normalize_author_display(page_title))
    if page_type == "author" and page_author and canonical_author == page_author:
        return 1
    return 0


def projected_occurrence_count(
    normalized_quote_hash: str,
    existing_quote_states: dict[str, ExistingQuoteState],
    frequency_tracker: QuoteFrequencyTracker | None,
) -> int:
    existing_state = existing_quote_states.get(normalized_quote_hash)
    if existing_state is not None:
        return max(1, existing_state.occurrence_count + 1)
    if frequency_tracker is not None:
        return max(1, frequency_tracker.occurrence_count(normalized_quote_hash) + 1)
    return 1


def cross_page_frequency_score(occurrence_count: int) -> int:
    return max(0, int(math.log(max(0, occurrence_count) + 1) * 3))


def compute_global_popularity_score(
    *,
    page_title: str,
    page_type: str,
    source_prestige: int,
    canonical_author: str,
    occurrence_count: int,
    evaluation: Any,
) -> GlobalPopularityBreakdown:
    iconic_phrase_score = int(evaluation.iconic_phrase_score)
    aphorism_score = int(evaluation.aphorism_structure_score)
    parser_quality_score = int(evaluation.parser_quality_score or evaluation.score)
    cultural_score = cultural_source_score(
        page_title=page_title,
        page_type=page_type,
        source_prestige=source_prestige,
    )
    reputation_score = author_reputation_score(
        canonical_author=canonical_author,
        page_title=page_title,
        page_type=page_type,
    )
    recurrence_score = cross_page_frequency_score(occurrence_count)
    total = (
        iconic_phrase_score
        + aphorism_score
        + cultural_score
        + reputation_score
        + recurrence_score
        + parser_quality_score
    )
    return GlobalPopularityBreakdown(
        total=total,
        occurrence_count=occurrence_count,
        iconic_phrase_score=iconic_phrase_score,
        aphorism_structure_score=aphorism_score,
        cultural_source_score=cultural_score,
        author_reputation_score=reputation_score,
        cross_page_frequency_score=recurrence_score,
        parser_quality_score=parser_quality_score,
    )


def build_quote_records(
    page_title: str,
    page_type: str,
    quote_candidates: list[QuoteCandidate],
    categories: list[str],
    moods: list[str],
    min_score: int,
    top_quotes_per_page: int,
    source_prestige: int,
    existing_quote_states: dict[str, ExistingQuoteState],
    frequency_tracker: QuoteFrequencyTracker | None,
) -> QuoteBuildResult:
    source_url = build_source_url(page_title)
    candidates: list[tuple[int, int, int, int, int, int, int, int, QuoteRecord]] = []
    seen_normalized_quote_hashes = set()
    result = QuoteBuildResult(records=[])
    page_author = normalize_author_display(page_title)
    page_canonical_author = canonicalize_author(page_author)

    for candidate in quote_candidates:
        text = clean_quote_display_text(candidate.text)
        attribution_style = candidate.attribution_style or "none"

        if page_type == "author":
            if candidate.extracted_author:
                extracted_author = normalize_author_display(candidate.extracted_author)
                extracted_canonical = canonicalize_author(extracted_author)
                if (
                    extracted_canonical
                    and page_canonical_author
                    and extracted_canonical != page_canonical_author
                ):
                    _record_rejection(result, "bad_author")
                    continue
            author_display = page_author
            attribution_style = "page_author"
        elif candidate.extracted_author is not None:
            author_display = normalize_author_display(candidate.extracted_author)
        else:
            _record_rejection(result, "low_confidence")
            continue

        if not author_display or author_display.lower() == "unknown":
            _record_rejection(result, "bad_author")
            continue

        if not validate_author_name(author_display, quote_text=text):
            _record_rejection(result, "bad_author")
            continue

        evaluation = evaluate_quote_candidate(
            text,
            author_display,
            attribution_style=attribution_style,
            from_template=candidate.from_template,
            page_type=page_type,
            page_title=page_title,
            threshold=None,
        )
        if not evaluation.accepted:
            _record_rejection(result, evaluation.reject_reason)
            continue

        canonical_author = canonicalize_author(author_display)
        if not canonical_author:
            _record_rejection(result, "bad_author")
            continue

        normalized_text, normalized_quote_hash = build_normalized_quote_identity(text)
        if not normalized_text or not normalized_quote_hash:
            _record_rejection(result, "metadata")
            continue
        token_signature = build_quote_token_signature(normalized_text)
        quote_hash = normalized_quote_hash
        if normalized_quote_hash in seen_normalized_quote_hashes:
            _record_rejection(result, "metadata")
            continue
        seen_normalized_quote_hashes.add(normalized_quote_hash)
        occurrence_count = projected_occurrence_count(
            normalized_quote_hash=normalized_quote_hash,
            existing_quote_states=existing_quote_states,
            frequency_tracker=frequency_tracker,
        )
        popularity = compute_global_popularity_score(
            page_title=page_title,
            page_type=page_type,
            source_prestige=source_prestige,
            canonical_author=canonical_author,
            occurrence_count=occurrence_count,
            evaluation=evaluation,
        )
        length_tier = classify_length_tier(text)
        accepted_by_frequency = 1 if occurrence_count >= 3 else 0
        accepted = 1 if (popularity.total >= min_score or accepted_by_frequency) else 0

        candidates.append(
            (
                accepted,
                accepted_by_frequency,
                popularity.total,
                occurrence_count,
                popularity.cross_page_frequency_score,
                popularity.iconic_phrase_score,
                popularity.aphorism_structure_score,
                popularity.parser_quality_score,
                QuoteRecord(
                    text=text,
                    normalized_text=normalized_text,
                    normalized_quote_hash=normalized_quote_hash,
                    quote_cluster_id=build_quote_cluster_id(
                        token_signature,
                        normalized_quote_hash,
                    ),
                    cluster_size=1,
                    token_signature=token_signature,
                    author=author_display,
                    canonical_author=canonical_author,
                    source_ref=page_title,
                    source_url=source_url,
                    categories=list(categories),
                    moods=list(moods),
                    length_tier=length_tier,
                    popularity_score=popularity.total,
                    occurrence_count=occurrence_count,
                    quote_hash=quote_hash,
                    hash=quote_hash,
                ),
            )
        )

    candidates.sort(
        key=lambda item: (
            item[0],
            item[1],
            item[2],
            item[3],
            item[4],
            item[5],
            item[6],
            item[7],
            -abs(len(item[8].text) - 96),
        ),
        reverse=True,
    )

    selected: list[QuoteRecord] = []
    for index, (accepted, _, _, _, _, _, _, _, record) in enumerate(candidates):
        if not accepted:
            remaining = len(candidates) - index
            result.rejected_total += remaining
            result.rejected_low_score += remaining
            break
        if len(selected) >= top_quotes_per_page:
            result.rejected_total += len(candidates) - index
            break
        selected.append(record)

    result.records = selected
    result.inserted_top_quotes = len(selected)
    return result


def _record_rejection(result: QuoteBuildResult, reason: str | None) -> None:
    result.rejected_total += 1
    if reason == "bad_author":
        result.rejected_bad_author += 1
        return
    if reason == "commentary":
        result.rejected_commentary += 1
        return
    if reason == "metadata":
        result.rejected_metadata += 1
        return
    if reason == "title_like":
        result.rejected_title_like += 1
        return
    if reason == "low_confidence":
        result.rejected_low_confidence += 1
        return
    if reason == "low_score":
        result.rejected_low_score += 1
        return
    result.rejected_metadata += 1


def upsert_quotes(
    cur: Any,
    records: list[QuoteRecord],
    cluster_index: QuoteClusterIndex | None = None,
) -> tuple[int, int]:
    if not records:
        return (0, 0)

    inserted = 0
    duplicates = 0
    for record in records:
        if cluster_index is not None:
            matched_cluster, _ = cluster_index.find_best_match(
                record.normalized_quote_hash,
                record.token_signature,
            )
            if matched_cluster is not None and matched_cluster.quote_id:
                merged_cluster = merge_record_into_cluster_state(
                    matched_cluster,
                    record,
                    cluster_index,
                )
                update_clustered_quote(cur=cur, cluster=merged_cluster)
                cluster_index.replace_cluster(merged_cluster)
                duplicates += 1
                continue

        record.quote_cluster_id = record.quote_cluster_id or build_quote_cluster_id(
            record.token_signature,
            record.normalized_quote_hash,
        )
        record.cluster_size = max(1, record.cluster_size)
        cur.execute(
            UPSERT_QUOTE_SQL,
            {
                "text": record.text,
                "normalized_text": record.normalized_text,
                "normalized_quote_hash": record.normalized_quote_hash,
                "normalized_quote": record.normalized_text,
                "quote_cluster_id": record.quote_cluster_id,
                "cluster_size": record.cluster_size,
                "author": record.author,
                "canonical_author": record.canonical_author,
                "source_ref": record.source_ref,
                "source_url": record.source_url,
                "categories": record.categories,
                "moods": record.moods,
                "length_tier": record.length_tier,
                "popularity_score": record.popularity_score,
                "occurrence_count": record.occurrence_count,
                "quote_hash": record.quote_hash,
                "hash": record.hash,
            },
        )
        row = cur.fetchone()
        is_insert = bool(row and row.get("inserted"))
        quote_id = str(row.get("id") or "").strip() if row else ""
        if cluster_index is not None and quote_id:
            cluster_index.replace_cluster(
                build_quote_cluster_state_from_record(
                    record,
                    quote_id=quote_id,
                )
            )
        if is_insert:
            inserted += 1
        else:
            duplicates += 1
    return (inserted, duplicates)


def refresh_author_stats(cur: Any, records: list[QuoteRecord]) -> None:
    canonical_names = sorted(
        {
            record.canonical_author.strip().lower()
            for record in records
            if record.canonical_author.strip()
        }
    )
    if not canonical_names:
        return

    cur.execute(
        "select public.refresh_author_stats_for_names(%s::text[])",
        (canonical_names,),
    )


def mark_page_success(
    cur: Any,
    page_id: int,
    page_type: str,
    page_priority: int,
    quote_density: int,
) -> None:
    cur.execute(
        """
        update public.pages_queue
        set processed = true,
            skipped = false,
            retry_count = 0,
            page_type = %s,
            page_priority = %s,
            quote_density = %s,
            last_checked = now(),
            last_error = null
        where id = %s
        """,
        (page_type, max(0, page_priority), max(0, quote_density), page_id),
    )


def mark_page_failure(cur: Any, page_id: int, max_retries: int, error: Exception) -> None:
    message = str(error).strip()
    if len(message) > 500:
        message = message[:500]
    cur.execute(
        """
        update public.pages_queue
        set retry_count = retry_count + 1,
            processed = case when retry_count + 1 >= %s then true else false end,
            skipped = case when retry_count + 1 >= %s then true else false end,
            last_checked = now(),
            last_error = %s
        where id = %s
        """,
        (max_retries, max_retries, message, page_id),
    )


def _is_page_marked_skipped(cur: Any, page_id: int) -> bool:
    cur.execute(
        "select skipped from public.pages_queue where id = %s limit 1",
        (page_id,),
    )
    row = cur.fetchone() or {}
    return bool(row.get("skipped"))


def seed_context_for_page(
    page_title: str,
    page_categories: list[str],
    seeds: list[str],
) -> list[str]:
    corpus = " | ".join([normalize_text(page_title), *page_categories])
    contexts = [seed for seed in seeds if normalize_text(seed) in corpus]
    return contexts


def classify_discovered_page_type(page_title: str) -> str:
    title = page_title.strip()
    normalized = normalize_text(title)
    if infer_page_type(title, []) == "author":
        return "author"
    if re.search(r"\((film|tv|television|series|episode|season)\)", normalized):
        return "topic"
    if ":" in title or any(ch.isdigit() for ch in title):
        return "topic"

    tokens = [part for part in re.split(r"\s+", title) if part]
    if 2 <= len(tokens) <= 4:
        looks_like_name = True
        for token in tokens:
            stripped = token.strip(".,'\"()")
            if not stripped:
                looks_like_name = False
                break
            if len(stripped) == 1 and stripped.isalpha():
                continue
            if not stripped[0].isupper():
                looks_like_name = False
                break
        if looks_like_name:
            return "author"

    return "topic"


def should_queue_title(title: str) -> bool:
    normalized = title.strip()
    lowered = normalized.lower()
    if not normalized:
        return False
    if len(normalized) < 2 or len(normalized) > 120:
        return False
    if lowered.startswith(("category:", "template:", "help:", "file:", "image:")):
        return False
    if lowered.startswith("list of "):
        return False
    if "disambiguation" in lowered:
        return False
    if re.fullmatch(r"[0-9 ]+", normalized):
        return False
    return True


def clean_quote_display_text(text: str) -> str:
    return sanitize_quote_text(text)


def normalize_author_display(value: str) -> str:
    author = value.replace("_", " ")
    author = re.sub(r"\s*\([^)]{1,40}\)\s*$", "", author)
    author = re.sub(r"\s+", " ", author).strip()
    author = author.strip(" -\"'")
    return author or "Unknown"


def infer_stored_quote_context(author: str, source_ref: str) -> tuple[str, str]:
    page_author = normalize_author_display(source_ref) if source_ref else ""
    page_author_canonical = canonicalize_author(page_author)
    author_canonical = canonicalize_author(author)
    if source_ref and page_author_canonical and author_canonical == page_author_canonical:
        return ("author", "page_author")
    return ("topic", "stored_explicit")


def compute_stored_quote_popularity(
    *,
    text: str,
    author: str,
    source_ref: str,
    occurrence_count: int,
) -> GlobalPopularityBreakdown | None:
    cleaned_text = clean_quote_display_text(text)
    normalized_author = normalize_author_display(author)
    canonical_author = canonicalize_author(normalized_author)
    if not cleaned_text or not canonical_author:
        return None

    page_type, attribution_style = infer_stored_quote_context(
        author=normalized_author,
        source_ref=source_ref,
    )
    evaluation = evaluate_quote_candidate(
        cleaned_text,
        normalized_author,
        attribution_style=attribution_style,
        from_template=False,
        page_type=page_type,
        page_title=source_ref or None,
        threshold=None,
    )
    if not evaluation.accepted:
        return None

    return compute_global_popularity_score(
        page_title=source_ref or normalized_author,
        page_type=page_type,
        source_prestige=resolve_source_prestige(source_ref or normalized_author, page_type),
        canonical_author=canonical_author,
        occurrence_count=max(1, occurrence_count),
        evaluation=evaluation,
    )


def merge_text_array_values(*arrays: list[str] | None) -> list[str]:
    values: set[str] = set()
    for array in arrays:
        for item in array or []:
            value = str(item or "").strip()
            if value:
                values.add(value)
    return sorted(values)


def cluster_candidate_rank(
    *,
    popularity_score: int,
    occurrence_count: int,
    cluster_size: int,
    text: str,
) -> tuple[int, int, int, int]:
    return (
        max(0, popularity_score),
        max(1, occurrence_count),
        max(1, cluster_size),
        -abs(len(text.strip()) - 96),
    )


def build_quote_cluster_state_from_record(
    record: QuoteRecord,
    *,
    quote_id: str | None,
) -> QuoteClusterState:
    cluster_id = record.quote_cluster_id or build_quote_cluster_id(
        record.token_signature,
        record.normalized_quote_hash,
    )
    return QuoteClusterState(
        cluster_id=cluster_id,
        quote_id=quote_id,
        text=record.text,
        normalized_text=record.normalized_text,
        normalized_quote_hash=record.normalized_quote_hash,
        author=record.author,
        canonical_author=record.canonical_author,
        source_ref=record.source_ref,
        source_url=record.source_url,
        categories=list(record.categories),
        moods=list(record.moods),
        length_tier=record.length_tier,
        popularity_score=max(0, record.popularity_score),
        occurrence_count=max(1, record.occurrence_count),
        cluster_size=max(1, record.cluster_size),
        token_signature=tuple(record.token_signature),
        member_hashes={record.normalized_quote_hash} if record.normalized_quote_hash else set(),
    )


def build_quote_cluster_state_from_row(row: dict[str, Any]) -> QuoteClusterState | None:
    text = clean_quote_display_text(str(row.get("text") or ""))
    normalized_text = str(row.get("normalized_text") or "").strip()
    normalized_quote_hash = str(row.get("normalized_quote_hash") or "").strip()
    recomputed_normalized_text, recomputed_normalized_quote_hash = build_normalized_quote_identity(text)
    if recomputed_normalized_text and recomputed_normalized_quote_hash:
        if (
            not normalized_text
            or not normalized_quote_hash
            or normalized_text != recomputed_normalized_text
            or normalized_quote_hash != recomputed_normalized_quote_hash
        ):
            normalized_text = recomputed_normalized_text
            normalized_quote_hash = recomputed_normalized_quote_hash
    if not normalized_quote_hash:
        return None

    token_signature = build_quote_token_signature(normalized_text)
    cluster_id = str(row.get("quote_cluster_id") or "").strip() or build_quote_cluster_id(
        token_signature,
        normalized_quote_hash,
    )
    author = normalize_author_display(str(row.get("author") or ""))
    canonical_author = canonicalize_author(author) or str(row.get("canonical_author") or "").strip()
    return QuoteClusterState(
        cluster_id=cluster_id,
        quote_id=str(row.get("id") or "").strip() or None,
        text=text,
        normalized_text=normalized_text,
        normalized_quote_hash=normalized_quote_hash,
        author=author,
        canonical_author=canonical_author,
        source_ref=str(row.get("source_ref") or "").strip(),
        source_url=str(row.get("source_url") or "").strip(),
        categories=list(row.get("categories") or []),
        moods=list(row.get("moods") or []),
        length_tier=str(row.get("length_tier") or "").strip(),
        popularity_score=max(0, int(row.get("popularity_score") or 0)),
        occurrence_count=max(1, int(row.get("occurrence_count") or 1)),
        cluster_size=max(1, int(row.get("cluster_size") or 1)),
        token_signature=token_signature,
        member_hashes={normalized_quote_hash},
    )


def merge_loaded_cluster_state(
    existing_cluster: QuoteClusterState,
    member_state: QuoteClusterState,
) -> QuoteClusterState:
    existing_rank = cluster_candidate_rank(
        popularity_score=existing_cluster.popularity_score,
        occurrence_count=existing_cluster.occurrence_count,
        cluster_size=existing_cluster.cluster_size,
        text=existing_cluster.text,
    )
    member_rank = cluster_candidate_rank(
        popularity_score=member_state.popularity_score,
        occurrence_count=member_state.occurrence_count,
        cluster_size=member_state.cluster_size,
        text=member_state.text,
    )
    winner = member_state if member_rank > existing_rank else existing_cluster
    member_hashes = set(existing_cluster.member_hashes) | set(member_state.member_hashes)
    return QuoteClusterState(
        cluster_id=existing_cluster.cluster_id,
        quote_id=winner.quote_id,
        text=winner.text,
        normalized_text=winner.normalized_text,
        normalized_quote_hash=winner.normalized_quote_hash,
        author=winner.author,
        canonical_author=winner.canonical_author,
        source_ref=winner.source_ref,
        source_url=winner.source_url,
        categories=merge_text_array_values(existing_cluster.categories, member_state.categories),
        moods=merge_text_array_values(existing_cluster.moods, member_state.moods),
        length_tier=winner.length_tier,
        popularity_score=max(existing_cluster.popularity_score, member_state.popularity_score),
        occurrence_count=max(
            1,
            existing_cluster.occurrence_count + member_state.occurrence_count,
        ),
        cluster_size=max(
            len(member_hashes),
            existing_cluster.cluster_size,
            member_state.cluster_size,
        ),
        token_signature=winner.token_signature,
        member_hashes=member_hashes,
    )


def record_can_replace_cluster_canonical(
    cluster: QuoteClusterState,
    record: QuoteRecord,
    cluster_index: QuoteClusterIndex,
) -> bool:
    owner_quote_id = cluster_index.owner_quote_id(record.normalized_quote_hash)
    return owner_quote_id in {None, cluster.quote_id}


def merge_record_into_cluster_state(
    cluster: QuoteClusterState,
    record: QuoteRecord,
    cluster_index: QuoteClusterIndex,
) -> QuoteClusterState:
    member_hashes = set(cluster.member_hashes)
    member_hashes.add(record.normalized_quote_hash)
    merged_cluster_size = max(
        len(member_hashes),
        cluster.cluster_size,
        1 if record.cluster_size < 1 else record.cluster_size,
    )
    merged_occurrence_count = max(
        1,
        cluster.occurrence_count + 1,
        record.occurrence_count,
    )

    existing_breakdown = compute_stored_quote_popularity(
        text=cluster.text,
        author=cluster.author,
        source_ref=cluster.source_ref,
        occurrence_count=merged_occurrence_count,
    )
    record_breakdown = compute_stored_quote_popularity(
        text=record.text,
        author=record.author,
        source_ref=record.source_ref,
        occurrence_count=merged_occurrence_count,
    )
    existing_score = (
        int(existing_breakdown.total)
        if existing_breakdown is not None
        else max(0, cluster.popularity_score)
    )
    record_score = (
        int(record_breakdown.total)
        if record_breakdown is not None
        else max(0, record.popularity_score)
    )

    promote_record = (
        record_score > existing_score
        and record_can_replace_cluster_canonical(cluster, record, cluster_index)
    )
    if promote_record:
        text = record.text
        normalized_text = record.normalized_text
        normalized_quote_hash = record.normalized_quote_hash
        author = record.author
        canonical_author = record.canonical_author
        source_ref = record.source_ref
        source_url = record.source_url
        length_tier = record.length_tier
        token_signature = tuple(record.token_signature)
    else:
        text = cluster.text
        normalized_text = cluster.normalized_text
        normalized_quote_hash = cluster.normalized_quote_hash
        author = cluster.author
        canonical_author = cluster.canonical_author
        source_ref = cluster.source_ref
        source_url = cluster.source_url
        length_tier = cluster.length_tier
        token_signature = cluster.token_signature

    return QuoteClusterState(
        cluster_id=cluster.cluster_id,
        quote_id=cluster.quote_id,
        text=text,
        normalized_text=normalized_text,
        normalized_quote_hash=normalized_quote_hash,
        author=author,
        canonical_author=canonical_author,
        source_ref=source_ref,
        source_url=source_url,
        categories=merge_text_array_values(cluster.categories, record.categories),
        moods=merge_text_array_values(cluster.moods, record.moods),
        length_tier=length_tier,
        popularity_score=max(
            existing_score,
            record_score,
            cluster.popularity_score,
            record.popularity_score,
        ),
        occurrence_count=merged_occurrence_count,
        cluster_size=merged_cluster_size,
        token_signature=token_signature,
        member_hashes=member_hashes,
    )


def update_clustered_quote(cur: Any, cluster: QuoteClusterState) -> None:
    if not cluster.quote_id:
        raise ValueError("cluster quote_id is required for persisted updates")
    cur.execute(
        """
        update public.quotes
        set text = %s,
            normalized_text = %s,
            normalized_quote_hash = %s,
            normalized_quote = %s,
            quote_cluster_id = %s,
            cluster_size = %s,
            author = %s,
            canonical_author = %s,
            source_ref = %s,
            source_url = %s,
            categories = %s::text[],
            moods = %s::text[],
            length_tier = %s,
            popularity_score = %s,
            occurrence_count = %s,
            quote_hash = %s,
            hash = %s
        where id = %s::uuid
        """,
        (
            cluster.text,
            cluster.normalized_text,
            cluster.normalized_quote_hash,
            cluster.normalized_text,
            cluster.cluster_id,
            max(1, cluster.cluster_size),
            cluster.author,
            cluster.canonical_author,
            cluster.source_ref,
            cluster.source_url,
            cluster.categories,
            cluster.moods,
            cluster.length_tier,
            max(0, cluster.popularity_score),
            max(1, cluster.occurrence_count),
            cluster.normalized_quote_hash,
            cluster.normalized_quote_hash,
            cluster.quote_id,
        ),
    )


def load_quote_cluster_index(cur: Any) -> QuoteClusterIndex:
    cur.execute(
        """
        select
          id::text as id,
          text,
          author,
          canonical_author,
          source_ref,
          source_url,
          categories,
          moods,
          length_tier,
          popularity_score,
          likes_count,
          occurrence_count,
          normalized_text,
          normalized_quote_hash,
          quote_cluster_id,
          cluster_size,
          created_at
        from public.quotes
        order by
          coalesce(popularity_score, 0) desc,
          coalesce(likes_count, 0) desc,
          greatest(coalesce(occurrence_count, 1), 1) desc,
          created_at asc,
          id asc
        """
    )
    rows = list(cur.fetchall() or [])
    cluster_index = QuoteClusterIndex()
    for row in rows:
        member_state = build_quote_cluster_state_from_row(dict(row))
        if member_state is None:
            continue
        explicit_cluster = cluster_index.get_cluster(member_state.cluster_id)
        if explicit_cluster is not None:
            cluster_index.replace_cluster(
                merge_loaded_cluster_state(explicit_cluster, member_state)
            )
            continue
        matched_cluster, _ = cluster_index.find_best_match(
            member_state.normalized_quote_hash,
            member_state.token_signature,
        )
        if matched_cluster is None:
            cluster_index.register_cluster(member_state)
            continue
        cluster_index.replace_cluster(
            merge_loaded_cluster_state(matched_cluster, member_state)
        )
    return cluster_index


def reassign_duplicate_quote_refs(cur: Any, keep_id: str, duplicate_ids: list[str]) -> None:
    if not duplicate_ids:
        return

    cur.execute(
        """
        insert into public.quote_tags (quote_id, tag_id, weight)
        select %s::uuid, qt.tag_id, max(qt.weight)
        from public.quote_tags qt
        where qt.quote_id = any(%s::uuid[])
        group by qt.tag_id
        on conflict (quote_id, tag_id) do update set
          weight = greatest(public.quote_tags.weight, excluded.weight)
        """,
        (keep_id, duplicate_ids),
    )
    cur.execute(
        "delete from public.quote_tags where quote_id = any(%s::uuid[])",
        (duplicate_ids,),
    )

    cur.execute(
        """
        insert into public.user_saved_quotes (user_id, quote_id, created_at)
        select usq.user_id, %s::uuid, usq.created_at
        from public.user_saved_quotes usq
        where usq.quote_id = any(%s::uuid[])
        on conflict (user_id, quote_id) do nothing
        """,
        (keep_id, duplicate_ids),
    )
    cur.execute(
        "delete from public.user_saved_quotes where quote_id = any(%s::uuid[])",
        (duplicate_ids,),
    )

    cur.execute(
        """
        insert into public.user_liked_quotes (user_id, quote_id, created_at)
        select ulq.user_id, %s::uuid, ulq.created_at
        from public.user_liked_quotes ulq
        where ulq.quote_id = any(%s::uuid[])
        on conflict (user_id, quote_id) do nothing
        """,
        (keep_id, duplicate_ids),
    )
    cur.execute(
        "delete from public.user_liked_quotes where quote_id = any(%s::uuid[])",
        (duplicate_ids,),
    )

    cur.execute(
        """
        update public.daily_quotes
        set quote_id = %s::uuid
        where quote_id = any(%s::uuid[])
        """,
        (keep_id, duplicate_ids),
    )
    cur.execute(
        """
        update public.quote_events
        set quote_id = %s::uuid
        where quote_id = any(%s::uuid[])
        """,
        (keep_id, duplicate_ids),
    )


def run_dedupe_quotes(cur: Any, commit: bool) -> None:
    cur.execute(
        """
        select
          id::text as id,
          text,
          author,
          canonical_author,
          source_ref,
          source_url,
          categories,
          moods,
          length_tier,
          popularity_score,
          likes_count,
          occurrence_count,
          normalized_text,
          normalized_quote_hash,
          normalized_quote,
          quote_hash,
          hash,
          created_at
        from public.quotes
        order by created_at asc, id asc
        """
    )
    rows = list(cur.fetchall() or [])
    rows_before = len(rows)

    groups: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        text = clean_quote_display_text(str(row.get("text") or ""))
        normalized_text = str(row.get("normalized_text") or "").strip()
        normalized_quote_hash = str(row.get("normalized_quote_hash") or "").strip()
        if not normalized_text or not normalized_quote_hash:
            normalized_text, normalized_quote_hash = build_normalized_quote_identity(text)
        if not normalized_quote_hash:
            continue
        row["_normalized_text"] = normalized_text
        row["_normalized_quote_hash"] = normalized_quote_hash
        row["_clean_text"] = text
        groups.setdefault(normalized_quote_hash, []).append(row)

    groups_scanned = len(groups)
    groups_merged = 0
    rows_deleted = 0
    rows_updated = 0

    for normalized_quote_hash, group_rows in groups.items():
        if not group_rows:
            continue

        total_occurrence = sum(max(1, int(row.get("occurrence_count") or 1)) for row in group_rows)
        ranked_rows: list[tuple[tuple[int, int, int, int, int], dict[str, Any]]] = []
        for row in group_rows:
            breakdown = compute_stored_quote_popularity(
                text=str(row.get("_clean_text") or ""),
                author=str(row.get("author") or ""),
                source_ref=str(row.get("source_ref") or "").strip(),
                occurrence_count=total_occurrence,
            )
            ranked_rows.append(
                (
                    (
                        int(breakdown.total) if breakdown is not None else -1,
                        int(row.get("popularity_score") or 0),
                        int(row.get("likes_count") or 0),
                        max(1, int(row.get("occurrence_count") or 1)),
                        -abs(len(str(row.get("_clean_text") or "")) - 96),
                    ),
                    row,
                )
            )
        ranked_rows.sort(key=lambda item: item[0], reverse=True)
        keeper = ranked_rows[0][1]
        keep_id = str(keeper["id"])
        duplicate_ids = [str(row["id"]) for row in group_rows if str(row["id"]) != keep_id]

        merged_normalized_text = str(keeper.get("_normalized_text") or "").strip()
        merged_text = str(keeper.get("_clean_text") or "").strip()
        merged_author = normalize_author_display(str(keeper.get("author") or ""))
        merged_canonical_author = canonicalize_author(merged_author) or str(
            keeper.get("canonical_author") or ""
        ).strip()
        merged_source_ref = str(keeper.get("source_ref") or "").strip()
        merged_source_url = str(keeper.get("source_url") or "").strip()
        merged_categories = merge_text_array_values(
            *[row.get("categories") for row in group_rows]
        )
        merged_moods = merge_text_array_values(*[row.get("moods") for row in group_rows])
        merged_length_tier = classify_length_tier(merged_text) if merged_text else str(
            keeper.get("length_tier") or ""
        ).strip()
        merged_breakdown = compute_stored_quote_popularity(
            text=merged_text,
            author=merged_author,
            source_ref=merged_source_ref,
            occurrence_count=total_occurrence,
        )
        merged_popularity_score = max(
            int(keeper.get("popularity_score") or 0),
            int(merged_breakdown.total) if merged_breakdown is not None else 0,
        )

        needs_update = (
            len(group_rows) > 1
            or str(keeper.get("normalized_text") or "").strip() != merged_normalized_text
            or str(keeper.get("normalized_quote_hash") or "").strip() != normalized_quote_hash
            or str(keeper.get("normalized_quote") or "").strip() != merged_normalized_text
            or str(keeper.get("quote_hash") or "").strip() != normalized_quote_hash
            or str(keeper.get("hash") or "").strip() != normalized_quote_hash
            or max(1, int(keeper.get("occurrence_count") or 1)) != total_occurrence
            or int(keeper.get("popularity_score") or 0) != merged_popularity_score
        )

        if not needs_update:
            continue

        rows_updated += 1
        if len(group_rows) > 1:
            groups_merged += 1
            rows_deleted += len(duplicate_ids)

        if not commit:
            continue

        cur.execute(
            """
            update public.quotes
            set text = %s,
                normalized_text = %s,
                normalized_quote_hash = %s,
                normalized_quote = %s,
                author = %s,
                canonical_author = %s,
                source_ref = %s,
                source_url = %s,
                categories = %s::text[],
                moods = %s::text[],
                length_tier = %s,
                popularity_score = %s,
                occurrence_count = %s,
                quote_hash = %s,
                hash = %s
            where id = %s::uuid
            """,
            (
                merged_text,
                merged_normalized_text,
                normalized_quote_hash,
                merged_normalized_text,
                merged_author,
                merged_canonical_author,
                merged_source_ref,
                merged_source_url,
                merged_categories,
                merged_moods,
                merged_length_tier,
                merged_popularity_score,
                total_occurrence,
                normalized_quote_hash,
                normalized_quote_hash,
                keep_id,
            ),
        )
        reassign_duplicate_quote_refs(cur=cur, keep_id=keep_id, duplicate_ids=duplicate_ids)
        if duplicate_ids:
            for batch in chunked(duplicate_ids, 200):
                cur.execute(
                    "delete from public.quotes where id = any(%s::uuid[])",
                    (list(batch),),
                )

    rows_remaining = rows_before - rows_deleted if commit else rows_before
    mode = "COMMIT" if commit else "DRY-RUN"
    print(f"\n[{mode}] Quote dedupe summary")
    print(f"rows_before={rows_before}")
    print(f"groups_scanned={groups_scanned}")
    print(f"groups_merged={groups_merged}")
    print(f"rows_updated={rows_updated}")
    print(f"rows_deleted={rows_deleted}")
    print(f"rows_remaining={rows_remaining}")


def run_cluster_quotes(cur: Any, commit: bool) -> None:
    cur.execute(
        """
        select
          id::text as id,
          text,
          author,
          canonical_author,
          source_ref,
          source_url,
          categories,
          moods,
          length_tier,
          popularity_score,
          likes_count,
          occurrence_count,
          normalized_text,
          normalized_quote_hash,
          quote_cluster_id,
          cluster_size,
          created_at
        from public.quotes
        order by
          coalesce(popularity_score, 0) desc,
          coalesce(likes_count, 0) desc,
          greatest(coalesce(occurrence_count, 1), 1) desc,
          created_at asc,
          id asc
        """
    )
    rows = [dict(row) for row in list(cur.fetchall() or [])]
    rows_before = len(rows)

    cluster_index = QuoteClusterIndex()
    cluster_members: dict[str, list[dict[str, Any]]] = {}

    for row in rows:
        member_state = build_quote_cluster_state_from_row(row)
        if member_state is None:
            continue

        explicit_cluster = cluster_index.get_cluster(member_state.cluster_id)
        if explicit_cluster is not None:
            merged_cluster = merge_loaded_cluster_state(explicit_cluster, member_state)
            cluster_index.replace_cluster(merged_cluster)
            cluster_members.setdefault(merged_cluster.cluster_id, []).append(row)
            continue

        matched_cluster, _ = cluster_index.find_best_match(
            member_state.normalized_quote_hash,
            member_state.token_signature,
        )
        if matched_cluster is None:
            cluster_index.register_cluster(member_state)
            cluster_members[member_state.cluster_id] = [row]
            continue

        merged_cluster = merge_loaded_cluster_state(matched_cluster, member_state)
        cluster_index.replace_cluster(merged_cluster)
        cluster_members.setdefault(merged_cluster.cluster_id, []).append(row)

    clusters_scanned = len(cluster_members)
    clusters_merged = 0
    rows_updated = 0
    rows_deleted = 0

    for cluster_id, member_rows in cluster_members.items():
        cluster = cluster_index.get_cluster(cluster_id)
        if cluster is None or not cluster.quote_id:
            continue

        cluster.cluster_size = max(
            cluster.cluster_size,
            len(cluster.member_hashes),
            len(member_rows),
        )
        cluster_breakdown = compute_stored_quote_popularity(
            text=cluster.text,
            author=cluster.author,
            source_ref=cluster.source_ref,
            occurrence_count=cluster.occurrence_count,
        )
        if cluster_breakdown is not None:
            cluster.popularity_score = max(cluster.popularity_score, int(cluster_breakdown.total))

        keeper_row = next(
            (row for row in member_rows if str(row.get("id") or "").strip() == cluster.quote_id),
            None,
        )
        if keeper_row is None:
            continue

        duplicate_ids = [
            str(row.get("id") or "").strip()
            for row in member_rows
            if str(row.get("id") or "").strip() != cluster.quote_id
        ]

        needs_update = (
            clean_quote_display_text(str(keeper_row.get("text") or "")) != cluster.text
            or str(keeper_row.get("normalized_text") or "").strip() != cluster.normalized_text
            or str(keeper_row.get("normalized_quote_hash") or "").strip()
            != cluster.normalized_quote_hash
            or str(keeper_row.get("quote_cluster_id") or "").strip() != cluster.cluster_id
            or max(1, int(keeper_row.get("cluster_size") or 1)) != cluster.cluster_size
            or max(1, int(keeper_row.get("occurrence_count") or 1)) != cluster.occurrence_count
            or max(0, int(keeper_row.get("popularity_score") or 0)) != cluster.popularity_score
            or duplicate_ids
        )
        if not needs_update:
            continue

        rows_updated += 1
        if duplicate_ids:
            clusters_merged += 1
            rows_deleted += len(duplicate_ids)

        if not commit:
            continue

        update_clustered_quote(cur=cur, cluster=cluster)
        reassign_duplicate_quote_refs(cur=cur, keep_id=cluster.quote_id, duplicate_ids=duplicate_ids)
        if duplicate_ids:
            for batch in chunked(duplicate_ids, 200):
                cur.execute(
                    "delete from public.quotes where id = any(%s::uuid[])",
                    (list(batch),),
                )

    rows_remaining = rows_before - rows_deleted if commit else rows_before
    mode = "COMMIT" if commit else "DRY-RUN"
    print(f"\n[{mode}] Quote clustering summary")
    print(f"rows_before={rows_before}")
    print(f"clusters_scanned={clusters_scanned}")
    print(f"clusters_merged={clusters_merged}")
    print(f"rows_updated={rows_updated}")
    print(f"rows_deleted={rows_deleted}")
    print(f"rows_remaining={rows_remaining}")


def run_strict_cleanup(
    cur: Any,
    min_score: int,
    commit: bool,
    frequency_columns_available: bool,
) -> None:
    select_columns = "id, text, author, source_ref"
    if frequency_columns_available:
        select_columns += ", occurrence_count"
    cur.execute(
        f"""
        select {select_columns}
        from public.quotes
        order by created_at desc, id desc
        """
    )
    rows = list(cur.fetchall() or [])
    rows_before = len(rows)

    delete_ids: list[str] = []
    for row in rows:
        if _stored_quote_should_be_deleted(row=row, min_score=min_score):
            delete_ids.append(str(row["id"]))

    if commit and delete_ids:
        for batch in chunked(delete_ids, 200):
            cur.execute(
                "delete from public.quotes where id = any(%s::uuid[])",
                (list(batch),),
            )

    rows_deleted = len(delete_ids)
    rows_remaining = rows_before - rows_deleted if commit else rows_before
    mode = "COMMIT" if commit else "DRY-RUN"
    print(f"\n[{mode}] Strict cleanup summary")
    print(f"rows_before={rows_before}")
    print(f"rows_deleted={rows_deleted}")
    print(f"rows_remaining={rows_remaining}")


def _stored_quote_should_be_deleted(row: dict[str, Any], min_score: int) -> bool:
    text = clean_quote_display_text(str(row.get("text") or ""))
    author = normalize_author_display(str(row.get("author") or ""))
    source_ref = str(row.get("source_ref") or "").strip()
    occurrence_count = max(1, int(row.get("occurrence_count") or 1))

    popularity = compute_stored_quote_popularity(
        text=text,
        author=author,
        source_ref=source_ref,
        occurrence_count=occurrence_count,
    )
    if popularity is None:
        return True
    return popularity.total < min_score and occurrence_count < 3


def build_source_url(page_title: str) -> str:
    slug = page_title.replace(" ", "_")
    return f"https://en.wikiquote.org/wiki/{urlquote(slug, safe='():')}"


def print_summary(stats: IngestStats, commit: bool) -> None:
    mode = "COMMIT" if commit else "DRY-RUN"
    print(f"\n[{mode}] Wikiquote ingestion summary")
    print(f"seed_pages_enqueued={stats.seed_pages_enqueued}")
    print(f"pages_processed={stats.pages_processed}")
    print(f"quotes_inserted={stats.quotes_inserted}")
    print(f"inserted_top_quotes={stats.inserted_top_quotes}")
    print(f"new_pages_discovered={stats.new_pages_discovered}")
    print(f"duplicates_skipped={stats.duplicates_skipped}")
    print(f"pages_failed={stats.pages_failed}")
    print(f"pages_skipped={stats.pages_skipped}")
    print(f"quotes_parsed={stats.quotes_parsed}")
    print(f"quotes_rejected={stats.quotes_rejected}")
    print(f"rejected_bad_author={stats.rejected_bad_author}")
    print(f"rejected_commentary={stats.rejected_commentary}")
    print(f"rejected_metadata={stats.rejected_metadata}")
    print(f"rejected_title_like={stats.rejected_title_like}")
    print(f"rejected_low_confidence={stats.rejected_low_confidence}")
    print(f"rejected_low_score={stats.rejected_low_score}")
    print(f"pruned_quotes={stats.pruned_quotes}")
    print(f"quotes_total_after={stats.quotes_total_after}")
    print(f"database_size_bytes_before={stats.database_size_bytes_before}")
    print(f"database_size_bytes_after={stats.database_size_bytes_after}")
    print(f"quotes_table_bytes_after={stats.quotes_table_bytes_after}")
    print(f"license={WIKIQUOTE_LICENSE}")


if __name__ == "__main__":
    main()
