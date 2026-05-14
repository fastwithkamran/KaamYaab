"""
KhidmatGaar — Matching Agent
Google Antigravity Orchestrator | Challenge 2

README-aligned 10-factor scoring algorithm for provider ranking.
Produces transparent rationale for every ranking decision.
"""

import json
import math
from typing import List, Dict, Any


# ── DNA Score Weights ────────────────────────────────────────────────────────
WEIGHTS = {
    "distance_score": 0.12,
    "availability_score": 0.15,
    "rating_score": 0.12,
    "review_recency_score": 0.08,
    "reliability_score": 0.14,
    "specialization_score": 0.15,
    "price_fit_score": 0.08,
    "cancellation_risk": 0.08,
    "capacity_score": 0.04,
    "user_preference_match": 0.04,
}

COMPLEXITY_MAP = {
    "basic":        0.6,
    "intermediate": 0.85,
    "complex":      1.0,
}


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance in km between two coordinates."""
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lng / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def compute_dna_score(provider: Dict, intent: Dict, surge_mult: float = 1.0) -> Dict:
    """
    Compute the 8-factor DNA Score for a provider given intent context.
    Returns score breakdown, total score (0-100), and human-readable rationale.
    """
    p = provider
    breakdown = {}
    rationale_parts = []
    warnings = []

    distance_km = intent.get("_distance_km", 0.0)
    preferred_time = intent.get("preferred_time", "flexible")
    budget_sensitivity = float(intent.get("budget_sensitivity", 0.5))
    review_count = p.get("review_count", 0)
    cancel_rate = p.get("cancellation_rate", 0.1)
    disputes = p.get("dispute_count", 0)
    rating = p.get("rating", 4.0)
    on_time = p.get("on_time_rate", 0.8)

    distance_score = 100 if distance_km <= 5 else max(0, 100 - ((distance_km - 5) / 25.0) * 100)
    availability_score = 95 if preferred_time == "flexible" else 55
    rating_score = max(0, min(100, (rating / 5.0) * 100))
    review_recency_score = min(100, (review_count / 200.0) * 100)
    reliability_score = max(0, min(100, on_time * 100))
    exp_level = str(p.get("experience_level", "")).lower()
    if exp_level == "complex":
        exp_level = "advanced"  # legacy data normalization
    if exp_level in {"expert", "advanced"}:
        specialization_bonus = 20
    elif exp_level == "intermediate":
        specialization_bonus = 10
    else:
        specialization_bonus = 0
    specialization_score = 70 + specialization_bonus
    specialization_score += 10 if len(p.get("skills", [])) >= 4 else 0
    specialization_score = min(100, specialization_score)
    rate_norm = min(1.0, p.get("base_rate_pkr", 1000) / 2000.0)
    price_fit_score = (1 - rate_norm) * 100 if budget_sensitivity >= 0.75 else (0.6 + (1 - abs(rate_norm - 0.5))) * 62.5
    cancellation_score = 0 if cancel_rate >= 0.25 else max(0, min(100, (1 - cancel_rate) * 100))
    total_jobs = p.get("total_jobs", 0)
    capacity_score = max(60, 100 - min(1.0, total_jobs / 500.0) * 40)
    user_pref_score = 50 + (15 if disputes == 0 else 0) + (10 if review_count > 120 else 0)
    user_pref_score = min(100, user_pref_score)

    breakdown["distance_score"] = round(distance_score, 2)
    breakdown["availability_score"] = round(availability_score, 2)
    breakdown["rating_score"] = round(rating_score, 2)
    breakdown["review_recency_score"] = round(review_recency_score, 2)
    breakdown["reliability_score"] = round(reliability_score, 2)
    breakdown["specialization_score"] = round(specialization_score, 2)
    breakdown["price_fit_score"] = round(price_fit_score, 2)
    breakdown["cancellation_risk"] = round(cancellation_score, 2)
    breakdown["capacity_score"] = round(capacity_score, 2)
    breakdown["user_preference_match"] = round(user_pref_score, 2)

    if on_time >= 0.95:
        rationale_parts.append(f"{int(on_time * 100)}% on-time arrival rate")
    if cancel_rate <= 0.03:
        rationale_parts.append("very low cancellation risk")
    if disputes == 0:
        rationale_parts.append("zero dispute history")
    if p.get("is_verified", False):
        rationale_parts.append("verified identity")
    if cancel_rate > 0.12:
        warnings.append(f"⚠ {int(cancel_rate * 100)}% cancellation rate")

    raw_total = sum(breakdown[k] * WEIGHTS[k] for k in WEIGHTS)

    rationale = " · ".join(rationale_parts)
    if warnings:
        rationale += " | " + " · ".join(warnings)

    return {
        "dna_score_computed": round(raw_total, 1),
        "breakdown": breakdown,
        "rationale": rationale if rationale else "Standard match based on available data.",
        "warnings": warnings,
    }


def calculate_quote(provider: Dict, intent: Dict, dist_km: float, surge_mult: float) -> Dict:
    """Generate dynamic price quote with transparent breakdown."""
    base = provider.get("base_rate_pkr", 1000)
    urgency = intent.get("urgency", "medium")
    preferred_date = intent.get("preferred_date", "flexible")
    preferred_time = intent.get("preferred_time", "flexible")
    complexity = intent.get("job_complexity", "basic")
    budget_sensitivity = intent.get("budget_sensitivity", 0.5)
    distance_charge = max(0, (dist_km - 5) * 15)
    if complexity == "complex":
        complexity_rate = 0.4
    elif complexity == "intermediate":
        complexity_rate = 0.2
    else:
        complexity_rate = 0.0
    complexity_surcharge = base * complexity_rate

    if preferred_date == "today" or urgency == "emergency":
        urgency_adj = base * 0.25
    elif preferred_date == "tomorrow" and preferred_time == "morning":
        urgency_adj = base * 0.10
    else:
        urgency_adj = 0
    demand_rate = max(0, min(0.35, surge_mult - 1.0))
    demand_surge = (base + distance_charge + complexity_surcharge + urgency_adj) * demand_rate
    loyalty_discount = base * 0.05
    budget_adjustment = base * 0.05 if budget_sensitivity >= 0.75 else 0
    total = base + distance_charge + complexity_surcharge + urgency_adj + demand_surge - loyalty_discount - budget_adjustment

    return {
        "base_pkr": base,
        "urgency_adj_pkr": round(urgency_adj),
        "distance_cost_pkr": round(distance_charge),
        "complexity_surcharge_pkr": round(complexity_surcharge),
        "surge_adj_pkr": round(demand_surge),
        "surge_multiplier": surge_mult,
        "loyalty_discount_pkr": round(loyalty_discount),
        "budget_adjustment_pkr": round(budget_adjustment),
        "total_pkr": round(total),
        "is_negotiable": budget_sensitivity > 0.6,
        "breakdown_text": (
            f"Base Rs.{base} + Distance Rs.{round(distance_charge)} + "
            f"Complexity Rs.{round(complexity_surcharge)} + Urgency Rs.{round(urgency_adj)} + "
            f"Demand Rs.{round(demand_surge)} - Loyalty Rs.{round(loyalty_discount)} - "
            f"Budget Rs.{round(budget_adjustment)}"
        ),
    }


def run(
    providers: List[Dict],
    intent: Dict,
    user_lat: float,
    user_lng: float,
    surge_mult: float = 1.0,
    top_n: int = 5,
) -> Dict[str, Any]:
    """
    Main Matching Agent entry point.
    Filters, scores, and ranks providers. Returns top_n matches with full rationale.
    """
    service_type = intent.get("service_type", "Unknown")

    # Step 1: Filter by service category and policy override rules.
    filtered = []
    service_lower = service_type.lower()
    for p in providers:
        category = str(p.get("service_category", "")).lower()
        same_service = (
            category == service_lower or
            ("ac" in service_lower and "ac" in category) or
            ("plumb" in service_lower and "plumb" in category) or
            ("electric" in service_lower and "electric" in category) or
            ("clean" in service_lower and "clean" in category) or
            ("tutor" in service_lower and "tutor" in category)
        )
        if not same_service:
            continue
        if p.get("dispute_count", 0) >= 3:
            continue
        filtered.append(p)

    if not filtered:
        return {
            "status": "no_providers",
            "message": f"No providers found for '{service_type}'. Consider expanding search radius.",
            "fallback": "waitlist",
            "matches": [],
        }

    # Step 2: Score each provider
    scored = []
    for p in filtered:
        dist = haversine(user_lat, user_lng, p["lat"], p["lng"])
        eta = round(dist * 6)  # ~6 min/km in city

        enriched_intent = dict(intent)
        enriched_intent["_distance_km"] = dist
        dna = compute_dna_score(p, enriched_intent, surge_mult)
        quote = calculate_quote(p, intent, dist, surge_mult)

        final_score = max(0, dna["dna_score_computed"])

        scored.append({
            "provider": p,
            "distance_km": round(dist, 2),
            "eta_minutes": eta,
            "match_score": round(final_score, 1),
            "dna_computed": dna["dna_score_computed"],
            "score_breakdown": dna["breakdown"],
            "rationale": dna["rationale"],
            "warnings": dna["warnings"],
            "quote": quote,
            "recommended_slot": p.get("available_slots", ["10:00"])[0],
        })

    # Step 3: Sort by match_score descending
    scored.sort(key=lambda x: x["match_score"], reverse=True)
    top = scored[:top_n]

    return {
        "status": "success",
        "service_type": service_type,
        "total_evaluated": len(filtered),
        "matches": top,
        "top_provider": top[0]["provider"]["name"] if top else None,
        "top_rationale": top[0]["rationale"] if top else None,
        "agent": "MatchingAgent",
        "surge_multiplier": surge_mult,
    }


# ── Antigravity Tool Definition ──────────────────────────────────────────────
TOOL_DEFINITION = {
    "name": "matching_agent",
        "description": (
        "Ranks service providers using a 10-factor composite matching algorithm. "
        "Factors: distance, availability, rating, review recency, reliability, specialization, "
        "price fit, cancellation risk, capacity, and user preference match. "
        "Returns top-N ranked matches with score breakdown and human-readable rationale."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "providers": {"type": "array", "description": "List of provider objects from the dataset"},
            "intent": {"type": "object", "description": "Parsed intent from the Intent Agent"},
            "user_lat": {"type": "number"},
            "user_lng": {"type": "number"},
            "surge_mult": {"type": "number", "description": "Current surge multiplier (default 1.0)"},
            "top_n": {"type": "integer", "description": "Number of top matches to return (default 5)"},
        },
        "required": ["providers", "intent", "user_lat", "user_lng"]
    }
}


if __name__ == "__main__":
    # Load mock data for testing
    import os
    data_path = os.path.join(os.path.dirname(__file__), "../../assets/data/providers_mock.json")
    with open(data_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    mock_intent = {
        "service_type": "AC Repair",
        "area": "G-13",
        "urgency": "high",
        "preferred_time": "morning",
        "budget_sensitivity": 0.7,
        "confidence": 0.92,
    }

    result = run(
        providers=data["providers"],
        intent=mock_intent,
        user_lat=33.7215,
        user_lng=73.0433,
        surge_mult=1.6,
        top_n=5,
    )

    print("=" * 60)
    print("KhidmatGaar — Matching Agent Results")
    print(f"Service: {result['service_type']} | Surge: {result['surge_multiplier']}x")
    print("=" * 60)
    for i, m in enumerate(result["matches"], 1):
        p = m["provider"]
        print(f"\n#{i} {p['name']} (DNA: {p['dna_score']}) — Match Score: {m['match_score']}")
        print(f"   Distance: {m['distance_km']}km | ETA: {m['eta_minutes']}min")
        print(f"   Quote: Rs. {m['quote']['total_pkr']}")
        print(f"   Rationale: {m['rationale']}")
        if m["warnings"]:
            print(f"   Warnings: {' | '.join(m['warnings'])}")
