from __future__ import annotations

import os
from collections.abc import Iterator, Sequence
from typing import Any

import psycopg
from psycopg.rows import dict_row


def get_database_url() -> str:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required for --commit mode")
    return database_url


def get_connection() -> psycopg.Connection[Any]:
    return psycopg.connect(get_database_url(), row_factory=dict_row)


def chunked(items: Sequence[Any], size: int) -> Iterator[Sequence[Any]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]
