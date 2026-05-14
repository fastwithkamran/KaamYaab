"""
KhidmatGaar — Intent Agent
Google Antigravity Orchestrator | Challenge 2

Extracts structured intent from multilingual user input
(Urdu, Roman Urdu, English, mixed/code-switched).
"""

import json
import logging
import os
import re
import time
import google.generativeai as genai

logger = logging.getLogger(__name__)
MAX_GEMINI_RETRIES = 3
MAX_BACKOFF_SECONDS = 4

_gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
model = None
if _gemini_api_key:
    genai.configure(api_key=_gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")

INTENT_PROMPT = """
You are the Intent Agent for KhidmatGaar, an AI service orchestrator for Pakistan's informal economy.

Parse this user request (may be Urdu, Roman Urdu, English, or mixed):
"{raw_input}"

Return ONLY a valid JSON object with these exact fields:
{{
  "service_type": "AC Repair | Plumbing | Electrical | Tutoring | Cleaning | Unknown",
  "location": "full location string",
  "area": "area code (G-13, F-10, etc.) or extracted area name",
  "urgency": "low | medium | high | emergency",
  "preferred_time": "morning | afternoon | evening | flexible | HH:MM",
  "preferred_date": "today | tomorrow | day_after | flexible | YYYY-MM-DD",
  "budget_sensitivity": 0.0,
  "confidence": 0.0,
  "language": "urdu | roman_urdu | english | mixed",
  "clarification_needed": false,
  "clarification_question": "",
  "issue_description": "brief description of the problem",
  "job_complexity": "basic | intermediate | complex"
}}

Rules:
- budget_sensitivity: 0.0=budget flexible, 1.0=very tight budget
- confidence: your certainty 0.0-1.0; if <0.75 set clarification_needed=true
- For Urdu keywords: "subah"=morning, "kal"=tomorrow, "urgent/jaldi"=high urgency
- "zyada nahi", "sasta", "budget tight" → budget_sensitivity > 0.7
- "bijli"=Electrical, "AC/ٹھنڈا"=AC Repair, "pani/pipe"=Plumbing, "safai"=Cleaning
"""

LANGUAGE_MAP = {
    "urdu":       r'[\u0600-\u06FF]',
    "roman_urdu": r'\b(hai|karo|chahiye|kal|subah|mein|nahi|bhai|thik|kaam)\b',
    "english":    r'\b(repair|fix|need|want|please|help|service|urgently)\b',
}

SERVICE_KEYWORDS = {
    "AC Repair":   ["ac", "air condition", "cooling", "ٹھنڈا", "ac kharab", "gas fill", "compressor"],
    "Plumbing":    ["pipe", "plumb", "leak", "pani", "پانی", "drain", "tap", "water"],
    "Electrical":  ["electric", "bijli", "بجلی", "wiring", "light", "switch", "mcb", "generator"],
    "Tutoring":    ["tutor", "teacher", "parhai", "parhana", "maths", "physics", "coaching", "class"],
    "Cleaning":    ["clean", "safai", "صفائی", "jhadu", "sweep", "mop", "home clean"],
}


def detect_language(text: str) -> str:
    if re.search(r'[\u0600-\u06FF]', text):
        if re.search(r'[a-zA-Z]', text):
            return "mixed"
        return "urdu"
    if re.search(r'\b(hai|karo|chahiye|kal|subah|mein|nahi|bhai|thik|kaam|mujhe|zyada)\b', text, re.I):
        return "roman_urdu"
    return "english"


def fast_parse(text: str) -> dict:
    """Rule-based fast parser as fallback when Gemini is unavailable."""
    lower = text.lower()
    
    service = "Unknown"
    for svc, keywords in SERVICE_KEYWORDS.items():
        if any(k in lower for k in keywords):
            service = svc
            break

    urgency = "medium"
    if any(w in lower for w in ["urgent", "emergency", "abhi", "jaldi", "فوری", "ابھی"]):
        urgency = "emergency" if "emergency" in lower else "high"
    elif any(w in lower for w in ["kal", "tomorrow", "next"]):
        urgency = "medium"
    else:
        urgency = "low"

    # Area detection
    area = "G-13"
    area_patterns = {"G-13": "g-13", "G-11": "g-11", "G-14": "g-14", "F-10": "f-10",
                     "F-11": "f-11", "G-15": "g-15", "I-8": "i-8", "E-11": "e-11"}
    for a, pattern in area_patterns.items():
        if pattern in lower or a.lower() in lower:
            area = a
            break

    budget = 0.5
    if any(w in lower for w in ["budget", "sasta", "kam paise", "zyada nahi", "affordable", "cheap", "ارزاں"]):
        budget = 0.8

    preferred_time = "flexible"
    if any(w in lower for w in ["subah", "morning", "صبح"]):
        preferred_time = "morning"
    elif any(w in lower for w in ["afternoon", "dopahar", "دوپہر"]):
        preferred_time = "afternoon"
    elif any(w in lower for w in ["evening", "shaam", "شام"]):
        preferred_time = "evening"

    preferred_date = "flexible"
    if any(w in lower for w in ["aaj", "today", "آج"]):
        preferred_date = "today"
    elif any(w in lower for w in ["kal", "tomorrow"]):
        preferred_date = "tomorrow"

    confidence = 0.91 if service != "Unknown" else 0.58
    if preferred_time == "flexible":
        confidence = max(0.75, confidence - 0.05) if service != "Unknown" else confidence
    lang = detect_language(text)
    complexity = "basic"
    if any(w in lower for w in ["install", "wiring", "replace", "compressor", "overhaul", "rewire"]):
        complexity = "complex"
    elif any(w in lower for w in ["gas", "diagnose", "repair", "service", "leak"]):
        complexity = "intermediate"

    return {
        "service_type": service,
        "location": "Islamabad",
        "area": area,
        "urgency": urgency,
        "preferred_time": preferred_time,
        "preferred_date": preferred_date,
        "budget_sensitivity": budget,
        "confidence": confidence,
        "language": lang,
        "clarification_needed": service == "Unknown" or confidence < 0.75,
        "clarification_question": (
            "Ap kis service ki zaroorat hai? "
            "(AC Repair, Plumbing, Electrical, Tutoring, ya Cleaning)"
            if service == "Unknown" else ""
        ),
        "issue_description": text[:120],
        "job_complexity": complexity,
    }


def run(raw_input: str, use_gemini: bool = True) -> dict:
    """
    Main entry point for the Intent Agent.
    Returns structured intent with confidence score.
    """
    if use_gemini and model is not None:
        try:
            prompt = INTENT_PROMPT.format(raw_input=raw_input)
            response = _generate_with_retry(
                prompt
            )
            text = response.text.strip()
            # Strip markdown fences if present
            text = re.sub(r'```json\s*|\s*```', '', text).strip()
            result = json.loads(text)
            result["agent"] = "IntentAgent"
            result["model"] = "gemini-1.5-flash"
            return result
        except Exception as e:
            logger.warning("[IntentAgent] Gemini failed: %s — using fast_parse fallback", e)
    elif use_gemini and model is None:
        logger.info("[IntentAgent] GEMINI_API_KEY not set — using fast_parse fallback")

    result = fast_parse(raw_input)
    result["agent"] = "IntentAgent"
    result["model"] = "rule_based_fallback"
    return result


def _generate_with_retry(prompt: str):
    last_error = None
    for retry in range(0, MAX_GEMINI_RETRIES + 1):
        try:
            return model.generate_content(
                prompt,
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    max_output_tokens=512,
                )
            )
        except Exception as e:
            last_error = e
            msg = str(e).lower()
            is_rate_limited = "429" in msg or "rate" in msg or "quota" in msg
            if retry == MAX_GEMINI_RETRIES or not is_rate_limited:
                break
            time.sleep(min(MAX_BACKOFF_SECONDS, 2 ** retry))
    raise last_error


# ── Antigravity Tool Definition ──────────────────────────────────────────────
TOOL_DEFINITION = {
    "name": "intent_agent",
    "description": (
        "Parses multilingual service requests (Urdu, Roman Urdu, English, mixed) "
        "and extracts structured intent: service type, location, area, urgency, "
        "time preference, budget sensitivity, and confidence score."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "raw_input": {
                "type": "string",
                "description": "The user's raw service request in any language"
            },
            "use_gemini": {
                "type": "boolean",
                "description": "Whether to use Gemini for parsing (default: true). Falls back to rule-based if false or on error."
            }
        },
        "required": ["raw_input"]
    }
}


if __name__ == "__main__":
    # ── Test Cases ───────────────────────────────────────────────────────────
    test_inputs = [
        "AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye, budget zyada nahi hai",
        "Mujhe kal morning main AC service chahiye G-11 mein",
        "bijli ka masla hai, switch nahi chal raha",
        "I need an electrician urgently in F-10, wiring issue",
        "پانی کا پائپ لیک ہو رہا ہے، فوری ضرورت ہے",
        "Bhai plumber chahiye, pipe phoot gaya hai",
        "MDCAT ke liye tutor chahiye, chemistry aur biology",
        "ghar ki safai chahiye weekend pe",
        "acond thek karwana hai urgent",  # misspelled
    ]

    print("=" * 60)
    print("KhidmatGaar — Intent Agent Test Results")
    print("=" * 60)
    for inp in test_inputs:
        result = run(inp, use_gemini=False)  # use fast_parse for test
        print(f"\nInput: {inp[:60]}...")
        print(f"  Service: {result['service_type']}")
        print(f"  Area: {result['area']} | Urgency: {result['urgency']}")
        print(f"  Confidence: {result['confidence']:.0%} | Language: {result['language']}")
        print(f"  Clarification needed: {result['clarification_needed']}")
        if result['clarification_needed']:
            print(f"  Question: {result['clarification_question']}")
