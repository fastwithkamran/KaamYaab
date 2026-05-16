"""
KaamYaab — Intent Agent  (v2 — Optimized)
Google Antigravity Orchestrator | Challenge 2

Extracts structured intent from multilingual user input
(Urdu, Roman Urdu, English, mixed/code-switched).

v2 improvements
───────────────
• Expanded SERVICE_KEYWORDS with phonetic / misspelled variants (acond, bijly, safaai…)
• Urgency detection is priority-ordered (emergency > high > medium > low)
• Budget sensitivity uses weighted keyword scoring instead of a single flag
• Confidence is computed from multiple signals: service found, area found, time found
• fast_parse now extracts area from a much richer city-area dictionary
• Clarification question is bilingual (Urdu + English)
• INTENT_PROMPT upgraded: instructs Gemini to return risk_score + sentiment
"""

import json
import logging
import os
import re
import time
from typing import Optional

try:
    import google.generativeai as genai
except ImportError:          # pragma: no cover
    genai = None

logger = logging.getLogger(__name__)

MAX_GEMINI_RETRIES   = 3
MAX_BACKOFF_SECONDS  = 4

_gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
model: Optional[object] = None
if _gemini_api_key and genai is not None:
    genai.configure(api_key=_gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")
elif _gemini_api_key and genai is None:
    logger.info("[IntentAgent] google.generativeai not installed — fast_parse fallback active")

# ── Gemini Prompt ─────────────────────────────────────────────────────────────
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

# ── Language Detection ────────────────────────────────────────────────────────
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

# ── Urgency Keywords (priority-ordered: higher index = higher urgency) ────────
URGENCY_TIERS = [
    (["emergency", "foori", "فوری", "fire", "flood", "gas leak", "bijli ka shock"],          "emergency"),
    (["urgent", "abhi", "ابھی", "jaldi", "jaldee", "foran", "immediately", "asap"],          "high"),
    (["aaj", "today", "آج", "same day", "within hours"],                                       "high"),
    (["kal", "tomorrow", "اگلا"],                                                               "medium"),
    (["weekend", "next week", "baad mein", "flexible", "whenever"],                            "low"),
]

# ── Budget Keywords ───────────────────────────────────────────────────────────
BUDGET_KEYWORDS = {
    "very_tight": ["bilkul nahi", "bohot kam", "zyada afford nahi", "barely"],
    "tight":      ["zyada nahi", "sasta", "kam paise", "budget tight", "cheap", "affordable",
                   "ارزاں", "save", "discounted"],
    "moderate":   ["reasonable", "fair price", "market rate", "theek thak"],
}

# ── Complexity Keywords ───────────────────────────────────────────────────────
COMPLEXITY_HIGH  = {"install", "installation", "wiring", "replace", "compressor",
                    "overhaul", "rewire", "complete", "full service", "replace"}
COMPLEXITY_MED   = {"gas", "diagnose", "repair", "service", "leak", "fix", "refill",
                    "check", "tuneup", "tune-up", "cleaning"}


# ── Helpers ───────────────────────────────────────────────────────────────────

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
            return candidate if candidate in AREA_COORDS else candidate
    return "Unknown"


def _detect_service(lower: str) -> str:
    for svc, keywords in SERVICE_KEYWORDS.items():
        if any(k in lower for k in keywords):
            return svc
    return "Unknown"


def _detect_urgency(lower: str) -> str:
    for keywords, level in URGENCY_TIERS:
        if any(k in lower for k in keywords):
            return level
    return "medium"


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
    # HH:MM pattern
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
    score = 0.70  # base
    if service != "Unknown":
        score += 0.15
    if area != "Unknown":
        score += 0.10
    if time_pref != "flexible":
        score += 0.05
    # Penalise ambiguous language detection
    if lang == "mixed":
        score -= 0.03
    return round(min(score, 0.98), 2)


# ── Fast Rule-Based Parser ────────────────────────────────────────────────────

def fast_parse(text: str) -> dict:
    """Deterministic rule-based parser. Used when Gemini is unavailable."""
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

    # Risk score: high if ambiguous + emergency + budget tight
    risk = 0.0
    if service == "Unknown":
        risk += 0.30
    if area == "Unknown":
        risk += 0.20
    if urgency == "emergency" and budget >= 0.75:
        risk += 0.25
    risk = round(min(risk, 1.0), 2)

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
        "sentiment":              "frustrated" if urgency in ("emergency", "high") else "neutral",
    }


# ── Gemini Call with Retry ────────────────────────────────────────────────────

def _generate_with_retry(prompt: str):
    last_error = None
    for attempt in range(MAX_GEMINI_RETRIES + 1):
        try:
            return model.generate_content(
                prompt,
                generation_config=genai.GenerationConfig(
                    temperature=0.05,       # Near-deterministic for structured output
                    max_output_tokens=600,
                ),
            )
        except Exception as exc:
            last_error = exc
            msg = str(exc).lower()
            retriable = any(x in msg for x in ("429", "rate", "quota", "unavailable"))
            if attempt == MAX_GEMINI_RETRIES or not retriable:
                break
            time.sleep(min(MAX_BACKOFF_SECONDS, 2 ** attempt))
    raise last_error


# ── Main Entry Point ──────────────────────────────────────────────────────────

def run(raw_input: str, use_gemini: bool = True) -> dict:
    """
    Parse user's service request. Tries Gemini first, falls back to fast_parse.
    Always returns a dict with guaranteed keys including risk_score and sentiment.
    """
    if use_gemini and model is not None:
        try:
            prompt   = INTENT_PROMPT.format(raw_input=raw_input)
            response = _generate_with_retry(prompt)
            text     = response.text.strip()
            text     = re.sub(r'```(?:json)?\s*|\s*```', '', text).strip()
            result   = json.loads(text)
            # Ensure all keys exist (Gemini may omit optional fields)
            result.setdefault("risk_score", 0.0)
            result.setdefault("sentiment",  "neutral")
            result["agent"] = "IntentAgent"
            result["model"] = "gemini-1.5-flash"
            return result
        except Exception as exc:
            logger.warning("[IntentAgent] Gemini failed (%s) — fast_parse fallback", exc)
    elif use_gemini and model is None:
        logger.info("[IntentAgent] GEMINI_API_KEY not set — fast_parse fallback")

    result          = fast_parse(raw_input)
    result["agent"] = "IntentAgent"
    result["model"] = "rule_based_v2"
    return result


# ── Antigravity Tool Definition ──────────────────────────────────────────────
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
            "raw_input":   {"type": "string",  "description": "User's raw service request in any language"},
            "use_gemini":  {"type": "boolean", "description": "Use Gemini LLM (default true). Falls back to rule engine on failure."},
        },
        "required": ["raw_input"],
    },
}


# ── Self-Test ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    test_cases = [
        # (input,                                                     expected_service)
        ("AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye, budget zyada nahi hai", "AC Repair"),
        ("Mujhe kal morning main AC service chahiye G-11 mein",                              "AC Repair"),
        ("bijli ka masla hai, switch nahi chal raha, F-10",                                  "Electrical"),
        ("I need an electrician urgently in F-10, wiring issue",                             "Electrical"),
        ("پانی کا پائپ لیک ہو رہا ہے، فوری ضرورت ہے",                                      "Plumbing"),
        ("Bhai plumber chahiye, pipe phoot gaya hai",                                        "Plumbing"),
        ("MDCAT ke liye tutor chahiye, chemistry aur biology G-13",                          "Tutoring"),
        ("ghar ki safai chahiye weekend pe",                                                 "Cleaning"),
        ("acond thek karwana hai urgent",                                                    "AC Repair"),   # misspelled
        ("bijly nahi chal rahi puri raat se",                                                "Electrical"),  # misspelled
    ]

    print("=" * 65)
    print("KaamYaab — Intent Agent v2 Test")
    print("=" * 65)
    passed = 0
    for inp, expected in test_cases:
        r = run(inp, use_gemini=False)
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
