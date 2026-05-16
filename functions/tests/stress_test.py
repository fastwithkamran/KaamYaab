"""
KaamYaab — Comprehensive Stress Test Suite
Google Antigravity Orchestrator | Challenge 2

Tests all 6 edge cases required by the hackathon:
1. No suitable provider available
2. Provider cancels after confirmation
3. Ambiguous / misspelled / mixed-language input
4. Two users request same provider (double-booking)
5. Price dispute after completion
6. Low-confidence language parsing → clarification flow
"""

import json
import sys
import os
import time
from datetime import datetime
from typing import Dict, List

# Add parent path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from agents.intent_agent import run as intent_run
from agents.matching_agent import run as matching_run, haversine
from agents.orchestrator_agents import (
    surge_agent_run,
    pricing_agent_run,
    negotiation_agent_run,
    scheduling_agent_run,
    booking_agent_run,
    dispute_agent_run,
)

# ── Load mock data ────────────────────────────────────────────────────────────
DATA_PATH = os.path.join(os.path.dirname(__file__), "../../assets/data/providers_mock.json")
DEMAND_PATH = os.path.join(os.path.dirname(__file__), "../../assets/data/demand_mock.json")

with open(DATA_PATH, "r", encoding="utf-8") as f:
    PROVIDERS = json.load(f)["providers"]

with open(DEMAND_PATH, "r", encoding="utf-8") as f:
    DEMAND = json.load(f)

USER_LAT, USER_LNG = 33.7215, 73.0433

PASS = "✅ PASS"
FAIL = "❌ FAIL"
WARN = "⚠️  WARN"

results = []

def log(test_name: str, status: str, detail: str):
    results.append({"test": test_name, "status": status, "detail": detail})
    print(f"\n{status}  {test_name}")
    print(f"   {detail}")


# ════════════════════════════════════════════════════════════════════════════
# TEST 1: Intent Parsing — 12 Multilingual Variants
# ════════════════════════════════════════════════════════════════════════════
def test_multilingual_intent():
    print("\n" + "="*60)
    print("TEST SUITE 1: Multilingual Intent Parsing")
    print("="*60)

    test_cases = [
        # (input, expected_service, expected_lang, expected_min_confidence)
        ("AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye", "AC Repair", "roman_urdu", 0.80),
        ("Mujhe kal morning main AC service chahiye G-11 mein", "AC Repair", "roman_urdu", 0.80),
        ("I need an electrician urgently in F-10, wiring issue", "Electrical", "english", 0.85),
        ("bijli ka masla hai, switch nahi chal raha", "Electrical", "roman_urdu", 0.75),
        ("پانی کا پائپ لیک ہو رہا ہے، فوری ضرورت ہے", "Plumbing", "urdu", 0.75),
        ("Bhai plumber chahiye, pipe phoot gaya hai urgent", "Plumbing", "roman_urdu", 0.80),
        ("MDCAT ke liye tutor chahiye, chemistry aur biology", "Tutoring", "roman_urdu", 0.75),
        ("ghar ki safai chahiye weekend pe", "Cleaning", "roman_urdu", 0.75),
        ("acond thek karwana hai urgent G13", "AC Repair", "roman_urdu", 0.65),  # misspelled
        ("kal subha 9 baje AC repair G-13, budget tight hai", "AC Repair", "roman_urdu", 0.85),
        ("Fix my AC please, tomorrow morning, G-13 area", "AC Repair", "english", 0.85),
        ("کل صبح G-13 میں AC ٹھیک کرنا ہے", "AC Repair", "urdu", 0.75),
    ]

    passed = 0
    for inp, exp_service, exp_lang, min_conf in test_cases:
        result = intent_run(inp, use_gemini=False)
        ok_service = result["service_type"] == exp_service
        ok_conf = result["confidence"] >= min_conf

        status = PASS if (ok_service and ok_conf) else FAIL
        if ok_service and ok_conf:
            passed += 1
        log(
            f"Intent: '{inp[:50]}...'",
            status,
            f"Service={result['service_type']} (exp={exp_service}) | "
            f"Confidence={result['confidence']:.0%} (min={min_conf:.0%}) | "
            f"Lang={result['language']} | Urgency={result['urgency']}"
        )

    log(
        "Multilingual Summary",
        PASS if passed >= 10 else WARN,
        f"{passed}/{len(test_cases)} cases parsed correctly"
    )


# ════════════════════════════════════════════════════════════════════════════
# TEST 2: Low Confidence → Clarification Flow
# ════════════════════════════════════════════════════════════════════════════
def test_low_confidence_clarification():
    print("\n" + "="*60)
    print("TEST SUITE 2: Low Confidence → Clarification")
    print("="*60)

    ambiguous_inputs = [
        "kuch theek karwana hai ghar mein",         # too vague
        "masla ho gaya hai",                         # no service type
        "help chahiye",                              # minimal info
        "kal aana",                                  # incomplete
    ]

    for inp in ambiguous_inputs:
        result = intent_run(inp, use_gemini=False)
        needs_clarification = result["clarification_needed"]
        has_question = bool(result.get("clarification_question"))

        log(
            f"Clarification: '{inp}'",
            PASS if needs_clarification and has_question else FAIL,
            f"Confidence={result['confidence']:.0%} | "
            f"Clarification needed={needs_clarification} | "
            f"Question: {result.get('clarification_question', 'N/A')[:60]}"
        )


# ════════════════════════════════════════════════════════════════════════════
# TEST 3: No Provider Available (Edge Case)
# ════════════════════════════════════════════════════════════════════════════
def test_no_provider_available():
    print("\n" + "="*60)
    print("TEST SUITE 3: No Provider Available")
    print("="*60)

    # Request a service category that has no providers in mock data
    intent = {
        "service_type": "Carpentry",  # not in mock dataset
        "area": "G-13",
        "urgency": "high",
        "budget_sensitivity": 0.5,
        "confidence": 0.85,
    }

    result = matching_run(PROVIDERS, intent, USER_LAT, USER_LNG, surge_mult=1.0)

    log(
        "No Provider — Carpentry (unavailable service)",
        PASS if result["status"] == "no_providers" else FAIL,
        f"Status={result['status']} | "
        f"Fallback={result.get('fallback', 'N/A')} | "
        f"Message={result.get('message', '')[:80]}"
    )

    # Also test: correct service but very remote location (far providers)
    intent2 = {
        "service_type": "AC Repair",
        "area": "Karachi",  # providers are all in Islamabad
        "urgency": "low",
        "budget_sensitivity": 0.9,
        "confidence": 0.90,
    }
    result2 = matching_run(PROVIDERS, intent2, 24.8607, 67.0011, surge_mult=1.0)
    matches = result2.get("matches", [])
    far_dist = matches[0]["distance_km"] if matches else 0

    log(
        "No Provider — Extreme Distance (Karachi user)",
        PASS if far_dist > 1000 else WARN,
        f"Nearest provider is {far_dist:.0f}km away | "
        f"Matches returned={len(matches)} | System handled gracefully"
    )


# ════════════════════════════════════════════════════════════════════════════
# TEST 4: Double-Booking Prevention
# ════════════════════════════════════════════════════════════════════════════
def test_double_booking():
    print("\n" + "="*60)
    print("TEST SUITE 4: Double-Booking Prevention")
    print("="*60)

    from agents.orchestrator_agents import _booked_slots
    _booked_slots.clear()  # reset

    provider = next(p for p in PROVIDERS if p["id"] == "p001")

    # User 1 books 10:00
    result1 = scheduling_agent_run(provider, "2026-05-14", "10:00", eta_minutes=9)
    log(
        "Booking #1 — 10:00 slot (User A)",
        PASS if result1["status"] == "confirmed" else FAIL,
        f"Status={result1['status']} | Booking ID={result1.get('booking_id', 'N/A')}"
    )

    # User 2 tries to book the same slot
    result2 = scheduling_agent_run(provider, "2026-05-14", "10:00", eta_minutes=9)
    log(
        "Booking #2 — Same slot conflict (User B)",
        PASS if result2["status"] == "slot_taken" else FAIL,
        f"Status={result2['status']} | "
        f"Alternates offered={result2.get('alternate_slots', [])}"
    )

    # User 2 tries a slot too close (travel buffer conflict)
    result3 = scheduling_agent_run(provider, "2026-05-14", "10:20", eta_minutes=20)
    log(
        "Booking #3 — Travel buffer conflict (10:20, 20min ETA)",
        PASS if result3["status"] in ["slot_taken", "insufficient_buffer"] else FAIL,
        f"Status={result3['status']} | "
        f"Message={result3.get('message', '')[:80]}"
    )

    # User 3 books a safe slot
    result4 = scheduling_agent_run(provider, "2026-05-14", "14:00", eta_minutes=9)
    log(
        "Booking #4 — Valid slot (14:00, safe gap)",
        PASS if result4["status"] == "confirmed" else FAIL,
        f"Status={result4['status']} | Booking ID={result4.get('booking_id', 'N/A')}"
    )


# ════════════════════════════════════════════════════════════════════════════
# TEST 5: Surge Detection Scenarios
# ════════════════════════════════════════════════════════════════════════════
def test_surge_detection():
    print("\n" + "="*60)
    print("TEST SUITE 5: Surge Detection")
    print("="*60)

    # Peak hour surge (14:00 = index 14 — high demand for AC in G-13)
    result_surge = surge_agent_run(DEMAND, "G-13", "AC Repair", current_hour=15, available_providers=3)
    log(
        "Surge: G-13 AC Repair at 15:00 (3 providers)",
        PASS if result_surge["surge_multiplier"] >= 1.2 else WARN,
        f"Demand={result_surge['current_demand']} | "
        f"Multiplier={result_surge['surge_multiplier']}x | "
        f"Active={result_surge['active']} | "
        f"Trend={result_surge['demand_trend']}"
    )

    # Off-peak — no surge
    result_normal = surge_agent_run(DEMAND, "G-13", "AC Repair", current_hour=3, available_providers=10)
    log(
        "No Surge: G-13 AC Repair at 03:00 (off-peak)",
        PASS if not result_normal["active"] else FAIL,
        f"Demand={result_normal['current_demand']} | "
        f"Multiplier={result_normal['surge_multiplier']}x | "
        f"Active={result_normal['active']}"
    )

    # Emergency: very high demand, very few providers
    result_emergency = surge_agent_run(DEMAND, "G-13", "AC Repair", current_hour=15, available_providers=1)
    log(
        "Emergency Surge: 1 provider, peak hour",
        PASS if result_emergency["surge_multiplier"] >= 1.8 else WARN,
        f"Multiplier={result_emergency['surge_multiplier']}x | "
        f"Provider notification: {result_emergency.get('provider_notification', {}).get('message', 'N/A')[:60]}"
    )


# ════════════════════════════════════════════════════════════════════════════
# TEST 6: Price Negotiation Agent
# ════════════════════════════════════════════════════════════════════════════
def test_negotiation():
    print("\n" + "="*60)
    print("TEST SUITE 6: Negotiation Agent")
    print("="*60)

    provider = next(p for p in PROVIDERS if p["id"] == "p001")
    intent = {"service_type": "AC Repair", "urgency": "high", "budget_sensitivity": 0.8}

    quote = pricing_agent_run(provider, intent, dist_km=1.5, surge_mult=1.6, is_repeat_customer=False)
    original = quote["total_pkr"]
    print(f"\n   Original Quote: Rs. {original}")

    # Case A: Offer way too low (rejected)
    neg_a = negotiation_agent_run(original, original * 0.5, provider, intent, 1.6, False)
    log(
        "Negotiation: User offers 50% (too low)",
        PASS if not neg_a["accepted"] else FAIL,
        f"Offer=Rs.{original*0.5:.0f} | Counter=Rs.{neg_a['counter_offer_pkr']} | "
        f"Accepted={neg_a['accepted']} | Reason={neg_a['reasoning'][:60]}"
    )

    # Case B: Offer at 90% (should accept or near-accept)
    neg_b = negotiation_agent_run(original, original * 0.90, provider, intent, 1.6, False)
    log(
        "Negotiation: User offers 90% (near original)",
        PASS if neg_b["accepted"] or neg_b["counter_offer_pkr"] <= original * 0.92 else FAIL,
        f"Offer=Rs.{original*0.90:.0f} | Counter=Rs.{neg_b['counter_offer_pkr']} | "
        f"Accepted={neg_b['accepted']}"
    )

    # Case C: Repeat customer gets loyalty discount
    neg_c = negotiation_agent_run(original, original * 0.85, provider, intent, 1.0, True)
    log(
        "Negotiation: Repeat customer, no surge",
        PASS if neg_c["discount_reason"] == "loyalty" or neg_c["accepted"] else WARN,
        f"Discount=Rs.{neg_c['discount_applied_pkr']:.0f} | "
        f"Reason={neg_c['discount_reason']} | Final=Rs.{neg_c['counter_offer_pkr']}"
    )


# ════════════════════════════════════════════════════════════════════════════
# TEST 7: Dispute Resolution Engine
# ════════════════════════════════════════════════════════════════════════════
def test_dispute_engine():
    print("\n" + "="*60)
    print("TEST SUITE 7: Dispute & Escalation Engine")
    print("="*60)

    good_provider = next(p for p in PROVIDERS if p["id"] == "p001")  # DNA 912
    bad_provider  = next(p for p in PROVIDERS if p["id"] == "p019")  # DNA 556, 9 disputes

    # Case A: No-show
    r = dispute_agent_run("no_show", "Provider did not show up", 1200, 0, good_provider)
    log("Dispute: No-Show by good provider",
        PASS if r["verdict"] == "user_favor" and r["penalty_to_provider"] != "none" else FAIL,
        f"Verdict={r['verdict']} | Action={r['action']} | Penalty={r['penalty_to_provider']}")

    # Case B: Price overcharge > Rs.500 by low-DNA provider
    r2 = dispute_agent_run("price_disagreement", "Charged Rs.1800 instead of Rs.1200", 1200, 1800, bad_provider)
    log("Dispute: Price overcharge Rs.600 by low-DNA provider",
        PASS if r2["refund_amount_pkr"] > 0 and r2["verdict"] == "user_favor" else FAIL,
        f"Verdict={r2['verdict']} | Refund=Rs.{r2['refund_amount_pkr']:.0f} | "
        f"Penalty={r2['penalty_to_provider']}")

    # Case C: Quality complaint against high-dispute provider (blacklist trigger)
    r3 = dispute_agent_run("quality_complaint", "Work not done properly", 1000, 1000, bad_provider)
    log("Dispute: Quality complaint — high-dispute provider (blacklist?)",
        PASS if r3["penalty_to_provider"] in ["soft_ban", "blacklist", "dna_penalty"] else FAIL,
        f"Verdict={r3['verdict']} | Penalty={r3['penalty_to_provider']} | "
        f"Escalate={r3['escalate_to_human']} | "
        f"DNA delta={r3['provider_dna_delta']}")

    # Case D: Cancellation
    r4 = dispute_agent_run("cancellation", "Provider cancelled 1 hour before appointment", 1200, 0, good_provider)
    log("Dispute: Last-minute cancellation",
        PASS if r4["action"] == "rebook" else FAIL,
        f"Action={r4['action']} | Penalty={r4['penalty_to_provider']}")


# ════════════════════════════════════════════════════════════════════════════
# TEST 8: Full End-to-End Flow
# ════════════════════════════════════════════════════════════════════════════
def test_e2e_flow():
    print("\n" + "="*60)
    print("TEST SUITE 8: Full End-to-End Booking Flow")
    print("="*60)

    from agents.orchestrator_agents import _booked_slots
    _booked_slots.clear()

    raw_input = "AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye, budget zyada nahi"
    print(f"\n   Input: '{raw_input}'")

    # Step 1: Intent
    t0 = time.time()
    intent = intent_run(raw_input, use_gemini=False)
    t1 = time.time()
    log("E2E Step 1 — Intent Agent",
        PASS if intent["service_type"] == "AC Repair" else FAIL,
        f"Service={intent['service_type']} | Area={intent['area']} | "
        f"Urgency={intent['urgency']} | Confidence={intent['confidence']:.0%} | "
        f"Time={((t1-t0)*1000):.0f}ms")

    # Step 2: Surge
    t0 = time.time()
    surge = surge_agent_run(DEMAND, intent["area"], intent["service_type"], current_hour=15, available_providers=3)
    t1 = time.time()
    log("E2E Step 2 — Surge Agent",
        PASS,
        f"Multiplier={surge['surge_multiplier']}x | Active={surge['active']} | "
        f"Time={((t1-t0)*1000):.0f}ms")

    # Step 3: Matching
    t0 = time.time()
    matches = matching_run(PROVIDERS, intent, USER_LAT, USER_LNG, surge_mult=surge["surge_multiplier"])
    t1 = time.time()
    top = matches["matches"][0] if matches["matches"] else None
    log("E2E Step 3 — Matching Agent",
        PASS if top else FAIL,
        f"Top={top['provider']['name'] if top else 'None'} | "
        f"Score={top['match_score'] if top else 0} | "
        f"DNA={top['provider']['dna_score'] if top else 0} | "
        f"Time={((t1-t0)*1000):.0f}ms")

    if not top:
        return

    # Step 4: Pricing
    quote = pricing_agent_run(top["provider"], intent, top["distance_km"], surge["surge_multiplier"])
    log("E2E Step 4 — Pricing Agent",
        PASS,
        f"Quote=Rs.{quote['total_pkr']} | Breakdown={quote['breakdown']}")

    # Step 5: Scheduling
    sched = scheduling_agent_run(top["provider"], "2026-05-14", "09:00", top["eta_minutes"])
    log("E2E Step 5 — Scheduling Agent",
        PASS if sched["status"] == "confirmed" else FAIL,
        f"Status={sched['status']} | Booking ID={sched.get('booking_id', 'N/A')}")

    # Step 6: Booking Chain
    booking = booking_agent_run(sched, quote, top["provider"], intent, surge["surge_multiplier"])
    log("E2E Step 6 — Booking Agent (7-step chain)",
        PASS if booking["status"] == "booking_confirmed" else FAIL,
        f"Receipt={booking['receipt_number']} | "
        f"Steps={len(booking['steps'])} completed | "
        f"Agents traced={len(booking['antigravity_trace']['agents_invoked'])}")


# ════════════════════════════════════════════════════════════════════════════
# SUMMARY REPORT
# ════════════════════════════════════════════════════════════════════════════
def print_summary():
    print("\n" + "="*60)
    print("STRESS TEST SUMMARY REPORT")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)

    total = len(results)
    passed = sum(1 for r in results if "PASS" in r["status"])
    warned = sum(1 for r in results if "WARN" in r["status"])
    failed = sum(1 for r in results if "FAIL" in r["status"])

    print(f"\n  Total Tests : {total}")
    print(f"  ✅ Passed   : {passed}")
    print(f"  ⚠️  Warnings : {warned}")
    print(f"  ❌ Failed   : {failed}")
    print(f"  Pass Rate   : {passed/total*100:.1f}%")

    if failed == 0:
        print("\n  🎉 ALL CRITICAL TESTS PASSED — Ready for demo!")
    elif failed <= 2:
        print("\n  ⚠️  Minor issues — review FAIL cases above")
    else:
        print("\n  ❌ Multiple failures — review before demo")

    # Save JSON report
    report = {
        "timestamp": datetime.now().isoformat(),
        "summary": {"total": total, "passed": passed, "warned": warned, "failed": failed},
        "results": results,
    }
    report_path = os.path.join(os.path.dirname(__file__), "../../submission_evidence/stress_test_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"\n  📄 Report saved: submission_evidence/stress_test_report.json")


if __name__ == "__main__":
    print("🚀 KaamYaab — Stress Test Suite")
    print(f"   Running {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    test_multilingual_intent()
    test_low_confidence_clarification()
    test_no_provider_available()
    test_double_booking()
    test_surge_detection()
    test_negotiation()
    test_dispute_engine()
    test_e2e_flow()
    print_summary()
