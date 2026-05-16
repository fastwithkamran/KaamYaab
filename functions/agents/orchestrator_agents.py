"""
KaamYaab — Orchestrator Agents  (v2 — Optimized)
Google Antigravity Orchestrator | Challenge 2

Agents: SurgeAgent · PricingAgent · NegotiationAgent · SchedulingAgent · BookingAgent · DisputeAgent · ProviderOptimizationAgent

v2 improvements
───────────────
• SurgeAgent: provider-side load balancing, off-peak incentive, richer trend analysis
• PricingAgent: 5-tier urgency, per-km tiered distance, complexity multiplier, min-floor guard
• NegotiationAgent: multi-round counter-offer with surge awareness and loyalty tiers
• SchedulingAgent: same-day job count cap (max 6), smarter buffer = travel_time + 45 min
• BookingAgent: 7-step chain with Antigravity trace, en-route ETA, photo evidence step
• DisputeAgent: 5 dispute types, blacklist threshold, structured support ticket
• ProviderOptimizationAgent: workload balance, demand forecast, recommended slots (NEW)
"""

import json
import logging
import os
import uuid
import datetime
from typing import Dict, List, Any, Optional

try:
    import google.generativeai as genai
except ImportError:
    genai = None

logger = logging.getLogger(__name__)

_gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
model = None
if _gemini_api_key and genai is not None:
    genai.configure(api_key=_gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")


# ════════════════════════════════════════════════════════════════════════════
# SURGE AGENT
# ════════════════════════════════════════════════════════════════════════════

def surge_agent_run(
    demand_data: Dict,
    area: str,
    service: str,
    current_hour: int,
    available_providers: int,
) -> Dict:
    """
    Detects surge via demand/provider ratio.
    Adds provider load-balancing incentive and tiered multiplier.
    """
    zones = {z["area"]: z for z in demand_data.get("demand_zones", [])}
    zone  = zones.get(area, {})
    if not zone:
        return {"status": "no_data", "surge_multiplier": 1.0, "active": False, "agent": "SurgeAgent"}

    hourly    = zone.get("hourly_demand", {}).get(service, [0] * 24)
    threshold = zone.get("surge_threshold", {}).get(service, 10)
    current   = hourly[current_hour] if current_hour < len(hourly) else 0

    # Tiered surge multiplier
    ratio = current / max(available_providers, 1)
    if ratio >= 5:
        mult = min(2.5, 1.0 + (ratio - 1) * 0.30)
    elif ratio >= 3:
        mult = 1.0 + (ratio - 1) * 0.20
    elif ratio >= 2:
        mult = 1.0 + (ratio - 1) * 0.10
    else:
        mult = 1.0
    mult     = round(mult, 2)
    is_surge = mult > 1.1

    # Off-peak windows for user guidance
    off_peak = _find_off_peak(hourly, threshold)

    # Provider load-balancing: find which adjacent areas have low demand
    adj_areas = [z["area"] for z in demand_data.get("demand_zones", []) if z["area"] != area]
    overflow_area = adj_areas[0] if adj_areas else None

    provider_notification = None
    user_alert = None
    if is_surge:
        provider_notification = {
            "message":    f"🌊 Surge {mult}x in {area}! Accept {service} jobs to earn more.",
            "multiplier": mult,
            "area":       area,
            "load_balance_suggestion": f"Providers near {overflow_area} also needed" if overflow_area else None,
        }
        user_alert = {
            "title":        f"High Demand in {area}",
            "body":         f"{service} demand is {mult}x normal ({current} requests, {available_providers} providers). Book now to lock price.",
            "multiplier":   mult,
            "alternatives": f"Off-peak slots: {off_peak}",
            "tip":          "Booking for tomorrow morning avoids surge pricing.",
        }

    forecast = demand_data.get("forecast_next_24h", [])
    predicted = next((f for f in forecast if f["area"] == area and f["service"] == service), None)

    return {
        "status":                "success",
        "area":                  area,
        "service":               service,
        "current_demand":        current,
        "threshold":             threshold,
        "available_providers":   available_providers,
        "demand_ratio":          round(ratio, 2),
        "surge_multiplier":      mult,
        "active":                is_surge,
        "demand_trend":          _trend(hourly, current_hour),
        "off_peak_hours":        off_peak,
        "provider_notification": provider_notification,
        "user_alert":            user_alert,
        "forecast":              predicted,
        "agent":                 "SurgeAgent",
    }


def _find_off_peak(hourly: list, threshold: int) -> str:
    low = [h for h, d in enumerate(hourly) if 0 < d < threshold * 0.5]
    return ", ".join(f"{h:02d}:00" for h in low[:3]) if low else "No off-peak available today"


def _trend(hourly: list, hour: int) -> str:
    if hour < 1:
        return "rising"
    prev, curr = hourly[hour - 1], hourly[hour]
    if curr > prev * 1.25:
        return "rising_fast"
    if curr > prev:
        return "rising"
    if curr < prev * 0.75:
        return "falling_fast"
    if curr < prev:
        return "falling"
    return "stable"


# ════════════════════════════════════════════════════════════════════════════
# PRICING AGENT
# ════════════════════════════════════════════════════════════════════════════

_URGENCY_RATES  = {"emergency": 0.35, "high": 0.20, "medium": 0.08, "low": 0.0}
_COMPLEX_RATES  = {"complex": 0.40, "intermediate": 0.20, "basic": 0.0}


def pricing_agent_run(
    provider: Dict,
    intent: Dict,
    dist_km: float,
    surge_mult: float,
    is_repeat_customer: bool = False,
) -> Dict:
    """
    7-component transparent dynamic quote.
    Distance: Rs.20/km for first 5 km, Rs.35/km beyond.
    """
    base       = provider.get("base_rate_pkr", 1000)
    urgency    = intent.get("urgency", "medium")
    complexity = intent.get("job_complexity", "basic")
    budget     = float(intent.get("budget_sensitivity", 0.5))

    urgency_pkr    = round(base * _URGENCY_RATES.get(urgency, 0))
    dist_pkr       = round(min(dist_km, 5) * 20 + max(0, dist_km - 5) * 35)
    complex_pkr    = round(base * _COMPLEX_RATES.get(complexity, 0))
    surge_pkr      = round((base + urgency_pkr + complex_pkr) * max(0, surge_mult - 1.0))
    loyalty_pkr    = round(base * 0.07) if is_repeat_customer else 0
    budget_pkr     = round(base * 0.05) if budget >= 0.75 else 0
    total          = base + urgency_pkr + dist_pkr + complex_pkr + surge_pkr - loyalty_pkr - budget_pkr
    floor          = round(base * 0.80)   # provider hard floor
    total          = max(total, floor)

    return {
        "base_pkr":              base,
        "urgency_adj_pkr":       urgency_pkr,
        "distance_cost_pkr":     dist_pkr,
        "complexity_pkr":        complex_pkr,
        "surge_adj_pkr":         surge_pkr,
        "surge_multiplier":      surge_mult,
        "loyalty_discount_pkr":  loyalty_pkr,
        "budget_adjustment_pkr": budget_pkr,
        "total_pkr":             round(total),
        "min_acceptable_pkr":    floor,
        "is_negotiable":         budget > 0.55,
        "breakdown": (
            f"Base Rs.{base} + Urgency Rs.{urgency_pkr} + Distance Rs.{dist_pkr} "
            f"+ Complexity Rs.{complex_pkr} + Surge Rs.{surge_pkr}"
            + (f" - Loyalty Rs.{loyalty_pkr}" if loyalty_pkr else "")
            + (f" - Budget Relief Rs.{budget_pkr}" if budget_pkr else "")
        ),
        "agent": "PricingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# NEGOTIATION AGENT
# ════════════════════════════════════════════════════════════════════════════

def negotiation_agent_run(
    original_quote: float,
    user_offer: float,
    provider: Dict,
    intent: Dict,
    surge_mult: float,
    is_repeat_customer: bool,
    negotiation_round: int = 1,
) -> Dict:
    """
    Multi-round negotiation. Round 1 offers a counter; round 2+ is final.
    """
    budget_sens    = float(intent.get("budget_sensitivity", 0.5))
    loyalty_disc   = original_quote * (0.10 if is_repeat_customer else 0.0)
    surge_floor    = original_quote * (1.0 if surge_mult <= 1.2 else 0.90)
    floor          = max(original_quote * 0.80, surge_floor - loyalty_disc)

    if user_offer >= floor:
        return {
            "accepted":            True,
            "agreed_price_pkr":    round(user_offer),
            "counter_offer_pkr":   round(user_offer),
            "reasoning":           f"Offer accepted." + (f" Loyalty discount Rs.{round(loyalty_disc)} applied." if loyalty_disc else ""),
            "discount_applied_pkr": round(loyalty_disc),
            "is_final_offer":      True,
            "round":               negotiation_round,
            "agent":               "NegotiationAgent",
        }

    # Counter strategy
    if negotiation_round == 1:
        counter = round(floor * 1.03)   # slight buffer, room for round 2
        is_final = False
        reasoning = f"Provider's best offer is Rs.{counter}."
    else:
        counter  = round(floor)
        is_final = True
        reasoning = f"Final offer Rs.{counter}. Provider cannot go lower."

    if surge_mult > 1.2:
        reasoning += f" (Surge {surge_mult}x currently active.)"

    return {
        "accepted":            False,
        "agreed_price_pkr":    None,
        "counter_offer_pkr":   counter,
        "reasoning":           reasoning,
        "discount_applied_pkr": round(loyalty_disc),
        "is_final_offer":      is_final,
        "round":               negotiation_round,
        "agent":               "NegotiationAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# SCHEDULING AGENT
# ════════════════════════════════════════════════════════════════════════════

_booked_slots: Dict[str, List[str]] = {}   # provider_id → locked slots
_MAX_DAILY_JOBS = 6


def scheduling_agent_run(
    provider: Dict,
    requested_date: str,
    requested_time: str,
    eta_minutes: int,
) -> Dict:
    """
    Prevents double-booking, enforces travel+service buffer (45 min + ETA),
    caps daily jobs at 6, suggests alternates, manages waitlist.
    """
    pid    = provider["id"]
    booked = _booked_slots.get(pid, [])

    # Daily cap check
    if len(booked) >= _MAX_DAILY_JOBS:
        return {
            "status":            "daily_cap_reached",
            "message":           f"{provider['name']} has reached max {_MAX_DAILY_JOBS} jobs today.",
            "alternate_slots":   [],
            "waitlist_position": len(booked),
            "agent":             "SchedulingAgent",
        }

    # Direct conflict
    if requested_time in booked:
        alternates = [s for s in provider.get("available_slots", []) if s not in booked]
        return {
            "status":           "slot_taken",
            "requested_slot":   requested_time,
            "alternate_slots":  alternates[:3],
            "waitlist_position": len(booked),
            "message":          f"{requested_time} is taken. Alternatives: {', '.join(alternates[:3])}",
            "agent":            "SchedulingAgent",
        }

    # Travel buffer check: need ETA + 45 min service gap
    required_gap = eta_minutes + 45
    for existing in booked:
        try:
            ex_h, ex_m   = map(int, existing.split(":"))
            req_h, req_m = map(int, requested_time.split(":"))
            diff = abs((req_h * 60 + req_m) - (ex_h * 60 + ex_m))
            if diff < required_gap:
                alternates = [s for s in provider.get("available_slots", []) if s not in booked and s != requested_time]
                return {
                    "status":          "insufficient_buffer",
                    "message":         f"Need ≥{required_gap} min gap from {existing} slot. Alternatives: {', '.join(alternates[:3])}",
                    "alternate_slots": alternates[:3],
                    "agent":           "SchedulingAgent",
                }
        except ValueError:
            pass

    # Confirm booking
    _booked_slots.setdefault(pid, []).append(requested_time)
    booking_id = f"BK-{uuid.uuid4().hex[:8].upper()}"

    return {
        "status":               "confirmed",
        "booking_id":           booking_id,
        "provider_id":          pid,
        "provider_name":        provider["name"],
        "slot":                 requested_time,
        "date":                 requested_date,
        "travel_buffer_minutes": required_gap,
        "daily_jobs_booked":    len(_booked_slots[pid]),
        "message":              f"Slot {requested_time} on {requested_date} locked for {provider['name']}.",
        "agent":                "SchedulingAgent",
    }


def reschedule_on_cancellation(provider: Dict, cancelled_slot: str, affected_user: str) -> Dict:
    """Auto-reschedule when provider cancels — returns next available slot."""
    pid    = provider["id"]
    booked = _booked_slots.get(pid, [])
    if cancelled_slot in booked:
        booked.remove(cancelled_slot)
    alternates = [s for s in provider.get("available_slots", []) if s not in booked]
    new_slot   = alternates[0] if alternates else None
    return {
        "status":        "rescheduled" if new_slot else "no_slot_available",
        "cancelled_slot": cancelled_slot,
        "new_slot":       new_slot,
        "affected_user":  affected_user,
        "provider":       provider["name"],
        "message":        f"Rescheduled to {new_slot}" if new_slot else "No slots available. Refund initiated.",
        "agent":          "SchedulingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# BOOKING AGENT — 7-Step Chain
# ════════════════════════════════════════════════════════════════════════════

def booking_agent_run(
    scheduling_result: Dict,
    quote: Dict,
    provider: Dict,
    intent: Dict,
    surge_mult: float,
) -> Dict:
    now        = datetime.datetime.now()
    receipt_no = f"KG-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
    slot       = scheduling_result.get("slot", "10:00")
    bid        = scheduling_result.get("booking_id", "BK-000000")

    step_defs = [
        (1, "Slot Lock",           f"Calendar slot {slot} locked. Booking ID: {bid}"),
        (2, "Confirmation",        f"Push notification sent to user & {provider['name']} (+{provider['phone'][-7:]})"),
        (3, "Receipt Generated",   f"Receipt #{receipt_no} — Rs.{quote['total_pkr']} — {intent.get('service_type')} service"),
        (4, "Reminders Scheduled", "Reminder chain: T-24h · T-1h · T-15min via FCM"),
        (5, "En-Route Update",     f"Provider departs → live ETA pushed to user. Travel buffer: {scheduling_result.get('travel_buffer_minutes', 45)} min"),
        (6, "Service Completion",  "3-item checklist activated. Photo/video evidence placeholder triggered."),
        (7, "Feedback & DNA",      f"Post-service form sent. DNA score update queued for {provider['name']}."),
    ]

    steps = [
        {
            "step":       n,
            "title":      title,
            "agent_note": note,
            "timestamp":  (now + datetime.timedelta(seconds=n * 2)).isoformat(),
            "status":     "completed",
        }
        for n, title, note in step_defs
    ]

    return {
        "status":         "booking_confirmed",
        "receipt_number": receipt_no,
        "booking_id":     bid,
        "provider":       provider["name"],
        "service":        intent.get("service_type"),
        "scheduled":      f"{scheduling_result.get('date')} at {slot}",
        "total_pkr":      quote["total_pkr"],
        "surge_multiplier": surge_mult,
        "steps":          steps,
        "antigravity_trace": {
            "agents_invoked": [
                "IntentAgent", "SurgeAgent", "MatchingAgent",
                "PricingAgent", "SchedulingAgent", "BookingAgent",
            ],
            "total_steps":   len(steps),
            "completed_at":  now.isoformat(),
        },
        "agent": "BookingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# DISPUTE AGENT
# ════════════════════════════════════════════════════════════════════════════

def dispute_agent_run(
    dispute_type: str,
    description: str,
    quoted_price: float,
    charged_price: float,
    provider: Dict,
    booking: Optional[Dict] = None,
) -> Dict:
    dna           = provider.get("dna_score", 700)
    past_disputes = provider.get("dispute_count", 0)
    overcharge    = charged_price - quoted_price

    verdict  = "mediated"
    action   = "partial_refund"
    refund   = 0.0
    penalty  = "none"
    escalate = False

    if dispute_type == "no_show":
        verdict  = "user_favor"
        action   = "rebook"
        penalty  = "dna_penalty"
        reasoning = f"{provider['name']} did not show. Free rebook offered. DNA penalised."

    elif dispute_type == "price_disagreement":
        if overcharge > 500 or (overcharge > 200 and dna < 700):
            verdict   = "user_favor"
            refund    = overcharge * 0.80
            penalty   = "dna_penalty" if past_disputes < 3 else "soft_ban"
            reasoning = f"Overcharge of Rs.{round(overcharge)} confirmed. Refund Rs.{round(refund)} approved."
        else:
            refund    = overcharge * 0.50
            penalty   = "warning"
            reasoning = f"Discrepancy Rs.{round(overcharge)}. Goodwill refund Rs.{round(refund)}. Provider warned."

    elif dispute_type == "quality_complaint":
        if dna < 600 or past_disputes >= 5:
            verdict   = "user_favor"
            action    = "rebook"
            refund    = quoted_price * 0.50
            penalty   = "soft_ban" if past_disputes >= 5 else "dna_penalty"
            escalate  = past_disputes >= 5
            reasoning = "Quality complaint validated. 50% refund + free rebook. Provider under review."
        else:
            refund    = quoted_price * 0.25
            penalty   = "warning"
            reasoning = "Quality noted. 25% goodwill refund. Provider counselled."

    elif dispute_type == "cancellation":
        verdict   = "user_favor"
        action    = "rebook"
        penalty   = "dna_penalty"
        reasoning = "Provider cancelled last-minute. Priority rebook + DNA penalty."

    elif dispute_type == "overrun":
        refund    = overcharge * 0.50 if overcharge > 0 else 0
        penalty   = "warning"
        reasoning = "Time overrun noted. Partial adjustment applied."

    else:
        reasoning = f"Unknown dispute type '{dispute_type}'. Escalated for manual review."
        escalate  = True

    # Blacklist trigger
    if past_disputes >= 10 or (past_disputes >= 3 and penalty in ("soft_ban", "dna_penalty")):
        penalty   = "blacklist"
        escalate  = True
        reasoning += " Provider exceeded threshold — blacklisted and escalated to human team."

    ticket_id = f"DSP-{uuid.uuid4().hex[:8].upper()}"
    dna_delta = -15 if "dna_penalty" in penalty else (-50 if penalty == "blacklist" else 0)

    return {
        "status":              "escalated" if escalate else "resolved",
        "ticket_id":           ticket_id,
        "dispute_type":        dispute_type,
        "verdict":             verdict,
        "action":              action,
        "refund_amount_pkr":   round(refund, 2),
        "penalty_to_provider": penalty,
        "reasoning":           reasoning,
        "escalate_to_human":   escalate,
        "provider_dna_delta":  dna_delta,
        "support_ticket": {
            "id":           ticket_id,
            "created_at":   datetime.datetime.now().isoformat(),
            "provider":     provider.get("name"),
            "type":         dispute_type,
            "trace_attached": True,
        },
        "agent": "DisputeAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# PROVIDER OPTIMIZATION AGENT  (NEW)
# ════════════════════════════════════════════════════════════════════════════

def provider_optimization_agent_run(
    provider: Dict,
    demand_data: Dict,
    area: str,
    service: str,
) -> Dict:
    """
    Gives providers workload balancing advice, earnings forecast,
    and recommended time slots based on demand patterns.
    """
    zones    = {z["area"]: z for z in demand_data.get("demand_zones", [])}
    zone     = zones.get(area, {})
    hourly   = zone.get("hourly_demand", {}).get(service, [0] * 24)
    total_jobs_today = len(_booked_slots.get(provider["id"], []))

    # Find peak hours for this service
    peak_hours = sorted(range(len(hourly)), key=lambda h: hourly[h], reverse=True)[:3]
    peak_strs  = [f"{h:02d}:00" for h in peak_hours]

    # Earnings estimate: base_rate × expected jobs
    potential_jobs = max(0, _MAX_DAILY_JOBS - total_jobs_today)
    estimated_earnings = potential_jobs * provider.get("base_rate_pkr", 1000)

    # Adjacent high-demand areas
    other_zones = [z for z in demand_data.get("demand_zones", []) if z["area"] != area]
    hotspot = max(
        other_zones,
        key=lambda z: sum(z.get("hourly_demand", {}).get(service, [0])),
        default=None,
    )

    return {
        "provider_id":         provider["id"],
        "provider_name":       provider["name"],
        "jobs_today":          total_jobs_today,
        "capacity_remaining":  potential_jobs,
        "recommended_slots":   peak_strs,
        "estimated_earnings_pkr": estimated_earnings,
        "hotspot_area":        hotspot["area"] if hotspot else area,
        "advice": (
            f"Peak demand at {', '.join(peak_strs)}. "
            f"You can take {potential_jobs} more jobs today. "
            f"Estimated earnings: Rs.{estimated_earnings}. "
            + (f"High demand also in {hotspot['area']} — consider expanding coverage." if hotspot else "")
        ),
        "agent": "ProviderOptimizationAgent",
    }


# ── Antigravity Tool Definitions ─────────────────────────────────────────────
TOOL_DEFINITIONS = [
    {"name": "surge_agent",                 "description": "Detects demand surges, computes tiered multiplier, provider load-balancing, off-peak guidance."},
    {"name": "pricing_agent",               "description": "7-component transparent quote: base + urgency + tiered distance + complexity + surge - loyalty - budget relief."},
    {"name": "negotiation_agent",           "description": "Multi-round price negotiation with surge awareness and loyalty tiers."},
    {"name": "scheduling_agent",            "description": "Prevents double-booking, enforces ETA+45min buffer, daily job cap (6), auto-rescheduling on cancellation."},
    {"name": "booking_agent",               "description": "7-step booking chain: lock → confirm → receipt → reminders → en-route → completion checklist → DNA update."},
    {"name": "dispute_agent",               "description": "5-type dispute resolution with refund, penalty, blacklist, and human escalation."},
    {"name": "provider_optimization_agent", "description": "Workload balancing, earnings forecast, peak-hour recommendations, hotspot area suggestions."},
]


# ── Self-Test ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("KaamYaab — Orchestrator Agents v2 Test")
    print("=" * 60)

    p = {
        "id": "p001", "name": "Tariq Mehmood", "phone": "+92-300-1234567",
        "service_category": "AC Repair", "base_rate_pkr": 1200,
        "on_time_rate": 0.97, "cancellation_rate": 0.02,
        "price_fairness_score": 0.95, "dispute_count": 1,
        "dna_score": 912, "surge_acceptor": True,
        "available_slots": ["09:00", "10:00", "11:00", "14:00"],
        "is_verified": True,
    }
    intent = {"service_type": "AC Repair", "urgency": "high",
               "budget_sensitivity": 0.7, "job_complexity": "intermediate"}

    # Pricing
    q = pricing_agent_run(p, intent, dist_km=2.5, surge_mult=1.6, is_repeat_customer=True)
    print(f"\n💰 Quote: Rs.{q['total_pkr']}  |  {q['breakdown']}")

    # Negotiation round 1
    n1 = negotiation_agent_run(q["total_pkr"], 1200, p, intent, 1.6, True, negotiation_round=1)
    print(f"\n💬 Negotiation R1: accepted={n1['accepted']} counter=Rs.{n1['counter_offer_pkr']}")
    print(f"   {n1['reasoning']}")

    # Scheduling
    s = scheduling_agent_run(p, "2026-05-16", "10:00", eta_minutes=8)
    print(f"\n📅 Scheduling: {s['status']} — {s['message']}")

    # Booking
    b = booking_agent_run(s, q, p, intent, 1.6)
    print(f"\n📋 Booking: {b['status']} | Receipt: {b['receipt_number']}")
    for step in b["steps"]:
        print(f"   Step {step['step']} [{step['title']}]: {step['agent_note'][:60]}")

    # Dispute
    d = dispute_agent_run("price_disagreement", "Charged extra", 1200, 1800,
                           {**p, "dna_score": 620, "dispute_count": 4})
    print(f"\n⚖️  Dispute: {d['verdict']} | Refund Rs.{d['refund_amount_pkr']} | Penalty: {d['penalty_to_provider']}")
    print(f"   {d['reasoning']}")
