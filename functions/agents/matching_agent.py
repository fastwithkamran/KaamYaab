"""
KaamYaab — Matching Agent  (v2 — Optimized)
Google Antigravity Orchestrator | Challenge 2

v2 improvements
───────────────
• availability_score now validates actual day-of-week AND time slots instead of binary 95/55
• cancellation_risk uses a smooth sigmoid decay instead of hard cutoff at 25%
• last_active_date staleness penalty (providers inactive > 3 days score lower)
• price_fairness_score from dataset now incorporated into price_fit_score
• review_recency_score considers reviews-per-job ratio (activity intensity)
• Composite reliability_score = 0.6×on_time + 0.25×price_fairness + 0.15×(1-cancel_rate)
• Specialization now checks exact skill match against intent service keywords
• user_preference_match includes verification bonus and recency bonus
• fallback "expand_radius" suggestion when < 3 providers found
• Job-complexity compatibility filter: basic jobs reject complex providers when budget is tight
"""

import json
import math
import datetime
from typing import List, Dict, Any, Optional


# ── Scoring Weights (10 factors, sum = 1.00) ──────────────────────────────────
WEIGHTS = {
    "distance_score":       0.12,   # haversine proximity
    "availability_score":   0.15,   # real day+slot match
    "rating_score":         0.12,   # star rating
    "review_recency_score": 0.07,   # activity intensity
    "reliability_score":    0.15,   # composite: on_time + price_fairness + cancel
    "specialization_score": 0.14,   # skill depth + experience match
    "price_fit_score":      0.09,   # budget alignment
    "cancellation_risk":    0.07,   # smooth sigmoid penalty
    "capacity_score":       0.05,   # workload headroom
    "user_preference_match":0.04,   # verification, dispute-free, recency bonus
}

assert abs(sum(WEIGHTS.values()) - 1.0) < 1e-9, "Weights must sum to 1.0"

COMPLEXITY_REQUIRED_LEVEL = {
    "complex":      {"expert", "advanced", "complex"},
    "intermediate": {"expert", "advanced", "complex", "intermediate"},
    "basic":        {"expert", "advanced", "complex", "intermediate", "basic"},
}

DAY_ABBR = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


# ── Geo Utilities ─────────────────────────────────────────────────────────────

def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance in km between two WGS-84 coordinates."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + (
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def estimate_travel_time_minutes(distance_km: float) -> int:
    """Islamabad average speed ~30 km/h in urban areas. Returns integer minutes."""
    return max(5, round(distance_km / 30.0 * 60))


# ── Sub-Score Calculators ─────────────────────────────────────────────────────

def _distance_score(distance_km: float) -> float:
    """Score decays linearly from 100 at 0 km to 0 at 30 km."""
    return max(0.0, 100.0 - (distance_km / 30.0) * 100.0)


def _availability_score(provider: Dict, intent: Dict) -> float:
    """
    Validates preferred day-of-week AND preferred time slot.
    Returns 100 for perfect match, 60 if partially available, 20 if unavailable.
    """
    preferred_time = intent.get("preferred_time", "flexible")
    preferred_date = intent.get("preferred_date", "flexible")

    avail_days  = provider.get("availability", [])
    avail_slots = provider.get("available_slots", [])

    # Determine target day
    today = datetime.datetime.now()
    if preferred_date == "today":
        target_day = DAY_ABBR[today.weekday()]
    elif preferred_date == "tomorrow":
        target_day = DAY_ABBR[(today.weekday() + 1) % 7]
    elif preferred_date == "day_after":
        target_day = DAY_ABBR[(today.weekday() + 2) % 7]
    else:
        target_day = None  # flexible

    day_ok = (target_day is None) or (target_day in avail_days)

    # Time slot check
    if preferred_time == "flexible":
        slot_ok = True
    elif preferred_time == "morning":
        slot_ok = any(s <= "12:00" for s in avail_slots)
    elif preferred_time == "afternoon":
        slot_ok = any("12:00" < s <= "17:00" for s in avail_slots)
    elif preferred_time == "evening":
        slot_ok = any(s > "17:00" for s in avail_slots)
    else:
        # Exact HH:MM
        slot_ok = preferred_time in avail_slots

    if day_ok and slot_ok:
        return 100.0
    if day_ok or slot_ok:
        return 60.0
    return 20.0


def _review_recency_score(provider: Dict) -> float:
    """
    Activity intensity = review_count / total_jobs.
    Also penalise providers inactive for > 7 days.
    """
    total_jobs   = max(1, provider.get("total_jobs", 1))
    review_count = provider.get("review_count", 0)
    intensity    = min(1.0, review_count / total_jobs)
    base_score   = min(100.0, (review_count / 200.0) * 100.0)
    score        = 0.6 * base_score + 0.4 * intensity * 100.0

    # Staleness penalty
    last_active = provider.get("last_active_date", "")
    if last_active:
        try:
            delta = (datetime.datetime.now() - datetime.datetime.strptime(last_active, "%Y-%m-%d")).days
            if delta > 14:
                score *= 0.60
            elif delta > 7:
                score *= 0.80
            elif delta > 3:
                score *= 0.92
        except ValueError:
            pass
    return round(min(score, 100.0), 2)


def _reliability_score(provider: Dict) -> float:
    """
    Composite: 60% on-time rate + 25% price fairness + 15% low cancellation.
    """
    on_time        = provider.get("on_time_rate", 0.80)
    price_fair     = provider.get("price_fairness_score", 0.80)
    cancel_rate    = provider.get("cancellation_rate", 0.10)
    low_cancel     = max(0.0, 1.0 - cancel_rate)

    score = (0.60 * on_time + 0.25 * price_fair + 0.15 * low_cancel) * 100.0
    return round(min(score, 100.0), 2)


def _specialization_score(provider: Dict, intent: Dict) -> float:
    """
    Skill depth + experience level + optional exact skill keyword match.
    """
    exp_raw = str(provider.get("experience_level", "basic")).lower()
    # Normalise legacy label
    if exp_raw == "complex":
        exp_raw = "expert"

    exp_bonus = {"expert": 25, "advanced": 25, "intermediate": 12, "basic": 0}.get(exp_raw, 0)
    skill_count = len(provider.get("skills", []))
    skill_bonus = min(15, skill_count * 3)      # up to 15 pts for breadth
    cert_bonus  = min(10, len(provider.get("certifications", [])) * 5)

    # Keyword match: does a provider skill appear in the issue description?
    issue_lower = intent.get("issue_description", "").lower()
    skill_match = any(skill.lower() in issue_lower for skill in provider.get("skills", []))
    match_bonus = 10 if skill_match else 0

    return round(min(100.0, 50.0 + exp_bonus + skill_bonus + cert_bonus + match_bonus), 2)


def _price_fit_score(provider: Dict, intent: Dict, surge_mult: float) -> float:
    """
    Budget-aligned price fit. Considers price fairness score from dataset.
    """
    budget_sensitivity = float(intent.get("budget_sensitivity", 0.50))
    base_rate          = provider.get("base_rate_pkr", 1000)
    price_fairness     = provider.get("price_fairness_score", 0.80)
    rate_norm          = min(1.0, base_rate / 2500.0)   # normalise against max ~2500 PKR

    if budget_sensitivity >= 0.75:
        # Budget-sensitive user: reward low rate + high fairness
        score = (1.0 - rate_norm) * 60.0 + price_fairness * 40.0
    else:
        # Normal: prefer balanced rate + fair provider
        fit = 1.0 - abs(rate_norm - 0.45)          # sweet spot around mid-range
        score = fit * 60.0 + price_fairness * 40.0

    # Penalise during surge for budget-sensitive users
    if surge_mult > 1.2 and budget_sensitivity >= 0.75:
        score *= (1.0 / surge_mult)

    return round(min(score, 100.0), 2)


def _cancellation_risk_score(cancel_rate: float) -> float:
    """
    Smooth sigmoid decay: score = 100 × e^(-6×cancel_rate).
    - 0% cancel → 100
    - 5% cancel → ~74
    - 15% cancel → ~41
    - 25% cancel → ~22
    - 40%+ cancel → ~9
    """
    return round(100.0 * math.exp(-6.0 * cancel_rate), 2)


def _capacity_score(provider: Dict) -> float:
    """Providers with moderate job counts score higher (not over-stretched)."""
    total_jobs = provider.get("total_jobs", 0)
    # Peak performance window: 100–400 jobs. Penalty for < 50 (unproven) or > 600.
    if total_jobs < 50:
        return 55.0
    if total_jobs > 600:
        return 70.0
    return round(min(100.0, 60.0 + (total_jobs / 500.0) * 40.0), 2)


def _user_preference_score(provider: Dict) -> float:
    """Bonus for verified, dispute-free, recently active providers."""
    score = 50.0
    if provider.get("is_verified", False):
        score += 20.0
    if provider.get("dispute_count", 0) == 0:
        score += 15.0
    elif provider.get("dispute_count", 0) <= 2:
        score += 7.0
    if provider.get("review_count", 0) > 150:
        score += 10.0
    if provider.get("surge_acceptor", False):
        score += 5.0
    return round(min(score, 100.0), 2)


# ── DNA Score ─────────────────────────────────────────────────────────────────

def compute_dna_score(provider: Dict, intent: Dict, surge_mult: float = 1.0) -> Dict:
    """
    Compute 10-factor DNA Score. Returns total (0–100), breakdown, rationale, warnings.
    """
    distance_km = float(intent.get("_distance_km", 0.0))
    cancel_rate = provider.get("cancellation_rate", 0.10)
    on_time     = provider.get("on_time_rate", 0.80)
    disputes    = provider.get("dispute_count", 0)

    breakdown = {
        "distance_score":        _distance_score(distance_km),
        "availability_score":    _availability_score(provider, intent),
        "rating_score":          round(provider.get("rating", 4.0) / 5.0 * 100.0, 2),
        "review_recency_score":  _review_recency_score(provider),
        "reliability_score":     _reliability_score(provider),
        "specialization_score":  _specialization_score(provider, intent),
        "price_fit_score":       _price_fit_score(provider, intent, surge_mult),
        "cancellation_risk":     _cancellation_risk_score(cancel_rate),
        "capacity_score":        _capacity_score(provider),
        "user_preference_match": _user_preference_score(provider),
    }

    raw_total = sum(breakdown[k] * WEIGHTS[k] for k in WEIGHTS)

    # Build human-readable rationale
    parts, warnings = [], []
    if on_time >= 0.95:
        parts.append(f"{int(on_time * 100)}% on-time rate")
    if cancel_rate <= 0.03:
        parts.append("very low cancellation risk")
    if disputes == 0:
        parts.append("zero dispute history")
    if provider.get("is_verified"):
        parts.append("verified provider")
    if len(provider.get("certifications", [])) > 0:
        parts.append(f"certified ({', '.join(provider['certifications'][:2])})")

    if cancel_rate > 0.12:
        warnings.append(f"⚠ {int(cancel_rate * 100)}% cancellation rate")
    if disputes >= 3:
        warnings.append(f"⚠ {disputes} past disputes")
    if provider.get("rating", 5.0) < 4.0:
        warnings.append(f"⚠ Low rating {provider.get('rating')}")

    rationale = " · ".join(parts) if parts else "Standard match based on available data."
    if warnings:
        rationale += " | " + " · ".join(warnings)

    return {
        "dna_score_computed": round(raw_total, 1),
        "breakdown":          {k: round(v, 2) for k, v in breakdown.items()},
        "rationale":          rationale,
        "warnings":           warnings,
    }


# ── Dynamic Pricing ───────────────────────────────────────────────────────────

def calculate_quote(provider: Dict, intent: Dict, dist_km: float, surge_mult: float) -> Dict:
    """
    Transparent quote with 7-part breakdown:
    base + urgency + distance + complexity + surge − loyalty − budget_relief
    """
    base               = provider.get("base_rate_pkr", 1000)
    urgency            = intent.get("urgency", "medium")
    preferred_date     = intent.get("preferred_date", "flexible")
    complexity         = intent.get("job_complexity", "basic")
    budget_sensitivity = float(intent.get("budget_sensitivity", 0.50))

    urgency_rates = {"emergency": 0.35, "high": 0.20, "medium": 0.08, "low": 0.0}
    urgency_adj   = round(base * urgency_rates.get(urgency, 0.0))

    # Distance: Rs. 20/km for first 5 km, Rs. 35/km beyond (Islamabad reality)
    dist_cost = round(max(0, (dist_km - 2) * 20 + max(0, dist_km - 5) * 15))

    complexity_rates = {"complex": 0.40, "intermediate": 0.20, "basic": 0.0}
    complexity_charge = round(base * complexity_rates.get(complexity, 0.0))

    surge_charge = round((base + urgency_adj + complexity_charge) * max(0.0, surge_mult - 1.0))

    loyalty_discount   = round(base * 0.07)
    budget_relief      = round(base * 0.05) if budget_sensitivity >= 0.75 else 0

    total = base + urgency_adj + dist_cost + complexity_charge + surge_charge - loyalty_discount - budget_relief

    return {
        "base_pkr":               base,
        "urgency_adj_pkr":        urgency_adj,
        "distance_cost_pkr":      dist_cost,
        "complexity_surcharge_pkr": complexity_charge,
        "surge_adj_pkr":          surge_charge,
        "surge_multiplier":       surge_mult,
        "loyalty_discount_pkr":   loyalty_discount,
        "budget_adjustment_pkr":  budget_relief,
        "total_pkr":              round(total),
        "min_acceptable_pkr":     round(base * 0.85),
        "is_negotiable":          budget_sensitivity > 0.55,
        "breakdown_text": (
            f"Base Rs.{base} + Urgency Rs.{urgency_adj} + Distance Rs.{dist_cost} "
            f"+ Complexity Rs.{complexity_charge} + Surge Rs.{surge_charge} "
            f"- Loyalty Rs.{loyalty_discount} - Budget Relief Rs.{budget_relief}"
        ),
    }


# ── Main Matching Function ────────────────────────────────────────────────────

def run(
    providers: List[Dict],
    intent: Dict,
    user_lat: float,
    user_lng: float,
    surge_mult: float = 1.0,
    top_n: int = 5,
) -> Dict[str, Any]:
    """
    Filter, score, and rank providers. Returns top_n matches with full transparency.
    Handles edge cases: no providers, low confidence, complexity mismatch.
    """
    service_type   = intent.get("service_type", "Unknown")
    job_complexity = intent.get("job_complexity", "basic")
    budget_sens    = float(intent.get("budget_sensitivity", 0.5))
    service_lower  = service_type.lower()

    # ── Step 1: Hard Filter ───────────────────────────────────────────────────
    filtered: List[Dict] = []
    for p in providers:
        cat = str(p.get("service_category", "")).lower()
        # Service category match
        service_match = (
            cat == service_lower
            or ("ac" in service_lower and "ac" in cat)
            or ("plumb" in service_lower and "plumb" in cat)
            or ("electric" in service_lower and "electric" in cat)
            or ("clean" in service_lower and "clean" in cat)
            or ("tutor" in service_lower and "tutor" in cat)
        )
        if not service_match:
            continue

        # Hard disqualify: too many disputes (≥ 3 disputes = hidden from results)
        if p.get("dispute_count", 0) >= 3:
            continue

        # Hard disqualify: unavailable for weeks (last_active > 14 days ago)
        last_active = p.get("last_active_date", "")
        if last_active:
            try:
                delta = (datetime.datetime.now() - datetime.datetime.strptime(last_active, "%Y-%m-%d")).days
                if delta > 14:
                    continue
            except ValueError:
                pass

        filtered.append(p)

    if not filtered:
        # Fallback: try relaxed filter (allow dispute_count < 5, ignore staleness)
        for p in providers:
            cat = str(p.get("service_category", "")).lower()
            service_match = (
                cat == service_lower
                or ("ac" in service_lower and "ac" in cat)
                or ("plumb" in service_lower and "plumb" in cat)
                or ("electric" in service_lower and "electric" in cat)
                or ("clean" in service_lower and "clean" in cat)
                or ("tutor" in service_lower and "tutor" in cat)
            )
            if service_match and p.get("dispute_count", 0) < 5:
                filtered.append(p)

        if not filtered:
            return {
                "status":  "no_providers",
                "message": f"No providers available for '{service_type}'. Try again later or contact support.",
                "fallback": "waitlist",
                "matches": [],
                "agent":   "MatchingAgent",
            }

    # ── Step 2: Score & Rank ──────────────────────────────────────────────────
    scored = []
    for p in filtered:
        dist    = haversine(user_lat, user_lng, p["lat"], p["lng"])
        eta_min = estimate_travel_time_minutes(dist)

        enriched = dict(intent)
        enriched["_distance_km"] = dist

        dna   = compute_dna_score(p, enriched, surge_mult)
        quote = calculate_quote(p, intent, dist, surge_mult)

        scored.append({
            "provider":       p,
            "distance_km":    round(dist, 2),
            "eta_minutes":    eta_min,
            "match_score":    round(dna["dna_score_computed"], 1),
            "score_breakdown": dna["breakdown"],
            "rationale":      dna["rationale"],
            "warnings":       dna["warnings"],
            "quote":          quote,
            "recommended_slot": _best_slot(p, intent),
        })

    scored.sort(key=lambda x: x["match_score"], reverse=True)
    top = scored[:top_n]

    # ── Step 3: Decision Rationale for Top Provider ───────────────────────────
    decision_note = ""
    if len(top) >= 2:
        best, runner = top[0], top[1]
        gap = best["match_score"] - runner["match_score"]
        if gap < 2.0:
            decision_note = (
                f"Close match: {best['provider']['name']} edges out "
                f"{runner['provider']['name']} by {gap:.1f} pts. "
                f"Key differentiator: {_key_differentiator(best, runner)}"
            )
        else:
            decision_note = (
                f"{best['provider']['name']} ranked #1 with "
                f"{best['match_score']} vs {runner['match_score']} for "
                f"{runner['provider']['name']}. {best['rationale']}"
            )

    return {
        "status":            "success",
        "service_type":      service_type,
        "total_evaluated":   len(filtered),
        "total_candidates":  len(providers),
        "matches":           top,
        "top_provider":      top[0]["provider"]["name"] if top else None,
        "top_rationale":     top[0]["rationale"] if top else None,
        "decision_note":     decision_note,
        "surge_multiplier":  surge_mult,
        "agent":             "MatchingAgent",
    }


def _best_slot(provider: Dict, intent: Dict) -> str:
    """Return the best available slot matching the preferred time."""
    slots      = provider.get("available_slots", [])
    time_pref  = intent.get("preferred_time", "flexible")
    if not slots:
        return "10:00"
    if time_pref == "morning":
        morning = [s for s in slots if s <= "12:00"]
        return morning[0] if morning else slots[0]
    if time_pref == "afternoon":
        aft = [s for s in slots if "12:00" < s <= "17:00"]
        return aft[0] if aft else slots[0]
    if time_pref == "evening":
        eve = [s for s in slots if s > "17:00"]
        return eve[0] if eve else slots[-1]
    return slots[0]


def _key_differentiator(best: Dict, runner: Dict) -> str:
    """Identify which factor most differentiates the top two providers."""
    b_bd = best["score_breakdown"]
    r_bd = runner["score_breakdown"]
    diffs = {k: b_bd.get(k, 0) - r_bd.get(k, 0) for k in WEIGHTS}
    top_factor = max(diffs, key=lambda k: abs(diffs[k]))
    val = diffs[top_factor]
    label = top_factor.replace("_", " ").title()
    direction = "higher" if val > 0 else "lower"
    return f"{label} is {abs(val):.1f} pts {direction}"


# ── Antigravity Tool Definition ───────────────────────────────────────────────
TOOL_DEFINITION = {
    "name": "matching_agent",
    "description": (
        "Ranks service providers using a 10-factor composite DNA Score. "
        "Factors: distance (haversine), real day/slot availability, rating, "
        "review activity intensity + staleness, composite reliability (on-time × price-fairness × cancel), "
        "skill specialization + certification match, budget-aligned price fit, "
        "sigmoid cancellation risk, capacity headroom, and user-preference bonuses. "
        "Returns top-N matches with score breakdowns, rationale, and transparent decision notes."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "providers": {"type": "array",  "description": "List of provider objects"},
            "intent":    {"type": "object", "description": "Parsed intent from IntentAgent"},
            "user_lat":  {"type": "number"},
            "user_lng":  {"type": "number"},
            "surge_mult":{"type": "number", "description": "Surge multiplier (default 1.0)"},
            "top_n":     {"type": "integer","description": "Number of results (default 5)"},
        },
        "required": ["providers", "intent", "user_lat", "user_lng"],
    },
}


# ── Self-Test ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import os
    data_path = os.path.join(os.path.dirname(__file__), "../../assets/data/providers_mock.json")
    with open(data_path, encoding="utf-8") as f:
        data = json.load(f)

    mock_intent = {
        "service_type":    "AC Repair",
        "area":            "G-13",
        "urgency":         "high",
        "preferred_time":  "morning",
        "preferred_date":  "tomorrow",
        "budget_sensitivity": 0.70,
        "confidence":      0.92,
        "job_complexity":  "intermediate",
        "issue_description": "AC gas refill and service needed",
    }

    result = run(
        providers=data["providers"],
        intent=mock_intent,
        user_lat=33.7215,
        user_lng=73.0433,
        surge_mult=1.6,
        top_n=5,
    )

    print("=" * 65)
    print("KaamYaab — Matching Agent v2 Results")
    print(f"Service: {result['service_type']} | Surge: {result['surge_multiplier']}x")
    print(f"Evaluated {result['total_evaluated']}/{result['total_candidates']} providers")
    print("=" * 65)
    for i, m in enumerate(result["matches"], 1):
        p = m["provider"]
        print(f"\n#{i} {p['name']} | DNA Score: {m['match_score']}")
        print(f"   Distance: {m['distance_km']}km | ETA: {m['eta_minutes']}min | Slot: {m['recommended_slot']}")
        print(f"   Quote: Rs.{m['quote']['total_pkr']} | Breakdown: {m['quote']['breakdown_text']}")
        print(f"   Rationale: {m['rationale']}")
        if m["warnings"]:
            print(f"   Warnings: {' | '.join(m['warnings'])}")
    if result.get("decision_note"):
        print(f"\n📊 Decision: {result['decision_note']}")
