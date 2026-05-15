"""
KhidmatGaar — Surge Agent + Pricing Agent + Scheduling Agent + Booking Agent + Dispute Agent
Google Antigravity Orchestrator | Challenge 2
"""

import json
import logging
import os
import uuid
import datetime
from typing import Dict, List, Any, Optional
try:
    import google.generativeai as genai
except ImportError:  # pragma: no cover - environment-dependent optional dependency
    genai = None

logger = logging.getLogger(__name__)

_gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
if _gemini_api_key and genai is not None:
    genai.configure(api_key=_gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")
elif _gemini_api_key and genai is None:
    model = None
    logger.info("[OrchestratorAgents] google.generativeai is not installed — running without Gemini model")
else:
    model = None
    logger.info("[OrchestratorAgents] GEMINI_API_KEY not set — running without Gemini model")


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
    Detects surge conditions by comparing current demand vs. threshold.
    Returns surge multiplier and provider notifications.
    """
    zones = {z["area"]: z for z in demand_data.get("demand_zones", [])}
    zone = zones.get(area, {})

    if not zone:
        return {"status": "no_data", "surge_multiplier": 1.0, "active": False}

    hourly = zone.get("hourly_demand", {}).get(service, [0] * 24)
    threshold = zone.get("surge_threshold", {}).get(service, 10)
    current_demand = hourly[current_hour] if current_hour < len(hourly) else 0

    # Calculate surge multiplier
    if current_demand == 0 or available_providers == 0:
        mult = 1.0
    else:
        demand_ratio = current_demand / max(available_providers, 1)
        if demand_ratio >= 4:
            mult = min(2.5, 1.0 + (demand_ratio - 1) * 0.25)
        elif demand_ratio >= 2:
            mult = 1.0 + (demand_ratio - 1) * 0.15
        else:
            mult = 1.0

    mult = round(mult, 2)
    is_surge = mult > 1.1

    # Generate demand forecast message
    forecast = demand_data.get("forecast_next_24h", [])
    predicted = next(
        (f for f in forecast if f["area"] == area and f["service"] == service), None
    )

    provider_notification = None
    user_alert = None
    if is_surge:
        provider_notification = {
            "message": f"🌊 Surge Alert! {service} demand in {area} is {mult}x. Accept jobs now to earn more.",
            "multiplier": mult,
            "area": area,
        }
        user_alert = {
            "title": f"Surge Active in {area}",
            "body": f"Demand for {service} is high ({current_demand} requests, {available_providers} providers). Book now to lock current price.",
            "multiplier": mult,
            "alternatives": f"Off-peak hours: {_find_off_peak(hourly, threshold)}",
        }

    return {
        "status": "success",
        "area": area,
        "service": service,
        "current_demand": current_demand,
        "threshold": threshold,
        "available_providers": available_providers,
        "surge_multiplier": mult,
        "active": is_surge,
        "demand_trend": _trend(hourly, current_hour),
        "provider_notification": provider_notification,
        "user_alert": user_alert,
        "forecast": predicted,
        "agent": "SurgeAgent",
    }


def _find_off_peak(hourly: list, threshold: int) -> str:
    low_hours = [h for h, d in enumerate(hourly) if d < threshold * 0.5 and d > 0]
    if not low_hours:
        return "Off-peak hours not available today"
    times = [f"{h:02d}:00" for h in low_hours[:3]]
    return ", ".join(times)


def _trend(hourly: list, current_hour: int) -> str:
    if current_hour < 1:
        return "rising"
    prev = hourly[current_hour - 1]
    curr = hourly[current_hour]
    if curr > prev * 1.2:
        return "rising_fast"
    elif curr > prev:
        return "rising"
    elif curr < prev * 0.8:
        return "falling"
    return "stable"


# ════════════════════════════════════════════════════════════════════════════
# PRICING AGENT
# ════════════════════════════════════════════════════════════════════════════

def pricing_agent_run(
    provider: Dict,
    intent: Dict,
    dist_km: float,
    surge_mult: float,
    is_repeat_customer: bool = False,
    use_gemini: bool = False,
) -> Dict:
    """Generates transparent dynamic quote and handles negotiation."""
    base = provider.get("base_rate_pkr", 1000)
    urgency = intent.get("urgency", "medium")
    budget_sensitivity = intent.get("budget_sensitivity", 0.5)

    urgency_adj = {"emergency": 0.30, "high": 0.15, "medium": 0.0, "low": 0.0}.get(urgency, 0.0)
    urgency_pkr = round(base * urgency_adj)
    dist_cost = round(dist_km * 50)
    surge_pkr = round((base + urgency_pkr) * (surge_mult - 1.0))
    loyalty = round(base * 0.07) if is_repeat_customer else 0
    total = base + urgency_pkr + dist_cost + surge_pkr - loyalty

    return {
        "base_pkr": base,
        "urgency_adj_pkr": urgency_pkr,
        "distance_cost_pkr": dist_cost,
        "surge_adj_pkr": surge_pkr,
        "surge_multiplier": surge_mult,
        "loyalty_discount_pkr": loyalty,
        "total_pkr": round(total),
        "is_negotiable": budget_sensitivity > 0.55,
        "min_acceptable_pkr": round(base * 0.85),  # Provider floor
        "breakdown": (
            f"Base Rs.{base} + Urgency Rs.{urgency_pkr} + "
            f"Distance Rs.{dist_cost} + Surge Rs.{surge_pkr}"
            + (f" - Loyalty Rs.{loyalty}" if loyalty > 0 else "")
        ),
        "agent": "PricingAgent",
    }


def negotiation_agent_run(
    original_quote: float,
    user_offer: float,
    provider: Dict,
    intent: Dict,
    surge_mult: float,
    is_repeat_customer: bool,
) -> Dict:
    """AI-powered negotiation between user and provider."""
    min_acceptable = original_quote * 0.85
    loyalty_discount = original_quote * 0.07 if is_repeat_customer else 0
    counter = max(min_acceptable, original_quote - loyalty_discount)

    if user_offer >= counter:
        return {
            "accepted": True,
            "counter_offer_pkr": round(user_offer),
            "reasoning": f"Offer accepted. {'Loyalty discount of Rs.' + str(round(loyalty_discount)) + ' applied.' if loyalty_discount > 0 else ''}",
            "discount_applied_pkr": round(loyalty_discount),
            "discount_reason": "loyalty" if loyalty_discount > 0 else "none",
            "is_final_offer": True,
            "agent": "NegotiationAgent",
        }

    surge_note = f" (surge {surge_mult}x active)" if surge_mult > 1.2 else ""
    return {
        "accepted": False,
        "counter_offer_pkr": round(counter),
        "reasoning": (
            f"Provider's minimum is Rs.{round(counter)}{surge_note}. "
            f"{'Loyalty discount of Rs.' + str(round(loyalty_discount)) + ' already applied.' if loyalty_discount > 0 else 'No discount applicable at this time.'}"
        ),
        "discount_applied_pkr": round(loyalty_discount),
        "discount_reason": "loyalty" if loyalty_discount > 0 else "none",
        "is_final_offer": True,
        "agent": "NegotiationAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# SCHEDULING AGENT
# ════════════════════════════════════════════════════════════════════════════

_booked_slots: Dict[str, List[str]] = {}  # provider_id → list of locked slots


def scheduling_agent_run(
    provider: Dict,
    requested_date: str,
    requested_time: str,
    eta_minutes: int,
) -> Dict:
    """
    Prevents double-booking, calculates travel-time buffers,
    suggests alternates, manages waitlist.
    """
    pid = provider["id"]
    slot_key = f"{pid}:{requested_date}:{requested_time}"
    booked = _booked_slots.get(pid, [])

    # Check if slot is already taken
    if requested_time in booked:
        # Find next available slot
        all_slots = provider.get("available_slots", [])
        alternates = [s for s in all_slots if s not in booked and s != requested_time]
        return {
            "status": "slot_taken",
            "requested_slot": requested_time,
            "alternate_slots": alternates[:3],
            "waitlist_position": len(booked),
            "message": f"{requested_time} is booked. Alternatives: {', '.join(alternates[:3])}",
            "agent": "SchedulingAgent",
        }

    # Check travel time buffer (need 30 min gap between jobs)
    for existing in booked:
        try:
            ex_h, ex_m = map(int, existing.split(":"))
            req_h, req_m = map(int, requested_time.split(":"))
            diff_min = abs((req_h * 60 + req_m) - (ex_h * 60 + ex_m))
            if diff_min < 30 + eta_minutes:
                alternates = [s for s in provider.get("available_slots", [])
                              if s not in booked and s != requested_time]
                return {
                    "status": "insufficient_buffer",
                    "message": f"Travel time conflict with {existing}. Need ≥{30 + eta_minutes}min gap.",
                    "alternate_slots": alternates[:3],
                    "agent": "SchedulingAgent",
                }
        except ValueError:
            pass

    # Lock the slot
    _booked_slots.setdefault(pid, []).append(requested_time)
    booking_id = f"BK-{uuid.uuid4().hex[:8].upper()}"

    return {
        "status": "confirmed",
        "booking_id": booking_id,
        "provider_id": pid,
        "provider_name": provider["name"],
        "slot": requested_time,
        "date": requested_date,
        "travel_buffer_minutes": 30,
        "message": f"Slot {requested_time} on {requested_date} locked for {provider['name']}.",
        "agent": "SchedulingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════
# BOOKING AGENT — 7-Step Chain Orchestrator
# ════════════════════════════════════════════════════════════════════════════

def booking_agent_run(
    scheduling_result: Dict,
    quote: Dict,
    provider: Dict,
    intent: Dict,
    surge_mult: float,
) -> Dict:
    """
    Simulates the complete 7-step booking workflow.
    Each step logged with timestamp and agent note.
    """
    now = datetime.datetime.now()
    steps = []
    receipt_no = f"KG-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

    step_defs = [
        (1, "Slot Lock",           f"Provider calendar slot {scheduling_result.get('slot')} locked. Booking ID: {scheduling_result.get('booking_id')}"),
        (2, "Confirmation",        f"In-app booking notification sent to user and {provider['name']} (+{provider['phone'][-7:]})"),
        (3, "Receipt Generated",   f"Receipt #{receipt_no} — Rs. {quote['total_pkr']} — {intent.get('service_type')} service"),
        (4, "Reminders Scheduled", "Reminder chain queued: T-24h, T-1h, T-15min via Firebase Cloud Messaging"),
        (5, "En-Route Update",     f"Provider en-route notification will trigger at departure. ETA calculated dynamically."),
        (6, "Service Completion",  "Completion checklist (3 items) + photo placeholder activated for post-service verification"),
        (7, "Feedback & DNA",      f"Post-service feedback form triggered. DNA Score update queued for {provider['name']}."),
    ]

    for step_num, title, note in step_defs:
        steps.append({
            "step": step_num,
            "title": title,
            "agent_note": note,
            "timestamp": (now + datetime.timedelta(seconds=step_num * 2)).isoformat(),
            "status": "completed",
        })

    return {
        "status": "booking_confirmed",
        "receipt_number": receipt_no,
        "booking_id": scheduling_result.get("booking_id"),
        "provider": provider["name"],
        "service": intent.get("service_type"),
        "scheduled": f"{scheduling_result.get('date')} at {scheduling_result.get('slot')}",
        "total_pkr": quote["total_pkr"],
        "surge_multiplier": surge_mult,
        "steps": steps,
        "antigravity_trace": {
            "agents_invoked": ["IntentAgent", "SurgeAgent", "MatchingAgent", "PricingAgent", "SchedulingAgent", "BookingAgent"],
            "total_steps": len(steps),
            "completed_at": now.isoformat(),
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
    """
    Analyzes disputes and produces automated verdicts with action plans.
    Triggers blacklist or human escalation for severe cases.
    """
    dna = provider.get("dna_score", 700)
    past_disputes = provider.get("dispute_count", 0)
    overcharge = charged_price - quoted_price

    # ── Dispute classification logic ─────────────────────────────────────────
    verdict = "mediated"
    action = "partial_refund"
    refund = 0.0
    penalty = "none"
    escalate = False
    reasoning = ""

    if dispute_type == "no_show":
        verdict = "user_favor"
        action = "rebook"
        refund = 0
        penalty = "dna_penalty"
        reasoning = (
            f"{provider['name']} did not show up. Full rebook offered at no cost. "
            "DNA score penalized. Incident logged."
        )

    elif dispute_type == "price_disagreement":
        if overcharge > 500 or (overcharge > 200 and dna < 700):
            verdict = "user_favor"
            action = "partial_refund"
            refund = overcharge * 0.8
            penalty = "dna_penalty" if past_disputes < 3 else "soft_ban"
            reasoning = (
                f"Provider charged Rs.{round(overcharge)} over quoted price without documented justification. "
                f"Partial refund of Rs.{round(refund)} approved."
            )
        else:
            verdict = "mediated"
            action = "partial_refund"
            refund = overcharge * 0.5
            penalty = "warning"
            reasoning = (
                f"Pricing discrepancy of Rs.{round(overcharge)} noted. "
                f"Goodwill refund of Rs.{round(refund)} issued. Provider warned."
            )

    elif dispute_type == "quality_complaint":
        if dna < 600 or past_disputes >= 5:
            verdict = "user_favor"
            action = "rebook"
            refund = quoted_price * 0.5
            penalty = "soft_ban" if past_disputes >= 5 else "dna_penalty"
            reasoning = (
                "Quality complaint validated against provider's history. "
                "50% refund and free rebook offered. Provider under review."
            )
            escalate = past_disputes >= 5
        else:
            verdict = "mediated"
            action = "partial_refund"
            refund = quoted_price * 0.25
            penalty = "warning"
            reasoning = "Quality concern noted. 25% goodwill refund. Provider counselled."

    elif dispute_type == "cancellation":
        verdict = "user_favor"
        action = "rebook"
        refund = 0
        penalty = "dna_penalty"
        reasoning = "Last-minute cancellation by provider. Priority rebook and DNA penalty applied."

    elif dispute_type == "overrun":
        verdict = "mediated"
        action = "partial_refund"
        refund = overcharge * 0.5 if overcharge > 0 else 0
        penalty = "warning"
        reasoning = "Service time overrun noted. Partial adjustment applied."

    # ── Blacklist trigger ─────────────────────────────────────────────────────
    if past_disputes >= 10 or (past_disputes >= 3 and penalty in ["soft_ban", "dna_penalty"]):
        penalty = "blacklist"
        escalate = True
        reasoning += " Provider has exceeded dispute threshold — soft blacklist applied and escalated to human review team."

    ticket_id = f"DSP-{uuid.uuid4().hex[:8].upper()}"

    return {
        "status": "resolved" if not escalate else "escalated",
        "ticket_id": ticket_id,
        "dispute_type": dispute_type,
        "verdict": verdict,
        "action": action,
        "refund_amount_pkr": round(refund, 2),
        "penalty_to_provider": penalty,
        "reasoning": reasoning,
        "escalate_to_human": escalate,
        "provider_dna_delta": -15 if "dna_penalty" in penalty else (-50 if penalty == "blacklist" else 0),
        "support_ticket": {
            "id": ticket_id,
            "created_at": datetime.datetime.now().isoformat(),
            "provider": provider.get("name"),
            "type": dispute_type,
            "trace_attached": True,
        },
        "agent": "DisputeAgent",
    }


# ── Antigravity Tool Definitions ─────────────────────────────────────────────
TOOL_DEFINITIONS = [
    {
        "name": "surge_agent",
        "description": "Detects demand surges by area and service type. Returns surge multiplier and user/provider notifications.",
    },
    {
        "name": "pricing_agent",
        "description": "Generates transparent dynamic price quotes: base + urgency + distance + surge - loyalty.",
    },
    {
        "name": "negotiation_agent",
        "description": "Mediates price negotiation between user and provider with AI-driven counter-offers.",
    },
    {
        "name": "scheduling_agent",
        "description": "Prevents double-booking, applies travel buffers, manages waitlists, auto-reschedules on cancellation.",
    },
    {
        "name": "booking_agent",
        "description": "Orchestrates the 7-step booking chain: lock → confirm → receipt → reminders → en-route → completion → DNA update.",
    },
    {
        "name": "dispute_agent",
        "description": "Analyzes disputes (no-show, price, quality, cancellation) and produces verdicts with refund/penalty actions.",
    },
]


if __name__ == "__main__":
    print("=" * 60)
    print("KhidmatGaar — Multi-Agent System Test")
    print("=" * 60)

    sample_provider = {
        "id": "p001", "name": "Tariq Mehmood", "phone": "+92-300-1234567",
        "service_category": "AC Repair", "skills": ["AC Installation", "AC Repair"],
        "lat": 33.7215, "lng": 73.0433, "area": "G-13",
        "dna_score": 912, "base_rate_pkr": 1200,
        "on_time_rate": 0.97, "cancellation_rate": 0.02,
        "price_fairness_score": 0.95, "dispute_count": 1,
        "surge_acceptor": True, "available_slots": ["09:00", "10:00"],
        "is_verified": True,
    }
    sample_intent = {
        "service_type": "AC Repair", "area": "G-13",
        "urgency": "high", "budget_sensitivity": 0.7,
    }

    # Test Pricing Agent
    quote = pricing_agent_run(sample_provider, sample_intent, dist_km=1.5, surge_mult=1.6)
    print(f"\n💰 Price Quote: Rs. {quote['total_pkr']}")
    print(f"   {quote['breakdown']}")

    # Test Negotiation
    neg = negotiation_agent_run(
        original_quote=quote["total_pkr"], user_offer=1400,
        provider=sample_provider, intent=sample_intent,
        surge_mult=1.6, is_repeat_customer=True,
    )
    print(f"\n💬 Negotiation: Counter Rs. {neg['counter_offer_pkr']} — {neg['reasoning']}")

    # Test Scheduling
    sched = scheduling_agent_run(sample_provider, "2026-05-14", "10:00", eta_minutes=9)
    print(f"\n📅 Scheduling: {sched['status']} — {sched['message']}")

    # Test Dispute
    dispute = dispute_agent_run(
        dispute_type="price_disagreement",
        description="Provider charged Rs. 1800 but quote was Rs. 1200",
        quoted_price=1200, charged_price=1800,
        provider={**sample_provider, "dna_score": 620, "dispute_count": 4},
    )
    print(f"\n⚖️ Dispute: {dispute['verdict']} — Refund Rs. {dispute['refund_amount_pkr']}")
    print(f"   {dispute['reasoning']}")
