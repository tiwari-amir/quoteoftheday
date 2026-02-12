from __future__ import annotations

import hashlib
import json
import re
from typing import Any

MOOD_ALLOWLIST = {
    "happy",
    "sad",
    "motivated",
    "calm",
    "confident",
    "lonely",
    "angry",
    "grateful",
    "anxious",
    "romantic",
    "hopeful",
    "stressed",
}


def normalize_quote_text(value: Any) -> str:
    text = "" if value is None else str(value)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def normalize_author(value: Any) -> str | None:
    if value is None:
        return None
    author = str(value).strip()
    return author or None


def parse_revised_tags(raw: Any) -> list[str]:
    values: list[str] = []

    if raw is None:
        return values

    if isinstance(raw, list):
        source = raw
    elif isinstance(raw, (tuple, set)):
        source = list(raw)
    elif isinstance(raw, str):
        text = raw.strip()
        if not text:
            return []
        if text.startswith("[") and text.endswith("]"):
            try:
                decoded = json.loads(text)
                source = decoded if isinstance(decoded, list) else [text]
            except json.JSONDecodeError:
                source = text.split(",")
        else:
            source = text.split(",")
    else:
        source = [raw]

    for item in source:
        token = str(item).strip().lower()
        if token:
            values.append(token)

    deduped: list[str] = []
    seen = set()
    for token in values:
        if token in seen:
            continue
        seen.add(token)
        deduped.append(token)

    return deduped


def slugify_tag(value: str) -> str:
    text = value.strip().lower()
    text = re.sub(r"[_\s]+", "-", text)
    text = re.sub(r"[^a-z0-9-]", "", text)
    text = re.sub(r"-{2,}", "-", text)
    return text.strip("-")


def display_name_from_slug(slug: str) -> str:
    return " ".join(part.capitalize() for part in slug.split("-") if part)


def classify_tag(slug: str) -> str:
    if slug in MOOD_ALLOWLIST:
        return "mood"
    return "category"


def quote_hash(normalized_text: str, normalized_author: str | None) -> str:
    author_token = normalized_author or ""
    payload = f"{normalized_text}|{author_token}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def get_case_insensitive(record: dict[str, Any], key: str) -> Any:
    direct = record.get(key)
    if direct is not None:
        return direct

    lower_key = key.lower()
    for k, value in record.items():
        if str(k).lower() == lower_key:
            return value
    return None
