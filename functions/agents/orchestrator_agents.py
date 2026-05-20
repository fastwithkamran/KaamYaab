"""
KaamYaab — Orchestrator Agents  (v3 — Optimized)
KaamYaab Autonomous Agent System | Cohere-Powered

Agents: SurgeAgent · PricingAgent · NegotiationAgent · SchedulingAgent · BookingAgent · DisputeAgent · ProviderOptimizationAgent

Bug Fixes (v2 → v3)
────────────────────
• BUG-9  FIXED: negotiation_agent_run() — surge_floor was LOWER during surge
  (original_quote  0.90 when surge > 1.2). This is backwards: during high demand
  the floor should be at or above the quoted price. Fixed: floor is always
  max(original_quote  0.80, original_quote  loyalty_discount), and surge info
  is surfaced in reasoning only.
• BUG-10 FIXED: booking_agent_run() did not check whether scheduling_result
  status == "confirmed" before proceeding. A failed/slot_taken scheduling result
  would still generate a receipt. Added guard: returns early with "scheduling_failed"
  status when the scheduling step did not succeed.
• BUG-11 FIXED: pricing_agent_run() distance formula now uses the canonical
  _distance_cost() imported from matching_agent to ensure consistent quotes
  everywhere in the pipeline.
• BUG-12 FIXED: dispute_agent_run() dna_delta used string-containment `"dna_penalty"
  in penalty` which is True for both "dna_penalty" and any string containing it.
  Replaced with explicit equality checks.
• MIGRATION: Replaced google.generativeai with Cohere (command-r-plus).
  Cohere is used only in NegotiationAgent for complex counter-offer reasoning.
  Set COHERE_API_KEY in your environment.
"""

import json
import logging
import os
import time
import uuid
import datetime
from typing import Dict, List, Any, Optional

try:
    import cohere
except ImportError:
    cohere = None

# Import canonical distance cost from matching_agent to avoid formula drift
try:
    from matching_agent import _distance_cost
except ImportError:
    # Fallback if running standalone
    def _distance_cost(dist_km: float) -> int:  # type: ignore[misc]
        if dist_km <= 2.0:
            return 0
        tier1 = min(dist_km, 5.0) - 2.0
        tier2 = max(0.0, dist_km - 5.0)
        return round(tier1 * 20.0 + tier2 * 35.0)

logger = logging.getLogger(__name__)

_cohere_api_key = os.getenv("COHERE_API_KEY", "").strip()
co = None
if _cohere_api_key and cohere is not None:
    co = cohere.Client(api_key=_cohere_api_key)
elif _cohere_api_key and cohere is None:
    logger.warning("[Orchestrator] cohere package not installed — run: pip install cohere")


# ════════════════════════════════════════════════════════════════════════════════
# SURGE AGENT
# ════════════════════════════════════════════════════════════════════════════════

def surge_agent_run(
    demand_data: Dict,
    area: str,
    service: str,
    current_hour: int,
    available_providers: int,
) -> Dict:
    """Detects surge via demand/provider ratio. Tiered multiplier + load balancing."""
    zones = {z["area"]: z for z in demand_data.get("demand_zones", [])}
    zone  = zones.get(area, {})
    if not zone:
        return {"status": "no_data", "surge_multiplier": 1.0, "active": False, "agent": "SurgeAgent"}

    hourly    = zone.get("hourly_demand", {}).get(service, [0] * 24)
    threshold = zone.get("surge_threshold", {}).get(service, 10)
    current   = hourly[current_hour] if current_hour < len(hourly) else 0

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

    off_peak = _find_off_peak(hourly, threshold)
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


# ════════════════════════════════════════════════════════════════════════════════
# PRICING AGENT
# ════════════════════════════════════════════════════════════════════════════════

_URGENCY_RATES = {"emergency": 0.35, "high": 0.20, "medium": 0.08, "low": 0.0}
_COMPLEX_RATES = {"complex": 0.40, "intermediate": 0.20, "basic": 0.0}


def pricing_agent_run(
    provider: Dict,
    intent: Dict,
    dist_km: float,
    surge_mult: float,
    is_repeat_customer: bool = False,
) -> Dict:
    """
    7-component transparent dynamic quote.
    BUG-11 FIX: uses _distance_cost() — same formula as matching_agent.calculate_quote().
    """
    base       = provider.get("base_rate_pkr", 1000)
    urgency    = intent.get("urgency", "medium")
    complexity = intent.get("job_complexity", "basic")
    budget     = float(intent.get("budget_sensitivity", 0.5))

    urgency_pkr  = round(base * _URGENCY_RATES.get(urgency, 0))
    # BUG-11 FIX: was using a different formula than matching_agent
    dist_pkr     = _distance_cost(dist_km)
    complex_pkr  = round(base * _COMPLEX_RATES.get(complexity, 0))
    surge_pkr    = round((base + urgency_pkr + complex_pkr) * max(0, surge_mult - 1.0))
    loyalty_pkr  = round(base * 0.07) if is_repeat_customer else 0
    budget_pkr   = round(base * 0.05) if budget >= 0.75 else 0
    total        = base + urgency_pkr + dist_pkr + complex_pkr + surge_pkr - loyalty_pkr - budget_pkr
    floor        = round(base * 0.80)
    total        = max(total, floor)

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


# ════════════════════════════════════════════════════════════════════════════════
# NEGOTIATION AGENT  (Cohere-powered for complex counter-offer reasoning)
# ════════════════════════════════════════════════════════════════════════════════

_NEGOTIATION_PROMPT = """
You are the Negotiation Agent for KaamYaab. A service provider has quoted Rs.{quote}
for a {service} job. The user has offered Rs.{user_offer}.
Provider floor (cannot go below): Rs.{floor}.
Surge multiplier currently: {surge}x.
Is repeat customer: {repeat}.
Negotiation round: {round}.

Return ONLY valid JSON:
{{
  "accepted": true/false,
  "counter_offer_pkr": <integer>,
  "reasoning": "<brief plain-language explanation in English>",
  "is_final_offer": true/false
}}
Rules:
- If user_offer >= floor: accepted = true, counter = user_offer.
- If round >= 2: is_final_offer = true, counter = floor.
- Keep counter >= floor always.
- During surge, mention it briefly in reasoning.
"""


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
    Multi-round negotiation. Tries Cohere for richer reasoning; falls back to rules.

    BUG-9 FIX: The old surge_floor = original_quote × 0.90 during surge made the
    floor LOWER during high demand — completely backwards. A surge means the provider
    has leverage; their floor should not drop. The floor is now computed purely from
    the quote with a loyalty adjustment, and surge information is conveyed in the
    reasoning message only.
    """
    budget_sens  = float(intent.get("budget_sensitivity", 0.5))
    loyalty_disc = original_quote * (0.10 if is_repeat_customer else 0.0)

    # BUG-9 FIX: floor is simply 80% of quote minus loyalty, regardless of surge.
    # Surge raises the quote itself (via PricingAgent) — no need to also manipulate
    # the negotiation floor downwards.
    floor = max(original_quote * 0.80, original_quote - loyalty_disc)

    # Try Cohere for richer counter-offer reasoning
    if co is not None and negotiation_round >= 2:
        try:
            prompt = _NEGOTIATION_PROMPT.format(
                quote=round(original_quote),
                service=intent.get("service_type", "service"),
                user_offer=round(user_offer),
                floor=round(floor),
                surge=surge_mult,
                repeat=is_repeat_customer,
                round=negotiation_round,
            )
            resp   = co.chat(model="command-r-plus", message=prompt, temperature=0.1, max_tokens=300)
            text   = resp.text.strip()
            import re
            text   = re.sub(r'```(?:json)?\s*|\s*```', '', text).strip()
            cohere_result = json.loads(text)
            cohere_result.update({
                "discount_reason":      "loyalty" if loyalty_disc > 0 else ("surge" if surge_mult > 1.2 else "standard"),
                "discount_applied_pkr": round(loyalty_disc),
                "round":                negotiation_round,
                "agreed_price_pkr":     round(user_offer) if cohere_result.get("accepted") else None,
                "agent":                "NegotiationAgent (Cohere)",
            })
            return cohere_result
        except Exception as exc:
            logger.warning("[NegotiationAgent] Cohere failed (%s) — rule fallback", exc)

    # Rule-based fallback
    if user_offer >= floor:
        reason_label = "loyalty" if loyalty_disc > 0 else "within_floor"
        return {
            "accepted":             True,
            "agreed_price_pkr":     round(user_offer),
            "counter_offer_pkr":    round(user_offer),
            "reasoning":            "Offer accepted." + (f" Loyalty discount Rs.{round(loyalty_disc)} applied." if loyalty_disc else ""),
            "discount_reason":      reason_label,
            "discount_applied_pkr": round(loyalty_disc),
            "is_final_offer":       True,
            "round":                negotiation_round,
            "agent":                "NegotiationAgent",
        }

    if negotiation_round == 1:
        counter  = round(floor * 1.03)
        is_final = False
        reasoning = f"Provider's best offer is Rs.{counter}."
    else:
        counter  = round(floor)
        is_final = True
        reasoning = f"Final offer Rs.{counter}. Provider cannot go lower."

    if surge_mult > 1.2:
        reasoning += f" (Surge {surge_mult}x currently active — prices are elevated.)"

    counter_reason = "loyalty" if loyalty_disc > 0 else ("surge" if surge_mult > 1.2 else "standard")
    return {
        "accepted":             False,
        "agreed_price_pkr":     None,
        "counter_offer_pkr":    counter,
        "reasoning":            reasoning,
        "discount_reason":      counter_reason,
        "discount_applied_pkr": round(loyalty_disc),
        "is_final_offer":       is_final,
        "round":                negotiation_round,
        "agent":                "NegotiationAgent",
    }


# ════════════════════════════════════════════════════════════════════════════════
# SCHEDULING AGENT
# ════════════════════════════════════════════════════════════════════════════════

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

    if len(booked) >= _MAX_DAILY_JOBS:
        return {
            "status":            "daily_cap_reached",
            "message":           f"{provider['name']} has reached max {_MAX_DAILY_JOBS} jobs today.",
            "alternate_slots":   [],
            "waitlist_position": len(booked),
            "agent":             "SchedulingAgent",
        }

    if requested_time in booked:
        alternates = [s for s in provider.get("available_slots", []) if s not in booked]
        return {
            "status":            "slot_taken",
            "requested_slot":    requested_time,
            "alternate_slots":   alternates[:3],
            "waitlist_position": len(booked),
            "message":           f"{requested_time} is taken. Alternatives: {', '.join(alternates[:3])}",
            "agent":             "SchedulingAgent",
        }

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

    _booked_slots.setdefault(pid, []).append(requested_time)
    booking_id = f"BK-{uuid.uuid4().hex[:8].upper()}"

    return {
        "status":                "confirmed",
        "booking_id":            booking_id,
        "provider_id":           pid,
        "provider_name":         provider["name"],
        "slot":                  requested_time,
        "date":                  requested_date,
        "travel_buffer_minutes": required_gap,
        "daily_jobs_booked":     len(_booked_slots[pid]),
        "message":               f"Slot {requested_time} on {requested_date} locked for {provider['name']}.",
        "agent":                 "SchedulingAgent",
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
        "status":         "rescheduled" if new_slot else "no_slot_available",
        "cancelled_slot": cancelled_slot,
        "new_slot":       new_slot,
        "affected_user":  affected_user,
        "provider":       provider["name"],
        "message":        f"Rescheduled to {new_slot}" if new_slot else "No slots available. Refund initiated.",
        "agent":          "SchedulingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════════
# BOOKING AGENT — 7-Step Chain
# ════════════════════════════════════════════════════════════════════════════════

def booking_agent_run(
    scheduling_result: Dict,
    quote: Dict,
    provider: Dict,
    intent: Dict,
    surge_mult: float,
) -> Dict:
    """
    Executes 7-step booking chain.

    BUG-10 FIX: Original code proceeded unconditionally, creating a receipt even
    when scheduling failed (status = "slot_taken", "insufficient_buffer", etc.).
    Now checks scheduling_result["status"] == "confirmed" before proceeding.
    """
    # BUG-10 FIX: guard — only proceed if scheduling actually succeeded
    if scheduling_result.get("status") != "confirmed":
        return {
            "status":           "scheduling_failed",
            "scheduling_status": scheduling_result.get("status"),
            "message":          scheduling_result.get("message", "Scheduling did not complete."),
            "alternate_slots":  scheduling_result.get("alternate_slots", []),
            "agent":            "BookingAgent",
        }

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
        "status":           "booking_confirmed",
        "receipt_number":   receipt_no,
        "booking_id":       bid,
        "provider":         provider["name"],
        "service":          intent.get("service_type"),
        "scheduled":        f"{scheduling_result.get('date')} at {slot}",
        "total_pkr":        quote["total_pkr"],
        "surge_multiplier": surge_mult,
        "steps":            steps,
        "antigravity_trace": {
            "agents_invoked": [
                "IntentAgent", "SurgeAgent", "MatchingAgent",
                "PricingAgent", "SchedulingAgent", "BookingAgent",
            ],
            "total_steps":  len(steps),
            "completed_at": now.isoformat(),
        },
        "agent": "BookingAgent",
    }


# ════════════════════════════════════════════════════════════════════════════════
# DISPUTE AGENT
# ════════════════════════════════════════════════════════════════════════════════

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
        verdict   = "user_favor"
        action    = "rebook"
        penalty   = "dna_penalty"
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

    # BUG-12 FIX: use explicit equality instead of string-containment `in`.
    if penalty == "dna_penalty":
        dna_delta = -15
    elif penalty == "blacklist":
        dna_delta = -50
    else:
        dna_delta = 0

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
            "id":             ticket_id,
            "created_at":     datetime.datetime.now().isoformat(),
            "provider":       provider.get("name"),
            "type":           dispute_type,
            "trace_attached": True,
        },
        "agent": "DisputeAgent",
    }


# ════════════════════════════════════════════════════════════════════════════════
# PROVIDER OPTIMIZATION AGENT
# ════════════════════════════════════════════════════════════════════════════════

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
    zones            = {z["area"]: z for z in demand_data.get("demand_zones", [])}
    zone             = zones.get(area, {})
    hourly           = zone.get("hourly_demand", {}).get(service, [0] * 24)
    total_jobs_today = len(_booked_slots.get(provider["id"], []))

    peak_hours = sorted(range(len(hourly)), key=lambda h: hourly[h], reverse=True)[:3]
    peak_strs  = [f"{h:02d}:00" for h in peak_hours]

    potential_jobs      = max(0, _MAX_DAILY_JOBS - total_jobs_today)
    estimated_earnings  = potential_jobs * provider.get("base_rate_pkr", 1000)

    other_zones = [z for z in demand_data.get("demand_zones", []) if z["area"] != area]
    hotspot = max(
        other_zones,
        key=lambda z: sum(z.get("hourly_demand", {}).get(service, [0])),
        default=None,
    )

    return {
        "provider_id":            provider["id"],
        "provider_name":          provider["name"],
        "jobs_today":             total_jobs_today,
        "capacity_remaining":     potential_jobs,
        "recommended_slots":      peak_strs,
        "estimated_earnings_pkr": estimated_earnings,
        "hotspot_area":           hotspot["area"] if hotspot else area,
        "advice": (
            f"Peak demand at {', '.join(peak_strs)}. "
            f"You can take {potential_jobs} more jobs today. "
            f"Estimated earnings: Rs.{estimated_earnings}. "
            + (f"High demand also in {hotspot['area']} — consider expanding coverage." if hotspot else "")
        ),
        "agent": "ProviderOptimizationAgent",
    }


# ── Tool Definitions ───────────────────────────────────────────────────────────
TOOL_DEFINITIONS = [
    {"name": "surge_agent",                 "description": "Detects demand surges, computes tiered multiplier, provider load-balancing, off-peak guidance."},
    {"name": "pricing_agent",               "description": "7-component transparent quote: base + urgency + distance (canonical) + complexity + surge - loyalty - budget relief."},
    {"name": "negotiation_agent",           "description": "Multi-round price negotiation. Cohere-powered reasoning on round 2+. Falls back to rule engine."},
    {"name": "scheduling_agent",            "description": "Prevents double-booking, enforces ETA+45min buffer, daily job cap (6), auto-rescheduling."},
    {"name": "booking_agent",               "description": "7-step booking chain — guards against unconfirmed scheduling. Produces receipt only on confirmed slot."},
    {"name": "dispute_agent",               "description": "5-type dispute resolution with refund, penalty, blacklist, and human escalation."},
    {"name": "provider_optimization_agent", "description": "Workload balancing, earnings forecast, peak-hour recommendations, hotspot area suggestions."},
]


# ── Self-Test ──────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("KaamYaab — Orchestrator Agents v3 Test (Cohere + Bug Fixes)")
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

    # Scheduling — confirmed
    s = scheduling_agent_run(p, "2026-05-16", "10:00", eta_minutes=8)
    print(f"\n📅 Scheduling: {s['status']} — {s['message']}")

    # Booking with confirmed scheduling
    b = booking_agent_run(s, q, p, intent, 1.6)
    print(f"\n📋 Booking: {b['status']} | Receipt: {b.get('receipt_number', 'N/A')}")
    for step in b.get("steps", []):
        print(f"   Step {step['step']} [{step['title']}]: {step['agent_note'][:60]}")

    # Test BUG-10 FIX: booking with failed scheduling
    s_fail = {"status": "slot_taken", "message": "10:00 is taken.", "alternate_slots": ["11:00"]}
    b_fail = booking_agent_run(s_fail, q, p, intent, 1.6)
    print(f"\n🚫 Booking (failed scheduling): {b_fail['status']} — {b_fail['message']}")

    # Dispute
    d = dispute_agent_run("price_disagreement", "Charged extra", 1200, 1800,
                           {**p, "dna_score": 620, "dispute_count": 4})
    print(f"\n⚖️  Dispute: {d['verdict']} | Refund Rs.{d['refund_amount_pkr']} | Penalty: {d['penalty_to_provider']}")
    print(f"   DNA Delta: {d['provider_dna_delta']} | {d['reasoning']}")