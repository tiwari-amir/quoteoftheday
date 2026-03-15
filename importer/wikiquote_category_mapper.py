from __future__ import annotations

import re
from dataclasses import dataclass

CURATED_CATEGORY_DISPLAY = [
    "Love",
    "Happiness",
    "Life",
    "Wisdom",
    "Success",
    "Friendship",
    "Inspiration",
    "Hope",
    "Courage",
    "Freedom",
    "Truth",
    "Strength",
    "Time",
    "Purpose",
    "Knowledge",
    "Growth",
    "Leadership",
    "Motivation",
    "Beauty",
    "Creativity",
    "Faith",
    "Peace",
    "Ambition",
    "Failure",
    "Resilience",
    "Justice",
    "Power",
    "Nature",
    "Death",
    "Society",
    "Identity",
    "Self-Discovery",
    "Forgiveness",
    "Regret",
    "Healing",
    "Loss",
    "Grief",
    "Fear",
    "Anxiety",
    "Desire",
    "Passion",
    "Imagination",
    "Gratitude",
    "Discipline",
    "Legacy",
    "Doubt",
    "Heartbreak",
    "Pain",
    "Mortality",
    "Suffering",
]

PRIMARY_EXPLORE_CATEGORIES = [
    "love",
    "happiness",
    "life",
    "wisdom",
    "success",
    "friendship",
    "inspiration",
    "hope",
    "courage",
    "freedom",
    "truth",
    "strength",
    "time",
    "purpose",
    "knowledge",
    "growth",
    "leadership",
    "motivation",
    "beauty",
    "creativity",
    "faith",
    "peace",
    "ambition",
    "failure",
    "resilience",
    "justice",
    "power",
    "nature",
    "death",
    "society",
    "identity",
    "self discovery",
    "forgiveness",
    "regret",
    "healing",
    "loss",
    "grief",
    "fear",
    "anxiety",
    "desire",
    "passion",
    "imagination",
    "gratitude",
    "discipline",
    "legacy",
    "doubt",
    "heartbreak",
    "pain",
    "mortality",
    "suffering",
]

GROUPED_CATEGORIES = {
    "inner_life": [
        "life",
        "purpose",
        "identity",
        "self discovery",
        "growth",
        "discipline",
        "legacy",
        "doubt",
    ],
    "emotion_relationships": [
        "love",
        "friendship",
        "forgiveness",
        "gratitude",
        "desire",
        "passion",
        "heartbreak",
        "regret",
    ],
    "resilience_conflict": [
        "hope",
        "courage",
        "strength",
        "failure",
        "resilience",
        "fear",
        "anxiety",
        "pain",
        "suffering",
    ],
    "thought_expression": [
        "wisdom",
        "truth",
        "knowledge",
        "creativity",
        "beauty",
        "imagination",
    ],
    "world_society": [
        "freedom",
        "justice",
        "power",
        "nature",
        "society",
        "peace",
        "leadership",
        "ambition",
    ],
    "mortality_healing": [
        "death",
        "mortality",
        "loss",
        "grief",
        "healing",
    ],
}

GROUP_BY_TAG = {
    " ".join(
        str(tag).strip().lower().replace("_", " ").replace("-", " ").replace("/", " ").split()
    ): group_name
    for group_name, tags in GROUPED_CATEGORIES.items()
    for tag in tags
}

GROUP_SELECTION_LIMITS = {
    "inner_life": 1,
    "emotion_relationships": 2,
    "resilience_conflict": 2,
    "thought_expression": 1,
    "world_society": 1,
    "mortality_healing": 2,
}

SEED_CATEGORY_ALIAS = {
    "self-discovery": "self discovery",
    "self discovery": "self discovery",
    "self improvement": "growth",
    "self-improvement": "growth",
    "motivational": "motivation",
    "inspirational": "inspiration",
    "humor": "creativity",
    "humour": "creativity",
    "romance": "love",
    "romantic": "love",
    "poetry": "creativity",
    "literature": "creativity",
    "art": "creativity",
    "music": "creativity",
    "religion": "faith",
    "science": "knowledge",
    "philosophy": "wisdom",
    "politics": "power",
    "family": "love",
    "funny": "happiness",
    "peaceful": "peace",
    "spirituality": "faith",
    "knowledge": "knowledge",
    "truth": "truth",
    "society": "society",
    "identity": "identity",
    "mortality": "mortality",
    "death": "death",
    "loss": "loss",
    "grief": "grief",
    "fear": "fear",
    "anxiety": "anxiety",
    "beauty": "beauty",
    "nature": "nature",
    "friendship": "friendship",
    "leadership": "leadership",
    "freedom": "freedom",
    "justice": "justice",
    "success": "success",
    "failure": "failure",
    "resilience": "resilience",
    "power": "power",
}

TAG_KEYWORDS = {
    "love": (
        "love",
        "loved",
        "beloved",
        "lover",
        "loved one",
        "affection",
        "heart",
    ),
    "happiness": (
        "happiness",
        "happy",
        "joy",
        "joyful",
        "delight",
        "cheerful",
        "cheer",
        "smile",
        "smiling",
        "laugh",
        "laughter",
        "bliss",
        "glad",
    ),
    "life": ("life", "living", "existence", "alive"),
    "wisdom": ("wisdom", "wise", "insight", "understanding"),
    "success": ("success", "succeed", "achievement", "accomplish", "victory"),
    "friendship": ("friendship", "friend", "companion", "companionship"),
    "inspiration": ("inspiration", "inspire", "uplift", "encourage"),
    "hope": ("hope", "hopeful", "optimism", "optimistic"),
    "courage": ("courage", "bravery", "brave", "valor"),
    "freedom": ("freedom", "free", "liberty", "liberation"),
    "truth": ("truth", "true", "honesty", "honest"),
    "strength": ("strength", "strong", "fortitude", "endurance"),
    "time": ("time", "timing", "moment", "future", "past"),
    "purpose": (
        "purpose",
        "meaning",
        "meanings",
        "meaningful",
        "calling",
        "mission",
        "goal",
        "goals",
        "aim",
        "aims",
        "destiny",
        "reason",
        "reasons",
    ),
    "knowledge": ("knowledge", "know", "learn", "learning", "study", "science"),
    "growth": ("growth", "grow", "become", "self improvement", "self improvement"),
    "leadership": ("leadership", "leader", "lead", "govern"),
    "motivation": ("motivation", "motivated", "drive", "driven"),
    "beauty": ("beauty", "beautiful", "beautifully"),
    "creativity": (
        "creativity",
        "creative",
        "art",
        "artist",
        "poetry",
        "poem",
        "image",
        "music",
        "song",
        "sing",
        "dance",
        "imagination",
    ),
    "faith": ("faith", "belief", "believe", "spiritual", "divine"),
    "peace": ("peace", "peaceful", "calm", "serenity"),
    "ambition": ("ambition", "aspiration", "aspire"),
    "failure": ("failure", "fail", "mistake", "defeat"),
    "resilience": (
        "resilience",
        "resilient",
        "persevere",
        "perseverance",
        "persist",
        "persistence",
        "endure",
        "enduring",
        "endurable",
        "overcome",
        "survive",
        "survival",
        "rise again",
        "stand back up",
    ),
    "justice": ("justice", "just", "rights", "fairness", "law"),
    "power": ("power", "powerful", "authority", "rule"),
    "nature": ("nature", "earth", "forest", "sea", "sky"),
    "death": ("death", "die", "dying", "dead"),
    "society": ("society", "social", "culture", "civilization"),
    "identity": ("identity", "self", "who am i", "who we are"),
    "self discovery": ("self discovery", "know yourself", "be yourself", "inner self"),
    "forgiveness": ("forgiveness", "forgive", "mercy"),
    "regret": ("regret", "remorse", "repent"),
    "healing": (
        "healing",
        "heal",
        "cure",
        "recover",
        "recovery",
        "healed",
        "heals",
        "cured",
        "incurable",
        "mend",
        "comfort",
        "solace",
        "restoration",
        "remedy",
    ),
    "loss": ("loss", "lost", "absence"),
    "grief": ("grief", "mourning", "sorrow"),
    "fear": ("fear", "afraid", "terror", "fright"),
    "anxiety": ("anxiety", "anxious", "worry", "worrying"),
    "desire": ("desire", "want", "longing", "craving"),
    "passion": ("passion", "passionate", "ardor", "fire"),
    "imagination": ("imagination", "imagine", "dream", "vision"),
    "gratitude": ("gratitude", "grateful", "thankful", "thanks"),
    "discipline": ("discipline", "self control", "self-control", "habit", "consistency"),
    "legacy": ("legacy", "remembered", "memory", "inheritance"),
    "doubt": ("doubt", "uncertainty", "skepticism", "skeptical"),
    "heartbreak": ("heartbreak", "broken heart", "heartbroken"),
    "pain": ("pain", "hurt", "wound", "suffer"),
    "mortality": ("mortality", "mortal", "finite", "impermanence"),
    "suffering": ("suffering", "suffer", "agony", "torment"),
}

STRICT_TEXT_EVIDENCE_TAGS = {
    "death",
    "happiness",
    "life",
    "truth",
    "time",
    "power",
    "knowledge",
    "growth",
    "society",
    "identity",
    "self discovery",
    "pain",
    "mortality",
    "suffering",
    "success",
    "failure",
}

TAG_MIN_SCORE = {
    "love": 4.0,
    "friendship": 4.0,
    "hope": 4.0,
    "courage": 4.0,
    "freedom": 4.0,
    "justice": 4.0,
    "nature": 4.0,
    "purpose": 3.5,
    "forgiveness": 4.0,
    "gratitude": 4.0,
    "healing": 3.0,
    "heartbreak": 4.0,
    "grief": 4.0,
    "resilience": 3.0,
    "death": 4.0,
    "happiness": 4.0,
    "life": 4.5,
    "truth": 4.5,
    "time": 4.5,
    "power": 4.5,
    "knowledge": 4.5,
    "growth": 4.5,
    "society": 4.5,
    "identity": 4.5,
    "pain": 4.0,
    "mortality": 4.0,
    "suffering": 4.0,
}

WEAK_KEYWORDS = {
    "creativity": {"art"},
    "desire": {"want"},
    "failure": {"mistake"},
    "faith": {"belief", "believe"},
    "friendship": {"friend"},
    "growth": {"become"},
    "identity": {"self"},
    "knowledge": {"know"},
    "life": {"living", "alive"},
    "loss": {"lost"},
    "nature": {"earth", "sky"},
    "pain": {"hurt"},
    "peace": {"calm"},
    "power": {"rule"},
    "society": {"social"},
    "strength": {"strong"},
    "time": {"moment"},
    "truth": {"true"},
}

BOOSTED_KEYWORDS = {
    "cure",
    "cured",
    "recover",
    "recovery",
    "incurable",
    "meaning",
    "meanings",
    "meaningful",
    "endure",
    "enduring",
    "endurable",
    "overcome",
    "survive",
    "survival",
    "persist",
    "persistence",
    "cheerful",
    "smile",
    "laughter",
}

MOOD_FROM_TAG = {
    "romantic": {"love", "friendship", "desire", "passion", "heartbreak"},
    "hopeful": {"hope", "healing", "forgiveness", "gratitude", "resilience"},
    "driven": {"success", "motivation", "discipline", "leadership", "ambition"},
    "reflective": {
        "life",
        "wisdom",
        "truth",
        "time",
        "purpose",
        "identity",
        "self discovery",
        "doubt",
    },
    "peaceful": {"peace", "faith", "beauty", "nature"},
    "heavy": {"death", "mortality", "loss", "grief", "pain", "suffering", "regret"},
    "bold": {"courage", "strength", "freedom", "justice", "power"},
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


def normalize_text(value: str) -> str:
    return " ".join(
        value.strip()
        .lower()
        .replace("_", " ")
        .replace("-", " ")
        .replace("/", " ")
        .split()
    )


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
    categories = _prioritize_categories(
        _direct_context_categories(
            page_title=page_title,
            seed_categories=seed_categories,
            page_categories=page_categories,
            fallback_categories=[],
        )
    )
    return PageTagMapping(
        categories=categories,
        moods=_derive_moods(categories),
        page_type=page_type,
    )


def map_quote_tags(
    page_title: str,
    quote_text: str,
    quote_author: str,
    seed_categories: list[str],
    page_categories: list[str],
    fallback_categories: list[str],
) -> PageTagMapping:
    page_type = infer_page_type(page_title, page_categories)
    categories = _score_quote_categories(
        page_title=page_title,
        quote_text=quote_text,
        quote_author=quote_author,
        seed_categories=seed_categories,
        page_categories=page_categories,
        fallback_categories=fallback_categories,
        page_type=page_type,
    )
    return PageTagMapping(
        categories=categories,
        moods=_derive_moods(categories),
        page_type=page_type,
    )


def _score_quote_categories(
    *,
    page_title: str,
    quote_text: str,
    quote_author: str,
    seed_categories: list[str],
    page_categories: list[str],
    fallback_categories: list[str],
    page_type: str,
) -> list[str]:
    normalized_quote = normalize_text(quote_text)
    normalized_title = normalize_text(page_title)
    normalized_author = normalize_text(quote_author)
    direct_context = _direct_context_categories(
        page_title=page_title,
        seed_categories=seed_categories,
        page_categories=page_categories,
        fallback_categories=fallback_categories,
    )
    direct_context_set = set(direct_context if page_type == "topic" else [])
    direct_page_tag = _canonical_category(page_title)

    scored: list[tuple[float, str]] = []
    for tag, keywords in TAG_KEYWORDS.items():
        quote_score = 0.0
        quote_hits = 0
        for index, keyword in enumerate(keywords):
            if not _contains_keyword(normalized_quote, keyword):
                continue
            quote_hits += 1
            quote_score += _keyword_weight(tag=tag, keyword=keyword, index=index)

        title_score = 0.0
        if page_type == "topic":
            for index, keyword in enumerate(keywords):
                if _contains_keyword(normalized_title, keyword):
                    title_score = max(
                        title_score,
                        _keyword_weight(tag=tag, keyword=keyword, index=index) * 0.65,
                    )

        context_score = 0.0
        if tag in direct_context_set:
            context_score += 1.5
        if direct_page_tag == tag:
            context_score += 1.25

        total = quote_score + title_score + context_score
        if quote_score == 0:
            total = 0.0
        elif tag in STRICT_TEXT_EVIDENCE_TAGS and quote_score < 4.0:
            continue
        elif quote_hits == 1 and _single_hit_is_weak(tag, normalized_quote):
            total -= 1.0

        if total <= 0:
            continue
        scored.append((total, tag))

    scored.sort(key=lambda item: (-item[0], _category_rank(item[1]), item[1]))
    selected = _select_categories_from_scores(scored)
    if selected:
        return selected

    fallback_candidates = [
        tag
        for score, tag in scored
        if score >= 3.0 and tag not in STRICT_TEXT_EVIDENCE_TAGS
    ]
    if fallback_candidates:
        return _prioritize_categories(fallback_candidates[:1])

    safe_context = [
        tag for tag in direct_context if tag not in STRICT_TEXT_EVIDENCE_TAGS
    ]
    return _prioritize_categories(safe_context[:1])


def _canonical_category(value: str) -> str | None:
    normalized = normalize_text(value)
    if not normalized:
        return None
    if normalized in SEED_CATEGORY_ALIAS:
        return SEED_CATEGORY_ALIAS[normalized]
    if normalized in PRIMARY_EXPLORE_CATEGORIES:
        return normalized
    return None


def _contains_keyword(corpus: str, keyword: str) -> bool:
    normalized_keyword = normalize_text(keyword)
    if not normalized_keyword:
        return False
    return re.search(rf"(?<!\w){re.escape(normalized_keyword)}(?!\w)", corpus) is not None


def _keyword_weight(*, tag: str, keyword: str, index: int) -> float:
    normalized_keyword = normalize_text(keyword)
    if not normalized_keyword:
        return 0.0
    if index < 2 or normalized_keyword == tag:
        return 4.0
    if normalized_keyword in BOOSTED_KEYWORDS:
        return 3.2
    if normalized_keyword in WEAK_KEYWORDS.get(tag, set()):
        return 1.5
    if " " in normalized_keyword:
        return 3.5
    if len(normalized_keyword) >= 8:
        return 3.0
    return 2.0


def _single_hit_is_weak(tag: str, normalized_quote: str) -> bool:
    weak_tokens = WEAK_KEYWORDS.get(tag, set())
    return any(_contains_keyword(normalized_quote, token) for token in weak_tokens)


def _tag_has_any_text_support(tag: str, normalized_quote: str) -> bool:
    for keyword in TAG_KEYWORDS.get(tag, ()):
        if _contains_keyword(normalized_quote, keyword):
            return True
    return False


def _direct_context_categories(
    *,
    page_title: str,
    seed_categories: list[str],
    page_categories: list[str],
    fallback_categories: list[str],
) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []

    for raw in [page_title, *seed_categories, *page_categories, *fallback_categories]:
        canonical = _canonical_category(raw)
        if canonical and canonical not in seen:
            seen.add(canonical)
            ordered.append(canonical)
    return ordered


def _category_rank(tag: str) -> int:
    try:
        return PRIMARY_EXPLORE_CATEGORIES.index(tag)
    except ValueError:
        return 10_000


def _select_categories_from_scores(
    scored_categories: list[tuple[float, str]],
) -> list[str]:
    selected: list[str] = []
    group_counts: dict[str, int] = {}

    for score, tag in scored_categories:
        if score < TAG_MIN_SCORE.get(tag, 4.0):
            continue
        group_name = GROUP_BY_TAG.get(tag, "")
        group_limit = GROUP_SELECTION_LIMITS.get(group_name, 1)
        if group_name and group_counts.get(group_name, 0) >= group_limit:
            continue
        selected.append(tag)
        if group_name:
            group_counts[group_name] = group_counts.get(group_name, 0) + 1
        if len(selected) >= 3:
            break

    return _prioritize_categories(selected)


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
