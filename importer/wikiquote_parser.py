from __future__ import annotations

import hashlib
import html
import re
from dataclasses import dataclass

try:
    from langdetect import DetectorFactory, LangDetectException, detect

    DetectorFactory.seed = 0
except ImportError:  # pragma: no cover - optional dependency fallback
    DetectorFactory = None
    LangDetectException = Exception
    detect = None

MIN_QUOTE_SCORE_STRONG = 3
MIN_AUTHOR_CONFIDENCE_SCORE = 2

_REF_RE = re.compile(r"<ref\b[^>/]*/>|<ref\b[^>]*>.*?</ref>", re.IGNORECASE | re.DOTALL)
_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_TAG_RE = re.compile(r"<[^>]+>")
_FOOTNOTE_RE = re.compile(r"\[[0-9]+\]")
_HEADING_RE = re.compile(r"^=+\s*([^=]+?)\s*=+$")
_CATEGORY_LINK_RE = re.compile(r"\[\[Category:(.+?)(?:\|.*?)?]]", re.IGNORECASE)
_INTERNAL_LINK_RE = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?]]")
_EXTERNAL_LINK_RE = re.compile(r"\[(https?://[^\s\]]+)(?:\s+([^\]]+))?]")
_URL_RE = re.compile(r"https?://|www\.", re.IGNORECASE)
_WORD_RE = re.compile(r"[A-Za-z']+")
_QUOTE_MARK_RE = re.compile(
    r'["\u2018\u2019\u201c\u201d]|(?:^|[\s(])\'[^\']{6,}\'(?:[\s).,;:!?]|$)'
)
_SENTENCE_PUNCTUATION_RE = re.compile(r'[.!?](?:["\')\]]|$)')
_LANGUAGE_TEXT_RE = re.compile(r"[^A-Za-z\u00C0-\u00FF'\s]")
_AUTHOR_PUNCT_RE = re.compile(r"[^\w\s]")
_HASH_PUNCT_RE = re.compile(r"[^\w\s]")
_TEMPLATE_RE = re.compile(
    r"\{\{(?P<name>quote|quotation|cquote|blockquote)\b(?P<body>.*?)\}\}",
    re.IGNORECASE | re.DOTALL,
)
_TRAILING_ATTR_RE = re.compile(
    r"^(?P<quote>.+?)\s+(?P<sep>(?:-|--|~|[\u2013\u2014]))\s+(?P<author>[A-Z][A-Za-z .\-]{1,40})$"
)
_LEADING_ATTR_RE = re.compile(
    r"^(?P<author>[A-Z][A-Za-z .\-]{1,40})\s*:\s*(?P<quote>.+)$"
)
_DATE_RE = re.compile(
    r"\b(?:\d{1,2}\s+)?(?:january|february|march|april|may|june|july|august|"
    r"september|october|november|december)\s+\d{4}\b",
    re.IGNORECASE,
)
_YEAR_RE = re.compile(r"\b(?:1[6-9]\d{2}|20\d{2})\b")
_TRAILING_YEAR_RE = re.compile(r"\s*(?:[\[(]?(?:c\.\s*)?(?:1[6-9]\d{2}|20\d{2})[\])]?)(?:\s*[.;,])?\s*$")
_ISBN_RE = re.compile(r"\b(?:isbn(?:-1[03])?:?\s*)?[0-9][0-9\-\s]{8,}\b", re.IGNORECASE)
_PUBLISHER_RE = re.compile(
    r"\b(?:publisher|published by|published in|written in|edition|volume|"
    r"chapter|page|pp?\.\s*\d+|press|books?|university press|oxford|wiley|"
    r"oldcastle|scarecrow|featured filmmaker)\b",
    re.IGNORECASE,
)
_COMMENTARY_RE = re.compile(
    r"\b(?:letter to|often misquoted|misattributed|incorrectly attributed|"
    r"wrongly attributed|as quoted in|from the book|published in|written in|"
    r"according to|see also|source:|note:)\b",
    re.IGNORECASE,
)
_EXPLANATORY_START_RE = re.compile(
    r"^(?:in philosophy|in literature|in religion|the term|this quote|one of the)\b",
    re.IGNORECASE,
)
_LEADING_VARIANT_INTRO_RE = re.compile(
    r"^(?:[\[(]\s*)?"
    r"(?:"
    r"(?:sometimes|often|commonly|frequently|widely|also)\s+"
    r"(?:paraphrased|quoted|rendered)(?:\s+as)?"
    r")"
    r"(?:\s*[\])])?"
    r"[\s,:;\-]*",
    re.IGNORECASE,
)
_MISQUOTE_HEADING_RE = re.compile(
    r"\b(?:misattributed|misquote|unsourced|quotes about|about|attributed)\b",
    re.IGNORECASE,
)
_IGNORED_HEADING_RE = re.compile(
    r"\b(?:see also|references|external links|misattributed|about|quotes about|"
    r"unsourced|attributed|notes)\b",
    re.IGNORECASE,
)
_TITLE_WORD_RE = re.compile(r"^[A-Z][a-z]+(?:-[A-Z][a-z]+)?\.?$")
_NON_ASCII_REJECTION_RATIO = 0.30
_MIN_QUOTE_LENGTH = 35
_MAX_QUOTE_LENGTH = 220
_CANDIDATE_EXTRACTION_THRESHOLD = 2
_KNOWN_MONONYMS = {
    "aesop",
    "aristotle",
    "buddha",
    "cicero",
    "confucius",
    "epictetus",
    "euripides",
    "homer",
    "horace",
    "laozi",
    "mencius",
    "moliere",
    "ovid",
    "plato",
    "plutarch",
    "rumi",
    "seneca",
    "socrates",
    "voltaire",
}
_HIGH_QUALITY_PAGE_WHITELIST = {
    "albert einstein",
    "friedrich nietzsche",
    "mark twain",
    "maya angelou",
    "oscar wilde",
}
_ICONIC_PHRASE_BONUSES = {
    "stay hungry": 4,
    "be the change": 4,
    "i have a dream": 4,
    "knowledge is power": 3,
    "time is money": 3,
}
_MEMORABLE_LENGTH_RANGE = (50, 120)
_DENSITY_PENALTIES = {
    "because": 1,
    "therefore": 2,
    "in order to": 2,
    "for example": 2,
}
_COMMON_IMPERATIVE_VERBS = {
    "act",
    "ask",
    "be",
    "believe",
    "change",
    "choose",
    "dream",
    "follow",
    "forget",
    "forgive",
    "give",
    "go",
    "hold",
    "imagine",
    "keep",
    "know",
    "learn",
    "let",
    "live",
    "look",
    "love",
    "make",
    "remember",
    "seek",
    "speak",
    "stand",
    "stay",
    "take",
    "think",
    "trust",
    "turn",
    "work",
}
_CLAUSE_SPLIT_RE = re.compile(r"(?:[,;:]\s+|\s+(?:and|but|or|nor|yet|so)\s+)", re.IGNORECASE)
_ENGLISH_STOPWORDS = {
    "a",
    "and",
    "are",
    "as",
    "at",
    "be",
    "but",
    "by",
    "for",
    "from",
    "have",
    "he",
    "her",
    "his",
    "i",
    "if",
    "in",
    "is",
    "it",
    "its",
    "me",
    "my",
    "not",
    "of",
    "on",
    "or",
    "our",
    "that",
    "the",
    "their",
    "them",
    "there",
    "they",
    "this",
    "to",
    "was",
    "we",
    "with",
    "you",
    "your",
}
_NON_ENGLISH_HINT_WORDS = {
    "avec",
    "car",
    "ce",
    "ces",
    "cette",
    "comme",
    "dans",
    "des",
    "elle",
    "faut",
    "heureux",
    "homme",
    "imaginer",
    "la",
    "le",
    "les",
    "lutte",
    "pour",
    "que",
    "qui",
    "remplir",
    "sommets",
    "suffit",
    "sur",
    "une",
    "vers",
}
_AUTHOR_ALIAS_MAP = {
    "a einstein": "albert einstein",
    "albert einstein": "albert einstein",
}
_AUTHOR_INVALID_VERB_RE = re.compile(
    r"\b(?:learn(?:ed|t)?|know(?:s|n)?|think(?:s|ing|thought)?|"
    r"believe(?:s|d|ing)?|say(?:s|ing|said)?|remember(?:s|ed|ing)?|"
    r"wrote|quoted|described)\b",
    re.IGNORECASE,
)
_AUTHOR_DISALLOWED_CHARS_RE = re.compile(r"[,\"':;()\d]")


@dataclass(frozen=True)
class QuoteCandidate:
    text: str
    extracted_author: str | None = None
    raw_line: str = ""
    attribution_style: str = "none"
    from_template: bool = False
    in_quote_section: bool = False


@dataclass(frozen=True)
class QuoteValidationResult:
    accepted: bool
    score: int
    reject_reason: str | None = None
    author_confidence_score: int = 0
    parser_quality_score: int = 0
    iconic_phrase_score: int = 0
    aphorism_structure_score: int = 0


def extract_quote_candidates(wikitext: str, max_candidates: int = 60) -> list[QuoteCandidate]:
    output: list[tuple[int, QuoteCandidate]] = []
    seen = set()

    for candidate in _extract_template_candidates(wikitext, limit=max_candidates):
        normalized = normalize_text_for_hash(candidate.text)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        output.append((_candidate_extraction_score(candidate), candidate))

    cleaned = _preclean_wikitext(wikitext)
    lines = cleaned.splitlines()
    in_quote_section = False
    ignored_section = False

    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue

        heading_match = _HEADING_RE.match(line)
        if heading_match:
            heading = _normalize_text(heading_match.group(1))
            ignored_section = _is_ignored_heading(heading)
            in_quote_section = _is_quote_heading(heading) and not ignored_section
            continue

        if ignored_section:
            continue
        if line.startswith("[[Category:"):
            continue
        if not line.startswith(("*", "#", ":*", ":#")):
            continue

        candidate = _build_bullet_candidate(raw_line, in_quote_section=in_quote_section)
        if candidate is None:
            continue
        normalized = normalize_text_for_hash(candidate.text)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)

        score = _candidate_extraction_score(candidate)
        if score < _CANDIDATE_EXTRACTION_THRESHOLD:
            continue
        output.append((score, candidate))
        if len(output) >= max_candidates * 4:
            break

    output.sort(key=lambda item: item[0], reverse=True)
    return [candidate for _, candidate in output[:max_candidates]]


def extract_quote_lines(wikitext: str, max_quotes: int = 60) -> list[str]:
    lines: list[str] = []
    for candidate in extract_quote_candidates(wikitext, max_candidates=max_quotes):
        if candidate.extracted_author:
            lines.append(f"{candidate.text} -- {candidate.extracted_author}")
        else:
            lines.append(candidate.text)
    return lines


def split_speaker_and_quote(line: str) -> tuple[str | None, str]:
    author, text, _ = _extract_attribution(line)
    return (author, text)


def extract_internal_links(wikitext: str, max_links: int = 120) -> list[str]:
    links: list[str] = []
    seen = set()

    for match in _INTERNAL_LINK_RE.finditer(wikitext):
        raw_target = (match.group(1) or "").strip()
        if not raw_target:
            continue
        if ":" in raw_target:
            namespace = raw_target.split(":", 1)[0].lower()
            if namespace in {
                "category",
                "file",
                "image",
                "template",
                "help",
                "portal",
                "special",
                "wikipedia",
                "w",
            }:
                continue

        normalized = _normalize_page_title(raw_target)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        links.append(normalized)
        if len(links) >= max_links:
            break

    return links


def extract_page_categories(wikitext: str) -> list[str]:
    categories: list[str] = []
    seen = set()
    for match in _CATEGORY_LINK_RE.finditer(wikitext):
        raw = (match.group(1) or "").strip()
        if not raw:
            continue
        normalized = _normalize_text(raw)
        if normalized in seen:
            continue
        seen.add(normalized)
        categories.append(normalized)
    return categories


def detect_quote_language(text: str) -> str:
    meaningful_chars = [char for char in text if not char.isspace()]
    if not meaningful_chars:
        return "unknown"

    non_ascii_count = sum(1 for char in meaningful_chars if ord(char) > 127)
    if (non_ascii_count / len(meaningful_chars)) > _NON_ASCII_REJECTION_RATIO:
        return "non-en"

    if len(re.findall(r"[A-Za-z]", text)) < 3:
        return "non-en"

    normalized = _LANGUAGE_TEXT_RE.sub(" ", text)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    words = [word.lower() for word in _WORD_RE.findall(normalized)]
    if not words:
        return "unknown"

    if detect is not None and len(words) >= 4:
        try:
            detected = detect(normalized[:400])
            if detected == "en":
                return "en"
            return detected or "non-en"
        except LangDetectException:
            pass

    english_hits = sum(1 for word in words if word in _ENGLISH_STOPWORDS)
    non_english_hits = sum(1 for word in words if word in _NON_ENGLISH_HINT_WORDS)
    if non_english_hits >= 2 and non_english_hits >= english_hits:
        return "non-en"
    if english_hits == 0 and len(words) >= 8:
        return "non-en"

    return "en"


def is_english_quote(text: str) -> bool:
    return detect_quote_language(text) == "en"


def normalize_author_text(value: str | None) -> str:
    if value is None:
        return ""
    normalized = _AUTHOR_PUNCT_RE.sub(" ", value.lower())
    normalized = re.sub(r"\b([a-z])\s+(?=[a-z]\b)", r"\1", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def canonicalize_author(value: str | None) -> str:
    normalized = normalize_author_text(value)
    if not normalized:
        return ""
    return _AUTHOR_ALIAS_MAP.get(normalized, normalized)


def classify_length_tier(text: str) -> str:
    length = len(text.strip())
    if length < 80:
        return "short"
    if length <= 160:
        return "medium"
    return "long"


def normalize_quote_text(text: str) -> str:
    normalized = sanitize_quote_text(text).lower()
    normalized = (
        normalized.replace("\u2018", "'")
        .replace("\u2019", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("_", " ")
    )
    normalized = _HASH_PUNCT_RE.sub(" ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def sanitize_quote_text(text: str) -> str:
    value = text.replace("\u201c", '"').replace("\u201d", '"')
    value = value.replace("\u2018", "'").replace("\u2019", "'")
    value = re.sub(r"\s+", " ", value).strip()

    previous = None
    while previous != value:
        previous = value
        value = _LEADING_VARIANT_INTRO_RE.sub("", value).strip()
        value = value.lstrip(" ,:;-").strip()
        value = _strip_trailing_source_metadata(value)
        if len(value) >= 2 and value[0] in {'"', "'"} and value[-1] == value[0]:
            value = value[1:-1].strip()

    value = value.strip('" ')
    value = re.sub(r"\s+", " ", value).strip()
    return value


def normalize_quote_text_key(text: str) -> str:
    return normalize_quote_text(text)


def normalize_text_for_hash(text: str) -> str:
    return normalize_quote_text_key(text)


def compute_quote_hash_from_normalized(normalized_text: str) -> str:
    return hashlib.sha1(normalized_text.encode("utf-8")).hexdigest()


def compute_quote_hash(text: str) -> str:
    normalized = normalize_quote_text_key(text)
    return compute_quote_hash_from_normalized(normalized)


def quote_similarity_tokens(text: str) -> tuple[str, ...]:
    normalized = normalize_quote_text(text)
    if not normalized:
        return ()

    raw_tokens = [
        token
        for token in _WORD_RE.findall(normalized)
        if token and token not in _ENGLISH_STOPWORDS
    ]
    if not raw_tokens:
        raw_tokens = [token for token in _WORD_RE.findall(normalized) if token]
    return tuple(sorted(set(raw_tokens)))


def jaccard_similarity(
    tokens_a: tuple[str, ...] | set[str] | frozenset[str],
    tokens_b: tuple[str, ...] | set[str] | frozenset[str],
) -> float:
    set_a = set(tokens_a)
    set_b = set(tokens_b)
    if not set_a and not set_b:
        return 1.0
    if not set_a or not set_b:
        return 0.0
    union = set_a | set_b
    if not union:
        return 0.0
    return len(set_a & set_b) / len(union)


def score_quote_quality(
    text: str,
    author: str | None,
    *,
    attribution_style: str = "page_author",
    from_template: bool = False,
    author_confidence_score: int | None = None,
    page_title: str | None = None,
) -> int:
    value = _normalize_candidate_text(text)
    confidence = (
        author_confidence_score
        if author_confidence_score is not None
        else _author_confidence_score(
            author,
            attribution_style=attribution_style,
            page_type="author",
            from_template=from_template,
        )
    )

    score = 0
    if _has_sentence_punctuation(value):
        score += 1
    if _healthy_letter_ratio(value):
        score += 1
    if _has_quote_marks(value):
        score += 1

    if attribution_style in {"trailing_dash", "template"}:
        score += 1

    if from_template:
        score += 1

    if confidence >= 3:
        score += 1

    if page_title and _normalize_text(page_title) in _HIGH_QUALITY_PAGE_WHITELIST:
        score += 1

    if "(" in value or ")" in value:
        score -= 1
    if "[" in value or "]" in value:
        score -= 1
    if sum(value.count(ch) for ch in ",;:") >= 4:
        score -= 1
    if _is_title_like(value):
        score -= 2
    if confidence <= MIN_AUTHOR_CONFIDENCE_SCORE:
        score -= 1
    score -= linguistic_density_penalty(value)

    return score


def iconicity_phrase_bonus(text: str) -> int:
    normalized = normalize_text_for_hash(text)
    bonus = 0
    for phrase, phrase_bonus in _ICONIC_PHRASE_BONUSES.items():
        if phrase in normalized:
            bonus += phrase_bonus
    return bonus


def aphorism_structure_score(text: str) -> int:
    value = _normalize_candidate_text(text)
    score = 0
    if _MEMORABLE_LENGTH_RANGE[0] <= len(value) <= _MEMORABLE_LENGTH_RANGE[1]:
        score += 2
    if _has_balanced_sentence_structure(value):
        score += 1
    if _has_imperative_verb(value):
        score += 1
    if _has_parallel_phrases(value):
        score += 2
    return score


def linguistic_density_penalty(text: str) -> int:
    normalized = normalize_text_for_hash(text)
    penalty = 0
    for fragment, fragment_penalty in _DENSITY_PENALTIES.items():
        if fragment in normalized:
            penalty += fragment_penalty
    return penalty


def is_quote_acceptable(
    text: str,
    author: str | None,
    threshold: int = MIN_QUOTE_SCORE_STRONG,
) -> bool:
    return evaluate_quote_candidate(text, author, threshold=threshold).accepted


def evaluate_quote_candidate(
    text: str,
    author: str | None,
    *,
    attribution_style: str = "page_author",
    from_template: bool = False,
    page_type: str = "author",
    page_title: str | None = None,
    threshold: int | None = MIN_QUOTE_SCORE_STRONG,
) -> QuoteValidationResult:
    value = _normalize_candidate_text(text)
    value = _strip_trailing_source_metadata(value)

    if detect_quote_language(value) != "en":
        return QuoteValidationResult(False, 0, "metadata", 0)

    reject_reason = _classify_quote_rejection(value)
    if reject_reason is not None:
        return QuoteValidationResult(False, 0, reject_reason, 0)

    if not validate_author_name(author, quote_text=value):
        return QuoteValidationResult(False, 0, "bad_author", 0)

    author_confidence_score = _author_confidence_score(
        author,
        attribution_style=attribution_style,
        page_type=page_type,
        from_template=from_template,
    )
    if author_confidence_score < MIN_AUTHOR_CONFIDENCE_SCORE:
        return QuoteValidationResult(
            False,
            0,
            "low_confidence",
            author_confidence_score,
            0,
            0,
            0,
        )

    parser_quality_score = score_quote_quality(
        value,
        author,
        attribution_style=attribution_style,
        from_template=from_template,
        author_confidence_score=author_confidence_score,
        page_title=page_title,
    )
    iconic_phrase_score = iconicity_phrase_bonus(value)
    aphoristic_score = aphorism_structure_score(value)
    if threshold is not None and parser_quality_score < threshold:
        return QuoteValidationResult(
            False,
            parser_quality_score,
            "low_score",
            author_confidence_score,
            parser_quality_score,
            iconic_phrase_score,
            aphoristic_score,
        )

    return QuoteValidationResult(
        True,
        parser_quality_score,
        None,
        author_confidence_score,
        parser_quality_score,
        iconic_phrase_score,
        aphoristic_score,
    )


def validate_author_name(author: str | None, quote_text: str | None = None) -> bool:
    value = _clean_author_candidate(author)
    if not value:
        return False
    if len(value) > 40:
        return False
    if _AUTHOR_DISALLOWED_CHARS_RE.search(value):
        return False
    if _AUTHOR_INVALID_VERB_RE.search(value):
        return False

    words = [word for word in re.split(r"\s+", value) if word]
    if not words:
        return False
    if len(words) == 1:
        if words[0].lower() not in _KNOWN_MONONYMS:
            return False
    elif len(words) < 2 or len(words) > 4:
        return False

    if any(not _looks_like_name_word(word) for word in words):
        return False
    if any(word.lower() in _ENGLISH_STOPWORDS for word in words):
        return False
    if any(len(word) > 1 and word.islower() for word in words):
        return False

    if quote_text:
        normalized_author = normalize_text_for_hash(value)
        normalized_quote = normalize_text_for_hash(quote_text)
        if normalized_author and normalized_author == normalized_quote:
            return False
        if normalized_author and normalized_author in normalized_quote and len(words) >= 2:
            return False

    return True


def _extract_template_candidates(wikitext: str, limit: int) -> list[QuoteCandidate]:
    output: list[QuoteCandidate] = []
    for match in _TEMPLATE_RE.finditer(wikitext):
        if len(output) >= limit:
            break
        name = (match.group("name") or "").strip().lower()
        body = match.group("body") or ""
        candidate = _parse_quote_template(name, body)
        if candidate is None:
            continue
        if detect_quote_language(candidate.text) != "en":
            continue
        output.append(candidate)
    return output


def _parse_quote_template(template_name: str, body: str) -> QuoteCandidate | None:
    parts = [part.strip() for part in body.split("|")]
    positional: list[str] = []
    named: dict[str, str] = {}
    for part in parts:
        if not part:
            continue
        if "=" in part:
            key, value = part.split("=", 1)
            named[key.strip().lower()] = value.strip()
        else:
            positional.append(part)

    text_value = (
        named.get("text")
        or named.get("quote")
        or named.get("quotetext")
        or named.get("content")
        or named.get("quotation")
    )
    author_value = (
        named.get("author")
        or named.get("sign")
        or named.get("person")
        or named.get("source")
    )
    if not text_value and positional:
        text_value = positional[0]
    if not author_value and len(positional) >= 2:
        author_value = positional[1]

    text = _clean_wikitext_value(text_value or "")
    author = _clean_author_candidate(_clean_wikitext_value(author_value or ""))
    if not text:
        return None
    if author and not validate_author_name(author, quote_text=text):
        author = None

    return QuoteCandidate(
        text=text,
        extracted_author=author,
        raw_line=f"{{{{{template_name}}}}}",
        attribution_style="template" if author else "none",
        from_template=True,
        in_quote_section=True,
    )


def _build_bullet_candidate(raw_line: str, *, in_quote_section: bool) -> QuoteCandidate | None:
    line = _clean_bullet_line(raw_line)
    if not line:
        return None
    if _is_mostly_metadata_line(line):
        return None
    if detect_quote_language(line) != "en":
        return None

    author, text, attribution_style = _extract_attribution(line)
    if _classify_extraction_rejection(text, in_quote_section=in_quote_section) is not None:
        return None

    return QuoteCandidate(
        text=text,
        extracted_author=author,
        raw_line=line,
        attribution_style=attribution_style,
        from_template=False,
        in_quote_section=in_quote_section,
    )


def _extract_attribution(line: str) -> tuple[str | None, str, str]:
    value = _normalize_candidate_text(line)

    trailing_match = _TRAILING_ATTR_RE.match(value)
    if trailing_match:
        author = _clean_author_candidate(trailing_match.group("author"))
        quote = _normalize_candidate_text(trailing_match.group("quote"))
        if validate_author_name(author, quote_text=quote):
            return (author, quote, "trailing_dash")

    leading_match = _LEADING_ATTR_RE.match(value)
    if leading_match:
        author = _clean_author_candidate(leading_match.group("author"))
        quote = _normalize_candidate_text(leading_match.group("quote"))
        if validate_author_name(author, quote_text=quote):
            return (author, quote, "leading_label")

    return (None, value, "none")


def _preclean_wikitext(source: str) -> str:
    text = _COMMENT_RE.sub(" ", source)
    text = _REF_RE.sub(" ", text)
    text = _strip_templates(text)
    return text


def _strip_templates(text: str) -> str:
    template_re = re.compile(r"\{\{[^{}]*}}")
    previous = None
    while previous != text:
        previous = text
        text = template_re.sub(" ", text)
    return text


def _clean_bullet_line(raw_line: str) -> str:
    line = raw_line
    line = re.sub(r"^[*#:;\s]+", "", line).strip()
    if not line:
        return ""

    line = line.replace("'''", "").replace("''", "")
    line = _INTERNAL_LINK_RE.sub(_replace_internal_link, line)
    line = _EXTERNAL_LINK_RE.sub(_replace_external_link, line)
    line = _TAG_RE.sub(" ", line)
    line = _FOOTNOTE_RE.sub(" ", line)
    line = html.unescape(line)
    line = re.sub(r"\s+", " ", line).strip(" -\t")
    line = line.replace("\u201c", '"').replace("\u201d", '"')
    line = line.replace("\u2018", "'").replace("\u2019", "'")
    return line


def _clean_wikitext_value(value: str) -> str:
    text = value or ""
    text = _INTERNAL_LINK_RE.sub(_replace_internal_link, text)
    text = _EXTERNAL_LINK_RE.sub(_replace_external_link, text)
    text = _TAG_RE.sub(" ", text)
    text = _FOOTNOTE_RE.sub(" ", text)
    text = _REF_RE.sub(" ", text)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return _normalize_candidate_text(text)


def _replace_internal_link(match: re.Match[str]) -> str:
    target = (match.group(1) or "").strip()
    label = (match.group(2) or "").strip()
    return label or target


def _replace_external_link(match: re.Match[str]) -> str:
    label = (match.group(2) or "").strip()
    return label


def _normalize_candidate_text(text: str) -> str:
    return sanitize_quote_text(text)


def _strip_trailing_source_metadata(text: str) -> str:
    value = text.strip()
    previous = None
    while previous != value:
        previous = value
        value = re.sub(r"\s*\[[0-9]+\]\s*$", "", value).strip()
        value = re.sub(
            r"\s*(?:[-,;]\s*)?(?:source:|note:|published in|written in|page\s+\d+|pp?\.\s*\d+)[^.!?]*$",
            "",
            value,
            flags=re.IGNORECASE,
        ).strip()
        value = _TRAILING_YEAR_RE.sub("", value).strip()
    return value


def _classify_extraction_rejection(text: str, *, in_quote_section: bool) -> str | None:
    value = text.strip()
    if not value:
        return "metadata"
    if _is_mostly_metadata_line(value):
        return "metadata"
    if _EXPLANATORY_START_RE.match(value):
        return "commentary"
    if _COMMENTARY_RE.search(value):
        return "commentary"
    if _IGNORED_HEADING_RE.search(value) and not in_quote_section:
        return "metadata"
    return None


def _classify_quote_rejection(text: str) -> str | None:
    value = text.strip()
    if not value:
        return "metadata"
    if len(value) < _MIN_QUOTE_LENGTH or len(value) > _MAX_QUOTE_LENGTH:
        return "metadata"
    if not _has_sentence_punctuation(value):
        return "metadata"
    if not _healthy_letter_ratio(value):
        return "metadata"
    if _COMMENTARY_RE.search(value):
        return "commentary"
    if _EXPLANATORY_START_RE.match(value):
        return "commentary"
    if _has_inline_date_metadata(value):
        return "metadata"
    if _is_title_like(value):
        return "title_like"
    if _has_too_many_delimiters(value):
        return "metadata"
    if _URL_RE.search(value):
        return "metadata"
    if _ISBN_RE.search(value):
        return "metadata"
    if _PUBLISHER_RE.search(value):
        return "metadata"
    if _is_mostly_metadata_line(value):
        return "metadata"
    return None


def _candidate_extraction_score(candidate: QuoteCandidate) -> int:
    score = 0
    if candidate.in_quote_section:
        score += 1
    if candidate.from_template:
        score += 2
    if candidate.attribution_style == "trailing_dash":
        score += 2
    elif candidate.attribution_style == "template":
        score += 2
    elif candidate.attribution_style == "leading_label":
        score += 1
    if _has_quote_marks(candidate.text):
        score += 1
    if _has_sentence_punctuation(candidate.text):
        score += 1
    return score


def _author_confidence_score(
    author: str | None,
    *,
    attribution_style: str,
    page_type: str,
    from_template: bool,
) -> int:
    if not validate_author_name(author):
        return 0
    if from_template or attribution_style == "template":
        return 4
    if attribution_style == "trailing_dash":
        return 4
    if attribution_style == "leading_label":
        return 3
    if attribution_style == "stored_explicit":
        return 2
    if attribution_style == "page_author" and page_type == "author":
        return 2
    return 0


def _healthy_letter_ratio(text: str) -> bool:
    meaningful = [char for char in text if not char.isspace()]
    if not meaningful:
        return False
    letters = sum(1 for char in meaningful if char.isalpha())
    digits = sum(1 for char in meaningful if char.isdigit())
    ratio = letters / len(meaningful)
    digit_ratio = digits / len(meaningful)
    return ratio >= 0.65 and digit_ratio <= 0.12


def _has_balanced_punctuation(text: str) -> bool:
    punctuation_count = len(re.findall(r"[!?.,;:]", text))
    ratio = punctuation_count / max(1, len(text))
    sentence_marks = len(re.findall(r"[.!?]", text))
    return 1 <= sentence_marks <= 2 and ratio <= 0.10


def _has_balanced_sentence_structure(text: str) -> bool:
    if not _has_balanced_punctuation(text):
        return False
    clauses = _split_clauses(text)
    if len(clauses) < 2:
        words = _normalized_words(text)
        return 7 <= len(words) <= 18 and len(text) <= _MEMORABLE_LENGTH_RANGE[1]

    lengths = [len(clause) for clause in clauses]
    if any(length < 2 for length in lengths):
        return False
    return max(lengths) / max(1, min(lengths)) <= 2.0


def _has_imperative_verb(text: str) -> bool:
    words = _normalized_words(text)
    if not words:
        return False
    if words[0] in _COMMON_IMPERATIVE_VERBS:
        return True
    if len(words) >= 3 and words[0] == "do" and words[1] == "not":
        return True
    if len(words) >= 2 and words[0] in {"don't", "never", "always"}:
        return True
    if len(words) >= 2 and words[0] == "let":
        return words[1] in {"us", "yourself", "them"} or words[1] in _COMMON_IMPERATIVE_VERBS
    return False


def _has_parallel_phrases(text: str) -> bool:
    normalized = normalize_text_for_hash(text)
    if re.search(r"\bnot\b.+\bbut\b", normalized):
        return True

    clauses = _split_clauses(text)
    if len(clauses) >= 2:
        first_words = [clause[0] for clause in clauses if clause]
        if len(first_words) != len(set(first_words)):
            return True

        leading_pairs = [" ".join(clause[:2]) for clause in clauses if len(clause) >= 2]
        if leading_pairs and len(leading_pairs) != len(set(leading_pairs)):
            return True

    repeated_to_phrases = re.findall(r"\bto\s+[a-z']+\b", normalized)
    return len(repeated_to_phrases) >= 2 and len(set(repeated_to_phrases)) >= 2


def _split_clauses(text: str) -> list[list[str]]:
    parts = [part.strip() for part in _CLAUSE_SPLIT_RE.split(text) if part.strip()]
    return [_normalized_words(part) for part in parts if part]


def _normalized_words(text: str) -> list[str]:
    return [word.lower() for word in _WORD_RE.findall(text)]


def _has_inline_date_metadata(text: str) -> bool:
    trimmed = _strip_trailing_source_metadata(text)
    if _DATE_RE.search(trimmed):
        return True
    year_matches = list(_YEAR_RE.finditer(trimmed))
    if not year_matches:
        return False
    for match in year_matches:
        suffix = trimmed[match.end() :].strip()
        if suffix:
            return True
    return False


def _has_too_many_delimiters(text: str) -> bool:
    bracket_count = sum(text.count(ch) for ch in "()[]")
    semicolon_count = text.count(";")
    colon_count = text.count(":")
    return bracket_count > 2 or semicolon_count > 1 or colon_count > 1


def _is_mostly_metadata_line(text: str) -> bool:
    value = text.strip()
    lowered = value.lower()
    if not value:
        return True
    if lowered.startswith(("source:", "note:", "published in", "written in")):
        return True
    if _URL_RE.search(value) or _ISBN_RE.search(value):
        return True
    if _PUBLISHER_RE.search(value):
        return True
    if value.count("|") >= 2:
        return True
    if re.fullmatch(r"[\W\d_]+", value):
        return True
    symbols = sum(1 for char in value if not char.isalnum() and not char.isspace())
    return symbols / max(1, len(value)) > 0.20


def _is_title_like(text: str) -> bool:
    if _has_quote_marks(text):
        return False
    words = [word.strip(".,!?;:") for word in text.split() if word.strip(".,!?;:")]
    if len(words) < 5:
        return False
    title_like = 0
    considered = 0
    for word in words:
        lowered = word.lower()
        if lowered in _ENGLISH_STOPWORDS:
            continue
        considered += 1
        if _TITLE_WORD_RE.fullmatch(word):
            title_like += 1
    if considered < 4:
        return False
    return (title_like / considered) >= 0.75


def _is_ignored_heading(heading: str) -> bool:
    return bool(_IGNORED_HEADING_RE.search(heading))


def _is_quote_heading(heading: str) -> bool:
    if _is_ignored_heading(heading):
        return False
    return any(token in heading for token in ("quote", "quotation", "saying", "dialogue", "lyrics"))


def _has_quote_marks(text: str) -> bool:
    return bool(_QUOTE_MARK_RE.search(text))


def _has_sentence_punctuation(text: str) -> bool:
    return bool(_SENTENCE_PUNCTUATION_RE.search(text))


def _clean_author_candidate(value: str | None) -> str:
    if value is None:
        return ""
    cleaned = value.replace("_", " ")
    cleaned = re.sub(r"\s*\([^)]{1,40}\)\s*$", "", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" \t-~\"'")
    return cleaned


def _looks_like_name_word(word: str) -> bool:
    if len(word) == 1 and word.isalpha():
        return True
    if re.fullmatch(r"[A-Z]\.", word):
        return True
    segments = [segment for segment in word.split("-") if segment]
    if not segments:
        return False
    return all(segment[0].isupper() and segment[1:].islower() for segment in segments if len(segment) > 1)


def _normalize_page_title(raw_title: str) -> str:
    title = raw_title.replace("_", " ").strip()
    title = re.sub(r"\s+", " ", title)
    return title


def _normalize_text(value: str) -> str:
    return " ".join(value.strip().lower().split())
