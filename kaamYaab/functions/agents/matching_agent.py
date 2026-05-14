"""
KhidmatGaar — Matching Agent
Google Antigravity Orchestrator | Challenge 2

8-factor DNA scoring algorithm for provider ranking.
Produces transparent rationale for every ranking decision.
"""

import json
import math
from typing import List, Dict, Any


# ── DNA Score Weights ────────────────────────────────────────────────────────
WEIGHTS = {
    "on_time_reliability":   0.25,
    "review_recency":        0.20,
    "job_completion_rate":   0.15,
    "skill_specialization":  0.15,
    "cancellation_risk":     0.10,
    "price_fairness":        0.08,
    "dispute_history":       0.05,
    "surge_acceptance":      0.02,
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

    # Factor 1: On-Time Reliability (25%)
    on_time = p.get("on_time_rate", 0.8)
    breakdown["on_time_reliability"] = round(on_time * WEIGHTS["on_time_reliability"] * 100, 2)
    if on_time >= 0.95:
        rationale_parts.append(f"{int(on_time*100)}% on-time arrival rate")
    elif on_time < 0.75:
        warnings.append(f"⚠ Low on-time rate: {int(on_time*100)}%")

    # Factor 2: Review Recency (20%)
    review_count = p.get("review_count", 0)
    recency_score = min(1.0, review_count / 300.0)
    breakdown["review_recency"] = round(recency_score * WEIGHTS["review_recency"] * 100, 2)
    if review_count >= 200:
        rationale_parts.append(f"{review_count} verified reviews")

    # Factor 3: Job Completion Rate (15%)
    total = p.get("total_jobs", 1)
    completed = p.get("completed_jobs", 0)
    completion = completed / total if total > 0 else 0
    breakdown["job_completion_rate"] = round(completion * WEIGHTS["job_completion_rate"] * 100, 2)
    if completion >= 0.95:
        rationale_parts.append(f"{int(completion*100)}% completion rate")

    # Factor 4: Skill Specialization Match (15%)
    skills = p.get("skills", [])
    exp_level = p.get("experience_level", "basic")
    skill_score = COMPLEXITY_MAP.get(exp_level, 0.6)
    # Bonus for many skills
    if len(skills) >= 4:
        skill_score = min(1.0, skill_score + 0.1)
    breakdown["skill_specialization"] = round(skill_score * WEIGHTS["skill_specialization"] * 100, 2)
    if exp_level == "complex":
        rationale_parts.append("complex-level specialist")

    # Factor 5: Cancellation Risk (10%) — lower cancellation = higher score
    cancel_rate = p.get("cancellation_rate", 0.1)
    no_cancel_score = 1.0 - cancel_rate
    breakdown["cancellation_risk"] = round(no_cancel_score * WEIGHTS["cancellation_risk"] * 100, 2)
    if cancel_rate > 0.12:
        warnings.append(f"⚠ {int(cancel_rate*100)}% cancellation rate")
    elif cancel_rate <= 0.03:
        rationale_parts.append("very low cancellation risk")

    # Factor 6: Price Fairness (8%)
    fairness = p.get("price_fairness_score", 0.8)
    breakdown["price_fairness"] = round(fairness * WEIGHTS["price_fairness"] * 100, 2)
    if fairness >= 0.92:
        rationale_parts.append("consistently fair pricing")

    # Factor 7: Dispute History (5%) — fewer disputes = higher score
    disputes = p.get("dispute_count", 0)
    disp_score = max(0.0, 1.0 - (disputes / 15.0))
    breakdown["dispute_history"] = round(disp_score * WEIGHTS["dispute_history"] * 100, 2)
    if disputes == 0:
        rationale_parts.append("zero dispute history")
    elif disputes > 5:
        warnings.append(f"⚠ {disputes} past disputes")

    # Factor 8: Surge Acceptance (2%)
    surge_acceptor = p.get("surge_acceptor", False)
    surge_bonus = 1.0 if (surge_mult > 1.2 and surge_acceptor) else 0.0
    breakdown["surge_acceptance"] = round(surge_bonus * WEIGHTS["surge_acceptance"] * 100, 2)
    if surge_bonus > 0:
        rationale_parts.append("surge-ready provider")

    raw_total = sum(breakdown.values())

    # Verification bonus
    if p.get("is_verified", False):
        raw_total = min(100, raw_total + 2)
        rationale_parts.append("verified identity")

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
    budget_sensitivity = intent.get("budget_sensitivity", 0.5)

    # Urgency adjustment
    urgency_adj = 0
    if urgency == "emergency":
        urgency_adj = base * 0.30
    elif urgency == "high":
        urgency_adj = base * 0.15

    # Distance cost
    dist_cost = round(dist_km * 50)

    # Surge adjustment
    surge_adj = round((base + urgency_adj) * (surge_mult - 1.0))

    # Loyalty discount (simulate: 0 for new user)
    loyalty_discount = 0

    total = base + urgency_adj + dist_cost + surge_adj - loyalty_discount

    return {
        "base_pkr": base,
        "urgency_adj_pkr": round(urgency_adj),
        "distance_cost_pkr": dist_cost,
        "surge_adj_pkr": surge_adj,
        "surge_multiplier": surge_mult,
        "loyalty_discount_pkr": loyalty_discount,
        "total_pkr": round(total),
        "is_negotiable": budget_sensitivity > 0.6,
        "breakdown_text": (
            f"Base Rs.{base} + Urgency Rs.{round(urgency_adj)} + "
            f"Distance Rs.{dist_cost} + Surge Rs.{surge_adj}"
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

    # Step 1: Filter by service category
    filtered = [p for p in providers if p.get("service_category") == service_type]

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

        dna = compute_dna_score(p, intent, surge_mult)
        quote = calculate_quote(p, intent, dist, surge_mult)

        # Distance penalty: deduct 0.5 per km beyond 3km
        dist_penalty = max(0, (dist - 3) * 0.5)
        final_score = max(0, dna["dna_score_computed"] - dist_penalty)

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
        "Ranks service providers using an 8-factor DNA Score algorithm. "
        "Factors: on-time reliability (25%), review recency (20%), job completion rate (15%), "
        "skill specialization (15%), cancellation risk (10%), price fairness (8%), "
        "dispute history (5%), surge acceptance (2%). "
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
