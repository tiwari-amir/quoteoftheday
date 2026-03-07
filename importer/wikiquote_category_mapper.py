from __future__ import annotations

from dataclasses import dataclass

PRIMARY_EXPLORE_CATEGORIES = [
    "love",
    "life",
    "inspirational",
    "humour",
    "philosophy",
    "god",
    "truth",
    "wisdom",
    "success",
    "romance",
    "poetry",
    "death",
    "happiness",
    "hope",
    "faith",
    "motivation",
    "friendship",
    "relationships",
    "change",
    "self improvement",
    "tv shows",
    "films",
]

GROUPED_CATEGORIES = {
    "life_personal_growth": [
        "life",
        "success",
        "happiness",
        "change",
        "courage",
        "hope",
        "failure",
        "time",
        "ambition",
        "balance",
    ],
    "motivation_action": [
        "inspiration",
        "motivation",
        "work",
        "leadership",
        "attitude",
        "determination",
        "focus",
        "preparation",
        "excellence",
        "hard work",
    ],
    "relationships_emotions": [
        "love",
        "friendship",
        "family",
        "kindness",
        "forgiveness",
        "trust",
        "loneliness",
        "beauty",
        "gratitude",
        "empathy",
    ],
    "intellect_society": [
        "wisdom",
        "education",
        "science",
        "art",
        "politics",
        "religion",
        "war",
        "truth",
        "freedom",
        "justice",
    ],
    "entertainment_culture": [
        "funny",
        "movies",
        "films",
        "tv shows",
        "books",
        "literature",
        "sports",
        "music",
        "proverbs",
        "epitaphs",
        "slogans",
        "misquotations",
    ],
}

SEED_CATEGORY_ALIAS = {
    "love": "love",
    "life": "life",
    "philosophy": "philosophy",
    "humor": "humour",
    "humour": "humour",
    "films": "films",
    "film": "films",
    "movies": "films",
    "television": "tv shows",
    "tv": "tv shows",
    "religion": "religion",
    "poetry": "poetry",
}

TAG_KEYWORDS = {
    "love": ["love", "affection", "heart", "romantic"],
    "life": ["life", "living", "existence"],
    "inspirational": ["inspiration", "inspire", "uplift"],
    "humour": ["humor", "humour", "funny", "comedy", "joke"],
    "philosophy": ["philosophy", "philosopher", "metaphysics"],
    "god": ["god", "divine", "deity"],
    "truth": ["truth", "honesty", "real"],
    "wisdom": ["wisdom", "wise", "insight"],
    "success": ["success", "achievement", "win", "accomplish"],
    "romance": ["romance", "romantic"],
    "poetry": ["poetry", "poem", "poet"],
    "death": ["death", "dying", "mortality"],
    "happiness": ["happiness", "happy", "joy"],
    "hope": ["hope", "optimism", "optimist"],
    "faith": ["faith", "belief"],
    "motivation": ["motivation", "motivated", "drive"],
    "friendship": ["friendship", "friend"],
    "relationships": ["relationship", "relationships", "partner"],
    "change": ["change", "transformation"],
    "self improvement": ["self improvement", "self-help", "growth", "discipline"],
    "tv shows": ["television", "tv", "series", "sitcom"],
    "films": ["film", "movie", "cinema"],
    "movies": ["movie", "movies", "film", "cinema"],
    "series": ["series", "television", "tv show"],
    "courage": ["courage", "bravery", "brave"],
    "failure": ["failure", "fail", "mistake"],
    "time": ["time", "timing", "clock"],
    "ambition": ["ambition", "aspiration"],
    "balance": ["balance", "equilibrium"],
    "inspiration": ["inspiration", "inspire"],
    "work": ["work", "career", "job"],
    "leadership": ["leadership", "leader"],
    "attitude": ["attitude", "mindset"],
    "determination": ["determination", "persistent", "perseverance"],
    "focus": ["focus", "concentration"],
    "preparation": ["preparation", "prepare"],
    "excellence": ["excellence", "excellent"],
    "hard work": ["hard work", "effort", "diligence"],
    "family": ["family", "parent", "mother", "father"],
    "kindness": ["kindness", "kind", "compassion"],
    "forgiveness": ["forgiveness", "forgive"],
    "trust": ["trust", "loyalty"],
    "loneliness": ["lonely", "loneliness", "alone"],
    "beauty": ["beauty", "beautiful"],
    "gratitude": ["gratitude", "grateful", "thankful"],
    "empathy": ["empathy", "empathetic"],
    "education": ["education", "learning", "study"],
    "science": ["science", "scientific"],
    "art": ["art", "artist"],
    "politics": ["politics", "political", "government"],
    "religion": ["religion", "religious", "spiritual"],
    "war": ["war", "battle"],
    "freedom": ["freedom", "liberty"],
    "justice": ["justice", "law", "rights"],
    "funny": ["funny", "humor", "humour", "joke"],
    "books": ["book", "books"],
    "literature": ["literature", "novel", "writer"],
    "sports": ["sport", "sports", "athlete"],
    "music": ["music", "song", "musician"],
    "proverbs": ["proverb", "proverbs"],
    "epitaphs": ["epitaph", "epitaphs"],
    "slogans": ["slogan", "slogans"],
    "misquotations": ["misquotation", "misquotations"],
}

MOOD_FROM_TAG = {
    "romantic": {"love", "romance", "relationships"},
    "motivated": {"motivation", "success", "hard work", "determination", "focus"},
    "happy": {"happiness", "humour", "funny"},
    "hopeful": {"hope", "faith"},
    "calm": {"wisdom", "life", "balance", "philosophy"},
    "angry": {"truth", "politics", "war", "justice"},
}

AUTHOR_CATEGORY_HINTS = {
    "people",
    "writers",
    "poets",
    "authors",
    "philosophers",
    "actors",
    "actresses",
    "musicians",
    "births",
    "deaths",
}


@dataclass(frozen=True)
class PageTagMapping:
    categories: list[str]
    moods: list[str]
    page_type: str


def infer_page_type(page_title: str, page_categories: list[str]) -> str:
    title = normalize_text(page_title)
    if "(film)" in title or "(tv" in title or "season " in title:
        return "topic"

    lowered_categories = [normalize_text(item) for item in page_categories]
    for category in lowered_categories:
        if any(hint in category for hint in AUTHOR_CATEGORY_HINTS):
            return "author"
    return "topic"


def map_page_tags(
    page_title: str,
    seed_categories: list[str],
    page_categories: list[str],
) -> PageTagMapping:
    page_type = infer_page_type(page_title, page_categories)

    categories: list[str] = []
    seen = set()

    for raw in seed_categories:
        alias = SEED_CATEGORY_ALIAS.get(normalize_text(raw))
        if alias and alias not in seen:
            seen.add(alias)
            categories.append(alias)

    corpus = " | ".join([page_title, *seed_categories, *page_categories]).lower()
    for tag, keywords in TAG_KEYWORDS.items():
        if any(keyword in corpus for keyword in keywords):
            if tag not in seen:
                seen.add(tag)
                categories.append(tag)

    if not categories:
        categories.append("life")

    ordered_categories = _prioritize_categories(categories)
    moods = _derive_moods(ordered_categories)

    return PageTagMapping(
        categories=ordered_categories,
        moods=moods,
        page_type=page_type,
    )


def normalize_text(value: str) -> str:
    return " ".join(value.strip().lower().replace("_", " ").split())


def _prioritize_categories(categories: list[str]) -> list[str]:
    priority = [*PRIMARY_EXPLORE_CATEGORIES]
    for group_values in GROUPED_CATEGORIES.values():
        for item in group_values:
            normalized = normalize_text(item)
            if normalized not in priority:
                priority.append(normalized)

    rank = {tag: index for index, tag in enumerate(priority)}
    deduped = list(dict.fromkeys(normalize_text(tag) for tag in categories if tag.strip()))
    deduped.sort(key=lambda item: (rank.get(item, 10_000), item))
    return deduped


def _derive_moods(categories: list[str]) -> list[str]:
    tags = set(categories)
    moods: list[str] = []
    for mood, source_tags in MOOD_FROM_TAG.items():
        if tags.intersection(source_tags):
            moods.append(mood)
    return moods
