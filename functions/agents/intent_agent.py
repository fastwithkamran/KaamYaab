"""
KaamYaab — Intent Agent  (v4 — Optimized)
KaamYaab Autonomous Agent System | Cohere-Powered

Extracts structured intent from multilingual user input
(Urdu, Roman Urdu, English, mixed/code-switched).

Bug Fixes (v2 → v3)
────────────────────
• BUG-1 FIXED: _detect_area returned `candidate` in BOTH branches of the if/else —
  the else branch now correctly returns "Unknown" instead of `candidate`.
• BUG-2 FIXED: _detect_urgency default was "medium" (too aggressive) — changed to "low".
• BUG-3 FIXED: COMPLEXITY_HIGH had "replace" listed twice (set dedup is harmless but confusing).
• BUG-4 FIXED: _generate_with_retry raised last_error which could be None on the
  very first attempt if no exception occurred but model returned None — added guard.
• MIGRATION: Replaced google.generativeai with Cohere (command-r-plus).
  Set COHERE_API_KEY in your environment — no key needed from you, just export it.

Bug Fixes (v3 → v4)
────────────────────
• FIX-1: COMPLEXITY_MED contained "cleaning" — any Cleaning service request was classified
  as "intermediate" complexity. Routine cleaning is "basic". Removed "cleaning" from the set.
• FIX-2: _detect_service used substring `k in lower` for all keywords, causing short tokens
  like "ac" to match unrelated words (e.g. "place", "each"). Short keywords (≤3 chars) now
  use word-boundary regex matching.
• FIX-12: Sentiment detection in fast_parse was binary (frustrated vs neutral). Added polite
  marker detection and a dedicated "urgent" sentiment for high-urgency non-frustrated requests.
"""

import json
import logging
import os
import re
import time
from typing import Optional

try:
    import cohere
except ImportError:          # pragma: no cover
    cohere = None

logger = logging.getLogger(__name__)

MAX_RETRIES         = 3
MAX_BACKOFF_SECONDS = 4

_cohere_api_key = os.getenv("COHERE_API_KEY", "").strip()
co: Optional[object] = None
if _cohere_api_key and cohere is not None:
    co = cohere.Client(api_key=_cohere_api_key)
elif _cohere_api_key and cohere is None:
    logger.warning("[IntentAgent] cohere package not installed — run: pip install cohere")
elif not _cohere_api_key:
    logger.info("[IntentAgent] COHERE_API_KEY not set — fast_parse fallback active")

# ── Cohere Prompt ──────────────────────────────────────────────────────────────
INTENT_PROMPT = """
You are the Intent Agent for KaamYaab, an AI service orchestrator for Pakistan's
informal economy. Your job: parse a potentially noisy, code-switched user request and
return clean structured data.

User request (may be Urdu, Roman Urdu, English, or mixed):
"{raw_input}"

Return ONLY valid JSON — no markdown fences, no extra text:
{{
  "service_type":          "AC Repair | Plumbing | Electrical | Tutoring | Cleaning | Unknown",
  "location":              "full location string or 'Islamabad'",
  "area":                  "sector code like G-13, F-10, or extracted area name",
  "urgency":               "low | medium | high | emergency",
  "preferred_time":        "morning | afternoon | evening | flexible | HH:MM",
  "preferred_date":        "today | tomorrow | day_after | flexible | YYYY-MM-DD",
  "budget_sensitivity":    0.0,
  "confidence":            0.0,
  "language":              "urdu | roman_urdu | english | mixed",
  "clarification_needed":  false,
  "clarification_question":"",
  "issue_description":     "brief description in the same language as input",
  "job_complexity":        "basic | intermediate | complex",
  "risk_score":            0.0,
  "sentiment":             "neutral | frustrated | polite | urgent"
}}

Scoring rules:
- budget_sensitivity: 0.0 = flexible, 1.0 = very tight.
  Keywords → high: "zyada nahi", "sasta", "kam paise", "budget tight", "cheap", "affordable"
- confidence: 0.0–1.0. If < 0.75 → clarification_needed = true.
  Deduct for: missing location (-0.10), ambiguous service (-0.15), misspelling (-0.05).
- risk_score: 0.0–1.0. High if: vague description, no area, extreme urgency with low budget.
- urgency: "emergency" only for immediate danger / total failure; "high" for same-day;
  "medium" for tomorrow; "low" for flexible scheduling.
- Urdu mappings: subah=morning, dopahar=afternoon, shaam=evening,
  kal=tomorrow, aaj=today, jaldi/foran/abhi=high urgency, foori=emergency,
  bijli=Electrical, pani/pipe=Plumbing, safai=Cleaning, ac/thanda=AC Repair.
- Misspellings to normalise: acond/akond→AC Repair, bijly→Electrical, safaai→Cleaning,
  plumbar→Plumbing, techar→Tutoring.
- job_complexity: "complex" if install/rewire/overhaul/replace compressor;
  "intermediate" if repair/service/diagnose/gas refill/leak fix;
  "basic" if cleaning/filter change/check/minor fix.
"""

# ── Language Detection ─────────────────────────────────────────────────────────
_ROMAN_URDU_PAT = re.compile(
    r'\b(hai|karo|chahiye|kal|subah|mein|nahi|bhai|thik|kaam|mujhe|zyada|'
    r'abhi|jaldi|aaj|dopahar|shaam|pani|bijli|safai|acond|ghar|kharab|nahi)\b',
    re.I,
)

def detect_language(text: str) -> str:
    has_arabic = bool(re.search(r'[\u0600-\u06FF]', text))
    has_latin  = bool(re.search(r'[a-zA-Z]', text))
    if has_arabic and has_latin:
        return "mixed"
    if has_arabic:
        return "urdu"
    if _ROMAN_URDU_PAT.search(text):
        return "roman_urdu"
    return "english"


# ── Service Keyword Map (phonetics + misspellings included) ───────────────────
SERVICE_KEYWORDS: dict[str, list[str]] = {
    "AC Repair":   [
        "ac", "air condition", "aircon", "acond", "akond", "a/c",
        "cooling", "ٹھنڈا", "thanda", "ac kharab", "gas fill",
        "compressor", "hvac", "inverter ac", "split ac",
    ],
    "Plumbing":    [
        "pipe", "plumb", "plumbar", "plumber", "leak", "pani", "پانی",
        "drain", "tap", "water", "naali", "bathroom fitting",
        "water heater", "pipe burst", "sewerage",
    ],
    "Electrical":  [
        "electric", "bijli", "bijly", "بجلی", "wiring", "light",
        "switch", "mcb", "generator", "solar", "ups", "inverter",
        "load shedding", "short circuit", "fan", "socket",
    ],
    "Tutoring":    [
        "tutor", "teacher", "techar", "parhai", "parhana",
        "maths", "physics", "chemistry", "biology", "coaching",
        "class", "mdcat", "ecat", "o-level", "a-level", "matric",
    ],
    "Cleaning":    [
        "clean", "safai", "safaai", "صفائی", "jhadu", "sweep",
        "mop", "home clean", "deep clean", "sofa shampoo",
        "carpet wash", "marble polish", "office clean",
    ],
}

# ── Area Coordinate Map (Islamabad sectors) ───────────────────────────────────
AREA_COORDS: dict[str, tuple[float, float]] = {
    "G-13": (33.7215, 73.0433),
    "G-11": (33.7180, 73.0521),
    "G-14": (33.7290, 73.0390),
    "G-15": (33.7300, 73.0380),
    "G-12": (33.7185, 73.0505),
    "G-10": (33.7150, 73.0500),
    "G-9":  (33.7100, 73.0470),
    "F-10": (33.7050, 73.0600),
    "F-11": (33.7100, 73.0620),
    "F-7":  (33.7200, 73.0640),
    "F-8":  (33.7230, 73.0610),
    "I-8":  (33.6950, 73.0700),
    "E-11": (33.7350, 73.0200),
}

# ── Urgency Keywords (priority-ordered: higher index = higher urgency) ─────────
URGENCY_TIERS = [
    (["emergency", "foori", "فوری", "fire", "flood", "gas leak", "bijli ka shock"], "emergency"),
    (["urgent", "abhi", "ابھی", "jaldi", "jaldee", "foran", "immediately", "asap"],  "high"),
    (["aaj", "today", "آج", "same day", "within hours"],                               "high"),
    (["kal", "tomorrow", "اگلا"],                                                       "medium"),
    (["weekend", "next week", "baad mein", "flexible", "whenever"],                    "low"),
]

# ── Budget Keywords ────────────────────────────────────────────────────────────
BUDGET_KEYWORDS = {
    "very_tight": ["bilkul nahi", "bohot kam", "zyada afford nahi", "barely"],
    "tight":      ["zyada nahi", "sasta", "kam paise", "budget tight", "cheap", "affordable",
                   "ارزاں", "save", "discounted"],
    "moderate":   ["reasonable", "fair price", "market rate", "theek thak"],
}

# ── Complexity Keywords ────────────────────────────────────────────────────────
# BUG-3 FIX: removed duplicate "replace" from the set
# FIX-1: removed "cleaning" from COMPLEXITY_MED — it was causing every Cleaning
# service request to be classified as "intermediate" when routine cleaning is "basic".
COMPLEXITY_HIGH = {"install", "installation", "wiring", "replace", "compressor",
                   "overhaul", "rewire", "complete", "full service"}
COMPLEXITY_MED  = {"gas", "diagnose", "repair", "service", "leak", "fix", "refill",
                   "check", "tuneup", "tune-up"}


# ── Polite Markers ─────────────────────────────────────────────────────────────
# FIX-12: used by fast_parse to distinguish "urgent but polite" from "frustrated"
_POLITE_MARKERS = {
    "please", "kindly", "shukriya", "shukria", "meherbani",
    "if possible", "when convenient", "no rush", "ap ki meherbani",
}

def _detect_area(lower: str) -> str:
    """Return the best matched Islamabad sector or 'Unknown'."""
    for area in AREA_COORDS:
        if area.lower() in lower:
            return area
    # Broader fuzzy match
    patterns = [
        (r'\bg[\s-]?(\d{1,2})\b', lambda m: f"G-{m.group(1)}"),
        (r'\bf[\s-]?(\d{1,2})\b', lambda m: f"F-{m.group(1)}"),
        (r'\bi[\s-]?(\d{1,2})\b', lambda m: f"I-{m.group(1)}"),
        (r'\be[\s-]?(\d{1,2})\b', lambda m: f"E-{m.group(1)}"),
    ]
    for pat, fmt in patterns:
        m = re.search(pat, lower)
        if m:
            candidate = fmt(m)
            # BUG-1 FIX: original code returned `candidate` in BOTH branches —
            # the else-branch was a dead no-op. Now properly returns "Unknown"
            # when the fuzzy-matched sector is not in our known coordinate map.
            return candidate if candidate in AREA_COORDS else "Unknown"
    return "Unknown"


def _detect_service(lower: str) -> str:
    # FIX-2: short tokens (≤3 chars) use word-boundary regex so "ac" does not
    # match inside "place", "each", "practice", etc.
    for svc, keywords in SERVICE_KEYWORDS.items():
        for k in keywords:
            if len(k) <= 3:
                if re.search(rf'\b{re.escape(k)}\b', lower):
                    return svc
            elif k in lower:
                return svc
    return "Unknown"


def _detect_urgency(lower: str) -> str:
    for keywords, level in URGENCY_TIERS:
        if any(k in lower for k in keywords):
            return level
    # BUG-2 FIX: was returning "medium" as default, which over-stated urgency
    # for casual / unspecified requests. "low" is the correct safe default.
    return "low"


def _detect_budget(lower: str) -> float:
    for kws in BUDGET_KEYWORDS["very_tight"]:
        if kws in lower:
            return 0.95
    for kws in BUDGET_KEYWORDS["tight"]:
        if kws in lower:
            return 0.80
    for kws in BUDGET_KEYWORDS["moderate"]:
        if kws in lower:
            return 0.40
    return 0.50


def _detect_complexity(lower: str) -> str:
    words = set(lower.split())
    if words & COMPLEXITY_HIGH:
        return "complex"
    if words & COMPLEXITY_MED:
        return "intermediate"
    return "basic"


def _detect_time(lower: str) -> str:
    if any(w in lower for w in ["subah", "morning", "صبح", "fajar"]):
        return "morning"
    if any(w in lower for w in ["afternoon", "dopahar", "دوپہر", "zuhar"]):
        return "afternoon"
    if any(w in lower for w in ["evening", "shaam", "شام", "raat", "night"]):
        return "evening"
    m = re.search(r'\b(\d{1,2}:\d{2})\b', lower)
    if m:
        return m.group(1)
    return "flexible"


def _detect_date(lower: str) -> str:
    if any(w in lower for w in ["aaj", "today", "آج", "abhi"]):
        return "today"
    if any(w in lower for w in ["kal", "tomorrow", "کل"]):
        return "tomorrow"
    if any(w in lower for w in ["parson", "day after", "2 din"]):
        return "day_after"
    return "flexible"


def _compute_confidence(service: str, area: str, time_pref: str, lang: str) -> float:
    score = 0.70
    if service != "Unknown":
        score += 0.15
    if area != "Unknown":
        score += 0.10
    if time_pref != "flexible":
        score += 0.05
    if lang == "mixed":
        score -= 0.03
    return round(min(score, 0.98), 2)


# ── Fast Rule-Based Parser ─────────────────────────────────────────────────────

def fast_parse(text: str) -> dict:
    """Deterministic rule-based parser. Used when Cohere is unavailable."""
    lower = text.lower()

    service    = _detect_service(lower)
    urgency    = _detect_urgency(lower)
    area       = _detect_area(lower)
    budget     = _detect_budget(lower)
    time_pref  = _detect_time(lower)
    date_pref  = _detect_date(lower)
    complexity = _detect_complexity(lower)
    lang       = detect_language(text)
    confidence = _compute_confidence(service, area, time_pref, lang)

    clarification_needed = service == "Unknown" or confidence < 0.75
    if service == "Unknown":
        q = ("Ap kaunsi service chahiye? مثلاً: "
             "AC Repair, Plumbing, Electrical, Tutoring, ya Cleaning\n"
             "(Which service do you need?)")
    elif area == "Unknown":
        q = "Ap ka area / sector kya hai? (G-13, F-10, etc.)"
    else:
        q = ""

    # Risk score
    risk = 0.0
    if service == "Unknown":
        risk += 0.30
    if area == "Unknown":
        risk += 0.20
    if urgency == "emergency" and budget >= 0.75:
        risk += 0.25
    risk = round(min(risk, 1.0), 2)

    # FIX-12: four-way sentiment — emergency→frustrated, polite high-urgency→urgent,
    # polite markers present→polite, otherwise→neutral.
    is_polite = any(m in lower for m in _POLITE_MARKERS)
    if urgency == "emergency":
        sentiment = "frustrated"
    elif urgency == "high" and not is_polite:
        sentiment = "urgent"
    elif is_polite:
        sentiment = "polite"
    else:
        sentiment = "neutral"

    return {
        "service_type":           service,
        "location":               "Islamabad",
        "area":                   area,
        "urgency":                urgency,
        "preferred_time":         time_pref,
        "preferred_date":         date_pref,
        "budget_sensitivity":     budget,
        "confidence":             confidence,
        "language":               lang,
        "clarification_needed":   clarification_needed,
        "clarification_question": q,
        "issue_description":      text[:150],
        "job_complexity":         complexity,
        "risk_score":             risk,
        "sentiment":              sentiment,
    }


# ── Cohere Call with Retry ─────────────────────────────────────────────────────

def _generate_with_retry(prompt: str) -> str:
    """
    Calls Cohere command-r-plus with retry/backoff.
    Returns the raw text response.

    BUG-4 FIX: original code stored last_error = None and could raise None.
    Now we raise a RuntimeError if we exhaust retries with no exception recorded.
    """
    last_error: Optional[Exception] = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            response = co.chat(                          # type: ignore[union-attr]
                model="command-r-plus",
                message=prompt,
                temperature=0.05,
                max_tokens=600,
                preamble=(
                    "You are a structured JSON extractor. "
                    "Always return valid JSON only — no markdown fences, no prose."
                ),
            )
            return response.text
        except Exception as exc:
            last_error = exc
            msg = str(exc).lower()
            retriable = any(x in msg for x in ("429", "rate", "quota", "unavailable", "timeout"))
            if attempt == MAX_RETRIES or not retriable:
                break
            time.sleep(min(MAX_BACKOFF_SECONDS, 2 ** attempt))

    if last_error is not None:
        raise last_error
    raise RuntimeError("[IntentAgent] Cohere returned no response after all retries.")


# ── Main Entry Point ───────────────────────────────────────────────────────────

def run(raw_input: str, use_cohere: bool = True) -> dict:
    """
    Parse user's service request. Tries Cohere first, falls back to fast_parse.
    Always returns a dict with guaranteed keys including risk_score and sentiment.
    """
    if use_cohere and co is not None:
        try:
            prompt = INTENT_PROMPT.format(raw_input=raw_input)
            text   = _generate_with_retry(prompt)
            text   = re.sub(r'```(?:json)?\s*|\s*```', '', text).strip()
            result = json.loads(text)
            result.setdefault("risk_score", 0.0)
            result.setdefault("sentiment",  "neutral")
            result["agent"] = "IntentAgent"
            result["model"] = "command-r-plus"
            return result
        except Exception as exc:
            logger.warning("[IntentAgent] Cohere failed (%s) — fast_parse fallback", exc)
    elif use_cohere and co is None:
        logger.info("[IntentAgent] Cohere client not configured — fast_parse fallback")

    result          = fast_parse(raw_input)
    result["agent"] = "IntentAgent"
    result["model"] = "rule_based_v3"
    return result


# ── Tool Definition ────────────────────────────────────────────────────────────
TOOL_DEFINITION = {
    "name": "intent_agent",
    "description": (
        "Parses multilingual service requests (Urdu, Roman Urdu, English, mixed code-switch) "
        "and extracts structured intent: service type, area, urgency, time/date preference, "
        "budget sensitivity, job complexity, confidence score, risk score, and sentiment. "
        "Handles misspellings, Roman Urdu slang, and noisy input gracefully."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "raw_input":  {"type": "string",  "description": "User's raw service request in any language"},
            "use_cohere": {"type": "boolean", "description": "Use Cohere LLM (default true). Falls back to rule engine on failure."},
        },
        "required": ["raw_input"],
    },
}


# ── Self-Test ──────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    test_cases = [
        ("AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye, budget zyada nahi hai", "AC Repair"),
        ("Mujhe kal morning main AC service chahiye G-11 mein",                              "AC Repair"),
        ("bijli ka masla hai, switch nahi chal raha, F-10",                                  "Electrical"),
        ("I need an electrician urgently in F-10, wiring issue",                             "Electrical"),
        ("پانی کا پائپ لیک ہو رہا ہے، فوری ضرورت ہے",                                      "Plumbing"),
        ("Bhai plumber chahiye, pipe phoot gaya hai",                                        "Plumbing"),
        ("MDCAT ke liye tutor chahiye, chemistry aur biology G-13",                          "Tutoring"),
        ("ghar ki safai chahiye weekend pe",                                                 "Cleaning"),
        ("acond thek karwana hai urgent",                                                    "AC Repair"),
        ("bijly nahi chal rahi puri raat se",                                                "Electrical"),
    ]

    print("=" * 65)
    print("KaamYaab — Intent Agent v3 Test (Cohere + Bug Fixes)")
    print("=" * 65)
    passed = 0
    for inp, expected in test_cases:
        r  = run(inp, use_cohere=False)   # fast_parse only for self-test
        ok = "✅" if r["service_type"] == expected else "❌"
        if r["service_type"] == expected:
            passed += 1
        print(f"\n{ok} [{r['language']}] {inp[:55]}...")
        print(f"   Service: {r['service_type']} (expected {expected})")
        print(f"   Area: {r['area']} | Urgency: {r['urgency']} | Budget: {r['budget_sensitivity']}")
        print(f"   Confidence: {r['confidence']:.0%} | Complexity: {r['job_complexity']} | Risk: {r['risk_score']}")
        if r["clarification_needed"]:
            print(f"   ❓ {r['clarification_question']}")
    print(f"\n{'='*65}\nPassed {passed}/{len(test_cases)}")