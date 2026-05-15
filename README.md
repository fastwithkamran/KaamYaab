# AI Service Orchestrator for the Informal Economy

> An agentic, end-to-end service lifecycle platform for informal-economy professionals — plumbers, electricians, AC technicians, tutors, beauticians, drivers, mechanics, and local service providers — powered by **Google Antigravity** as the core orchestrator.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Tech Stack and APIs](#3-tech-stack-and-apis)
4. [Google Antigravity Integration and Workflow](#4-google-antigravity-integration-and-workflow)
5. [Provider Dataset Schema](#5-provider-dataset-schema)
6. [Multilingual and Noisy Input Handling](#6-multilingual-and-noisy-input-handling)
7. [Advanced Provider Matching Algorithm](#7-advanced-provider-matching-algorithm)
8. [Job Complexity Classification](#8-job-complexity-classification)
9. [Scheduling Intelligence](#9-scheduling-intelligence)
10. [Dynamic Pricing Engine](#10-dynamic-pricing-engine)
11. [Booking Simulation](#11-booking-simulation)
12. [Service-Quality Loop](#12-service-quality-loop)
13. [Dispute and Escalation Workflow](#13-dispute-and-escalation-workflow)
14. [Provider-Side Optimization](#14-provider-side-optimization)
15. [Robustness and Fallback Mechanisms](#15-robustness-and-fallback-mechanisms)
16. [Stress-Test Scenarios](#16-stress-test-scenarios)
17. [Assumptions](#17-assumptions)
18. [Cost and Latency Analysis](#18-cost-and-latency-analysis)
19. [Baseline Comparison](#19-baseline-comparison)
20. [Privacy Note](#20-privacy-note)
21. [Limitations](#21-limitations)
22. [Judge Verification: Proving Antigravity Usage](#22-judge-verification-proving-antigravity-usage)

---

## 1. Project Overview

The informal service economy in South Asia and similar markets relies on fragmented discovery channels: WhatsApp forwards, phone-tree referrals, and word-of-mouth networks. This produces:

- Unpredictable and opaque pricing
- No verifiable provider ratings or history
- Missed appointments and zero follow-up
- No dispute resolution mechanism
- Complete exclusion of low-literacy or non-English-speaking users

This system automates the **entire service lifecycle** — from a natural-language request in Urdu, Roman Urdu, or mixed code-switched text, through provider matching, dynamic pricing, booking, live tracking simulation, feedback collection, reputation update, and dispute handling — all orchestrated by **Google Antigravity**.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│   Mobile App (React Native / Flutter)  ·  Web App (optional)   │
└───────────────────────────┬─────────────────────────────────────┘
                            │  Natural-language input
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              GOOGLE ANTIGRAVITY ORCHESTRATOR                    │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │ Intent Agent │  │ Matching     │  │ Scheduling Agent      │ │
│  │ (NLU + lang  │  │ Agent        │  │ (calendar, buffers,   │ │
│  │  detection)  │  │ (6+ factors) │  │  conflict detection)  │ │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬────────────┘ │
│         │                 │                      │              │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────────▼────────────┐ │
│  │ Pricing      │  │ Booking      │  │ Quality & Dispute      │ │
│  │ Agent        │  │ Agent        │  │ Agent                  │ │
│  │ (dynamic     │  │ (confirm,    │  │ (feedback, escalation, │ │
│  │  quotes)     │  │  notify,     │  │  refund, blacklist)    │ │
│  └──────────────┘  │  receipt)    │  └───────────────────────┘ │
│                    └──────────────┘                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │  Tool calls
          ┌───────────────────┼──────────────────────┐
          ▼                   ▼                      ▼
  ┌───────────────┐  ┌────────────────┐  ┌──────────────────────┐
  │ Haversine     │  │ Provider DB /  │  │ In-App Notification  │
  │ Distance Calc │  │ Mock Dataset   │  │ (Toast / Modal sim)  │
  │ (no Maps API) │  │ (static JSON)  │  │ (in-app only)        │
  └───────────────┘  └────────────────┘  └──────────────────────┘
```

### Component Responsibilities

| Component | Responsibility |
|---|---|
| **Intent Agent** | Language detection, entity extraction, confidence scoring, confirmation dialogs |
| **Matching Agent** | Multi-factor provider ranking, tie-breaking, fallback discovery |
| **Scheduling Agent** | Slot availability, conflict detection, travel-time buffers, waitlists |
| **Pricing Agent** | Dynamic quote generation, discount application, transparent breakdown |
| **Booking Agent** | Confirmation, assignment, calendar update, in-app notification simulation, receipt |
| **Quality & Dispute Agent** | En-route simulation, feedback collection, rating update, dispute resolution |

---

## 3. Tech Stack and APIs

> **Cost policy:** This prototype is designed to run entirely within the free tiers of every service used. No paid API calls are made. All components listed below are either free-tier or fully mocked for demo purposes.

| Layer | Technology / Service | Cost |
|---|---|---|
| **Orchestration** | Google Antigravity (hackathon-provided) | Free |
| **Mobile App** | React Native (mandatory) / Flutter | Free |
| **Web App** | React + Next.js (optional) | Free |
| **NLU / LLM** | Google Gemini 1.5 Flash — free tier (15 req/min, 1M tokens/day) | Free |
| **Provider Discovery** | Static mock dataset (JSON) + local Haversine distance calculation — no Maps API calls | Free |
| **Distance / Travel Time** | Haversine formula on provider `GeoPoint` coordinates stored in mock data — no external maps API | Free |
| **Notifications** | Fully simulated in-app (toast / bottom-sheet modal) — no third-party notification API | Free |
| **Database** | Firebase Firestore — Spark free plan (50K reads/day, 20K writes/day) | Free |
| **Spreadsheet Logging** | Google Sheets API — included free with GCP | Free |
| **Auth** | Firebase Auth — free tier | Free |
| **Hosting** | Google Cloud Run — 2M requests/month free tier | Free |
| **GCP Budget** | Not required for this prototype | $0 |

### Why no Google Maps API?
For the prototype, all 50–200 providers have pre-seeded `GeoPoint` coordinates. Distance between user and provider is calculated client-side using the Haversine formula (accurate to ~0.5%). This removes the need for external maps API calls entirely, costs nothing, and works offline.

---

## 4. Google Antigravity Integration and Workflow

Google Antigravity acts as the **sole decision-making spine** of the system. Every major agentic action is triggered, reasoned about, and logged through Antigravity. External LLMs, APIs, and databases are tools that Antigravity calls — they do not control workflow logic.

### 4.1 Antigravity Agent Workflow (Step-by-Step)

```
Step 1  USER INPUT
        │  Raw text → Antigravity Intent Agent
        │  Output: structured intent JSON + confidence score
        ▼
Step 2  CONFIRMATION GATE
        │  If confidence < 0.75 → agent issues clarification question
        │  If confidence ≥ 0.75 → proceed
        ▼
Step 3  PROVIDER DISCOVERY
        │  Intent Agent hands off to Matching Agent
        │  Matching Agent queries static mock Provider DB
        │  Haversine distance calculated locally for each candidate
        │  Builds candidate list (up to 20 providers)
        ▼
Step 4  MULTI-FACTOR RANKING
        │  Matching Agent scores each candidate across 10 factors
        │  Generates ranking rationale trace (see §4.2)
        │  Selects top-3 recommendations
        ▼
Step 5  COMPLEXITY CLASSIFICATION
        │  Job classified as Basic / Intermediate / Complex
        │  Matching Agent verifies provider certification/tools match complexity
        ▼
Step 6  SCHEDULING CHECK
        │  Scheduling Agent queries provider calendars
        │  Checks travel-time buffers from previous appointment
        │  Confirms or suggests alternate slots
        ▼
Step 7  DYNAMIC PRICING
        │  Pricing Agent computes quote with full breakdown
        │  Applies surge, urgency, loyalty adjustments
        │  Presents user-facing and provider-facing figures
        ▼
Step 8  BOOKING EXECUTION
        │  Booking Agent confirms slot, locks provider calendar
        │  Dispatches in-app notifications to user and provider
        │  Writes booking record to DB + audit sheet
        ▼
Step 9  SERVICE EXECUTION LOOP
        │  En-route simulation → arrival → checklist → completion
        │  Evidence placeholder (photo/video upload prompt)
        ▼
Step 10 FEEDBACK AND REPUTATION
        │  User submits rating (1–5) + text
        │  Quality Agent updates provider score
        │  Future match scores recalculated
        ▼
Step 11 DISPUTE HANDLING (if triggered)
        │  Dispute Agent classifies dispute type
        │  Applies resolution policy
        │  Escalates to human operator if unresolved
```

### 4.2 Antigravity Reasoning Trace Format

Every major decision emits a structured trace log:

```json
{
  "trace_id": "agx-20240515-00342",
  "stage": "provider_ranking",
  "timestamp": "2024-05-15T09:12:44Z",
  "input_summary": {
    "service": "AC Repair",
    "location": "G-13, Islamabad",
    "urgency": "high",
    "time_requested": "tomorrow 09:00–12:00",
    "budget_sensitivity": "high"
  },
  "candidates_evaluated": 12,
  "ranking": [
    {
      "rank": 1,
      "provider_id": "PRV-0041",
      "name": "Zia AC Services",
      "composite_score": 87.4,
      "rationale": "Highest AC-specialization score (0.96), on-time rate 94%, 3 recent 5-star reviews mentioning gas refill. Slight distance penalty offset by reliability premium.",
      "factors": {
        "distance_score": 72,
        "availability_score": 95,
        "rating_score": 88,
        "review_recency_score": 91,
        "reliability_score": 94,
        "specialization_score": 96,
        "price_fit_score": 80,
        "cancellation_risk": 5,
        "capacity_score": 100,
        "user_preference_match": 85
      }
    },
    {
      "rank": 2,
      "provider_id": "PRV-0019",
      "name": "Quick Cool Tech",
      "composite_score": 79.1,
      "rationale": "Closest provider but on-time rate only 71% and one cancellation in last 14 days. Deprioritized given high urgency."
    }
  ],
  "decision": "Recommend PRV-0041 (Zia AC Services) despite PRV-0019 being 2.1 km closer. Reliability and specialization outweigh proximity for high-urgency AC repair.",
  "fallback_ready": true,
  "fallback_provider": "PRV-0007"
}
```

Traces are produced for: **language parsing, provider ranking, scheduling conflict resolution, price calculation, booking confirmation, dispute escalation, and fallback activation.**

---

## 5. Provider Dataset Schema

### 5.1 Provider Record

| Field | Type | Description |
|---|---|---|
| `provider_id` | `string` | Unique identifier (e.g., `PRV-0041`) |
| `name` | `string` | Full business or individual name |
| `phone` | `string` | WhatsApp-capable contact number |
| `services` | `string[]` | List of offered services (e.g., `["AC Repair", "AC Installation"]`) |
| `specializations` | `object` | Per-service specialization score `0.0–1.0` |
| `location` | `GeoPoint` | GPS coordinates of base location |
| `service_radius_km` | `float` | Maximum travel radius |
| `base_rate_pkr` | `float` | Starting hourly or per-job rate (PKR) |
| `rating` | `float` | Weighted average rating `1.0–5.0` |
| `review_count` | `int` | Total reviews received |
| `last_review_date` | `date` | Date of most recent review |
| `on_time_rate` | `float` | Fraction of jobs completed on time `0.0–1.0` |
| `cancellation_rate` | `float` | Fraction of accepted jobs later cancelled `0.0–1.0` |
| `experience_years` | `int` | Years of active service |
| `certifications` | `string[]` | Relevant certifications (e.g., `["HVAC Level 2"]`) |
| `tools_owned` | `string[]` | Key tools/equipment available |
| `availability` | `object` | Weekly schedule with time slots |
| `active_bookings` | `int` | Current confirmed bookings (capacity check) |
| `max_daily_jobs` | `int` | Self-reported daily job cap |
| `risk_score` | `float` | Composite risk indicator `0.0–1.0` (lower = safer) |
| `loyalty_tier` | `enum` | `new / standard / preferred / elite` |
| `preferred_by_users` | `string[]` | User IDs who have marked this provider as preferred |
| `blacklisted` | `boolean` | Whether provider is currently suspended |
| `dispute_count` | `int` | Total disputes raised against provider |
| `last_dispute_date` | `date` | Date of most recent dispute |
| `demand_forecast_score` | `float` | Predicted demand in provider's area for next 7 days |
| `created_at` | `timestamp` | Profile creation date |
| `updated_at` | `timestamp` | Last profile update |

### 5.2 Booking Record

| Field | Type | Description |
|---|---|---|
| `booking_id` | `string` | Unique booking reference (e.g., `BK-20240515-0091`) |
| `user_id` | `string` | Customer identifier |
| `provider_id` | `string` | Assigned provider |
| `service_type` | `string` | Service requested |
| `complexity` | `enum` | `basic / intermediate / complex` |
| `location` | `GeoPoint + string` | Service address |
| `scheduled_start` | `datetime` | Confirmed appointment start |
| `scheduled_end` | `datetime` | Estimated appointment end |
| `status` | `enum` | `pending / confirmed / en_route / in_progress / completed / cancelled / disputed` |
| `quoted_price_pkr` | `float` | Price shown to user at booking |
| `final_price_pkr` | `float` | Actual price after completion |
| `pricing_breakdown` | `object` | Itemized pricing components |
| `confirmation_sent` | `boolean` | Whether confirmation SMS/WhatsApp was dispatched |
| `reminder_sent` | `boolean` | Whether reminder was dispatched |
| `user_rating` | `int` | Post-service rating `1–5` |
| `user_feedback_text` | `string` | Free-text review |
| `dispute_id` | `string` | Linked dispute record (if any) |
| `antigravity_trace_id` | `string` | Reference to Antigravity reasoning trace |
| `created_at` | `timestamp` | Booking creation time |

### 5.3 Dispute Record

| Field | Type | Description |
|---|---|---|
| `dispute_id` | `string` | Unique dispute identifier |
| `booking_id` | `string` | Linked booking |
| `raised_by` | `enum` | `user / provider` |
| `type` | `enum` | `no_show / quality / price_disagreement / overrun / cancellation / other` |
| `description` | `string` | Free-text description |
| `status` | `enum` | `open / under_review / resolved / escalated / closed` |
| `resolution` | `string` | Resolution action taken |
| `refund_amount_pkr` | `float` | Refund issued (if any) |
| `compensation_pkr` | `float` | Compensation to user (if any) |
| `escalated_to_human` | `boolean` | Whether human operator involved |
| `created_at` | `timestamp` | Dispute raised time |
| `resolved_at` | `timestamp` | Resolution time |

### 5.4 Sample Provider Records (Mock Dataset Extract)

```json
[
  {
    "provider_id": "PRV-0041",
    "name": "Zia AC Services",
    "services": ["AC Repair", "AC Installation", "AC Gas Refill"],
    "specializations": { "AC Repair": 0.96, "AC Installation": 0.88 },
    "location": { "lat": 33.6938, "lng": 73.0651 },
    "service_radius_km": 12,
    "base_rate_pkr": 1200,
    "rating": 4.7,
    "on_time_rate": 0.94,
    "cancellation_rate": 0.03,
    "experience_years": 9,
    "certifications": ["HVAC Level 2"],
    "risk_score": 0.07,
    "blacklisted": false
  },
  {
    "provider_id": "PRV-0019",
    "name": "Quick Cool Tech",
    "services": ["AC Repair", "Refrigerator Repair"],
    "specializations": { "AC Repair": 0.74 },
    "location": { "lat": 33.7100, "lng": 73.0550 },
    "service_radius_km": 8,
    "base_rate_pkr": 900,
    "rating": 4.1,
    "on_time_rate": 0.71,
    "cancellation_rate": 0.12,
    "experience_years": 4,
    "certifications": [],
    "risk_score": 0.28,
    "blacklisted": false
  }
]
```

---

## 6. Multilingual and Noisy Input Handling

### 6.1 Supported Input Modes

| Mode | Example |
|---|---|
| Pure Urdu (Nastaliq) | `کل صبح جی تیرہ میں اے سی ٹھیک کروانا ہے` |
| Roman Urdu | `Kal subah G-13 mein AC theek karwana hai` |
| English | `I need an AC technician tomorrow morning in G-13` |
| Code-switched | `AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai` |
| Noisy / misspelled | `ac thecnician chal gya g13 kl subha plss` |

### 6.2 Intent Extraction Fields

The Intent Agent extracts and returns:

```json
{
  "service_type": "AC Repair",
  "service_subtype": "breakdown / not cooling / gas / installation",
  "issue_severity": "high",
  "location_raw": "G-13",
  "location_resolved": { "lat": 33.6938, "lng": 73.0651, "area": "G-13, Islamabad" },
  "time_preference": "tomorrow morning",
  "time_resolved": "2024-05-16T09:00:00+05:00",
  "budget_sensitivity": "high",
  "user_language": "roman_urdu + urdu_mixed",
  "confidence_score": 0.91,
  "ambiguities": [],
  "confirmation_required": false
}
```

### 6.3 Confidence Score Thresholds

| Score | Action |
|---|---|
| ≥ 0.90 | Proceed directly |
| 0.75 – 0.89 | Soft confirmation: "کیا آپ کا مطلب کل صبح 9 بجے G-13 میں AC repair ہے?" |
| 0.60 – 0.74 | Mandatory confirmation with slot selection shown |
| < 0.60 | Full re-prompt: "ہم آپ کی request سمجھ نہیں پائے — براہ کرم دوبارہ بتائیں" |

### 6.4 Handling Strategies for Noise

- **Phonetic normalization:** `thecnician → technician`, `kl → kal`, `plss → please`
- **Transliteration mapping:** Roman Urdu tokens mapped to canonical Urdu intent labels
- **Contextual slot-filling:** Missing fields (e.g., no time mentioned) trigger targeted follow-up questions rather than full re-parse
- **Slang dictionary:** Maintains a domain-specific dictionary of common informal-economy slang (`chai pani = tip expectation`, `jugaar = improvised fix`)

---

## 7. Advanced Provider Matching Algorithm

### 7.1 Scoring Factors (10 Factors)

| # | Factor | Weight | Description |
|---|---|---|---|
| 1 | **Distance / Travel Time** | 12% | Estimated from Haversine distance with `distance_km / 30` hours; penalizes >30 min |
| 2 | **Availability** | 15% | Slot open in requested window with travel-time buffer |
| 3 | **Rating** | 12% | Weighted average, decays older reviews |
| 4 | **Review Recency** | 8% | Recency-weighted sentiment of last 10 reviews |
| 5 | **On-Time Reliability** | 14% | Historical fraction of on-time arrivals |
| 6 | **Skill Specialization** | 15% | Specialization score for the exact service requested |
| 7 | **Price Fit** | 8% | Alignment between provider rate and user's stated budget sensitivity |
| 8 | **Cancellation Risk** | 8% | Inverse of cancellation rate; recent cancellations penalized more |
| 9 | **Capacity** | 4% | Available slots relative to max daily jobs |
| 10 | **User Preference** | 4% | Boost if user has used this provider before or marked as preferred |

### 7.2 Composite Score Formula

```
composite_score = Σ (factor_score_i × weight_i)   for i = 1..10

Where factor_score_i ∈ [0, 100]
```

### 7.3 Tie-Breaking Rules

1. Higher on-time reliability wins
2. If equal, lower cancellation rate wins
3. If equal, more recent positive review wins

### 7.4 Override Conditions

- Provider is **blacklisted** → excluded from all results
- Provider has **≥3 disputes in last 30 days** → excluded
- Provider has **active cancellation in last 24h** → `cancellation_risk` score forced to 0
- User has **explicitly blocked** provider → excluded

---

## 8. Job Complexity Classification

| Complexity | Criteria | Provider Requirements |
|---|---|---|
| **Basic** | Routine maintenance, filter cleaning, minor adjustments | ≥1 year experience, standard tools |
| **Intermediate** | Gas refill, component replacement, fault diagnosis | ≥3 years experience, refrigerant handling certification |
| **Complex** | Full unit replacement, wiring overhaul, multi-unit installation | ≥5 years, HVAC Level 2+ certification, specialized equipment |

The Matching Agent verifies that the shortlisted provider's `certifications` and `tools_owned` satisfy the detected complexity level. Providers who do not meet the threshold are demoted or excluded, with a trace note.

---

## 9. Scheduling Intelligence

### 9.1 Slot Validation Rules

- No overlapping bookings for the same provider
- Minimum **30-minute travel buffer** inserted between consecutive jobs (using local Haversine travel-time estimates)
- Provider must not exceed `max_daily_jobs` cap
- Scheduled end time includes a **15-minute buffer** for handover

### 9.2 Conflict Scenarios and Responses

| Scenario | System Response |
|---|---|
| Requested slot taken | Suggest next 3 available slots from same provider |
| All top-3 providers unavailable | Expand radius by 5 km and re-rank; notify user of extended options |
| Provider cancels after confirmation | Scheduling Agent triggers immediate re-matching; user notified within 2 min |
| Two simultaneous bookings for same provider | First-commit wins (DB transaction lock); second user is offered next best provider |
| Provider running late | Send updated ETA notification; offer user option to reschedule |

### 9.3 Waitlist Management

If no provider is available in the requested window, the user is added to a **priority waitlist** for that service type and area. When a cancellation or new provider availability opens up, Antigravity's Scheduling Agent automatically re-evaluates and notifies the next user on the waitlist.

---

## 10. Dynamic Pricing Engine

### 10.1 Pricing Formula

```
final_quote = base_rate
            + distance_charge
            + complexity_surcharge
            + urgency_premium
            + demand_surge
            - loyalty_discount
            - budget_adjustment
```

### 10.2 Component Definitions

| Component | Calculation |
|---|---|
| `base_rate` | Provider's per-job base rate (PKR) |
| `distance_charge` | PKR 15 per km beyond 5 km threshold |
| `complexity_surcharge` | Basic: 0% · Intermediate: +20% · Complex: +40% |
| `urgency_premium` | Same-day: +25% · Next-morning: +10% · 48h+: 0% |
| `demand_surge` | 0–35% based on real-time request density in area |
| `loyalty_discount` | New: 0% · Standard: −5% · Preferred: −10% · Elite: −15% |
| `budget_adjustment` | If `budget_sensitivity = high`, system surfaces lowest-scoring acceptable provider as budget alternative |

### 10.3 User-Facing Breakdown (Sample)

```
Zia AC Services — Quote for AC Repair
──────────────────────────────────────
Base rate (visit + diagnosis)    PKR  1,200
Distance charge (7 km)           PKR    105
Complexity (Intermediate)        PKR    240
Next-morning urgency             PKR    154
Demand (moderate area demand)    PKR     80
Loyalty discount (Standard)      PKR    −87
──────────────────────────────────────
TOTAL ESTIMATE                   PKR  1,692
Range: PKR 1,500 – 2,100 (final depends on parts)
```

### 10.4 Provider-Facing Payout

The system also shows the provider their expected net payout, platform fee deduction, and any bonus for high-demand slots — ensuring pricing transparency for both parties.

---

## 11. Booking Simulation

### 11.1 Booking Flow

```
1. User confirms quote and slot
2. Booking Agent acquires DB transaction lock on provider's calendar slot
3. Booking record created with status: confirmed
4. Provider calendar updated (slot blocked)
5. In-app notification dispatched to user (booking ID, provider name, time, price)
6. In-app notification dispatched to provider (job details, location pin, user contact)
7. PDF/text receipt generated and sent to user
8. Booking entry written to Google Sheets audit log
9. Reminder scheduled (24h before and 1h before)
10. Antigravity Booking Agent emits confirmation trace
```

### 11.2 Confirmation Notification (Simulated In-App)

```
[SAAS Platform] Booking Confirmed!
Service: AC Repair
Provider: Zia AC Services
Date: 16 May 2024, 10:00 AM
Location: G-13, Islamabad
Estimate: PKR 1,692
Booking ID: BK-20240515-0091
Track your booking: [link]
```

---

## 12. Service-Quality Loop

| Stage | Action |
|---|---|
| **En Route** | Provider marks "heading to job"; user receives live ETA (simulated) |
| **Arrival** | Provider marks "arrived"; timestamp recorded |
| **In Progress** | Service checklist presented to provider (e.g., filter checked ✓, refrigerant level ✓) |
| **Evidence** | Provider prompted to upload photo/video of completed work (placeholder in prototype) |
| **Completion** | Provider marks job complete; user notified |
| **Feedback** | User prompted for 1–5 star rating + optional text within 30 min of completion |
| **Reputation Update** | Antigravity Quality Agent recalculates provider's rating, on-time score, and risk score |
| **Matching Impact** | Updated scores immediately reflected in future ranking traces |

---

## 13. Dispute and Escalation Workflow

### 13.1 Dispute Types and Initial Responses

| Dispute Type | Automated Response |
|---|---|
| **No-show** | Verify provider GPS (simulated); if confirmed absent → full refund + PKR 200 compensation; provider `no_show_count` incremented |
| **Quality complaint** | Request evidence (photo/video); Antigravity Quality Agent evaluates against checklist; partial refund if validated |
| **Price disagreement** | Compare final charge against quoted range; if overcharge confirmed → refund delta |
| **Overrun (time)** | Log overrun; if >60 min beyond estimate → trigger review; provider profiled |
| **Cancellation (provider)** | Auto-reroute to next best provider; user notified; provider `cancellation_rate` updated |
| **Cancellation (user, late)** | PKR 200 cancellation fee applied if within 2h of appointment |
| **Refund request** | Assessed by Quality Agent; refund issued via original payment method within 48h |

### 13.2 Escalation Ladder

```
Level 1: Antigravity Quality Agent automated resolution (0–4 hours)
Level 2: AI-assisted human review (4–24 hours) — triggered if:
         - Dispute value > PKR 5,000
         - Provider has ≥ 2 disputes in 30 days
         - User or provider requests human review
Level 3: Senior operator + possible blacklist decision (24–72 hours)
```

### 13.3 Blacklist and Reinstatement

- Providers with `cancellation_rate > 0.25` AND `dispute_count ≥ 5` in 60 days are automatically flagged for review
- Blacklist decision requires human confirmation at Level 3
- Reinstatement possible after 90-day cooling period with new onboarding review

---

## 14. Provider-Side Optimization

### 14.1 Workload Balancing

The Matching Agent enforces a **fair opportunity score** — providers with fewer recent bookings receive a small composite-score boost (up to +5 points) to prevent monopolization by top-rated providers. This decays as bookings accumulate.

### 14.2 Demand Forecasting

Antigravity's Pricing Agent maintains a rolling 7-day demand signal per service type and area. Providers are notified of predicted high-demand windows with a push notification: *"High AC repair demand expected in G-13 on Saturday morning — set your availability to capture bookings."*

### 14.3 Recommended Availability Slots

Based on historical booking patterns, the system recommends optimal working-hour slots to providers each week, maximizing utilization and reducing idle time.

### 14.4 Earnings Transparency

Each provider's dashboard shows: confirmed earnings this week, pending jobs, expected payout for each slot, platform fee, and comparison to their own 30-day average — promoting trust and long-term engagement.

---

## 15. Robustness and Fallback Mechanisms

| Failure Mode | Fallback Strategy |
|---|---|
| **No provider available** | Expand search radius (+5 km increments up to 3×); offer waitlist; suggest next available date |
| **Distance computation issue** | Fall back to local Haversine distance using stored `GeoPoint`; flag reduced accuracy in trace |
| **Low-confidence language parse** | Trigger slot-by-slot clarification dialog; never fail silently |
| **Payment confirmation failure** | Hold booking in `pending_payment` state for 10 min; release slot if unresolved |
| **Provider no-show** | Auto-reroute within 15 min; compensate user; escalate dispute |
| **Double-booking race condition** | DB transaction lock ensures atomicity; losing request receives immediate next-best offer |
| **User preference conflicts** | Surface conflict explicitly: *"Your preferred provider is unavailable — would you like the next best match or to wait?"* |
| **Antigravity agent timeout** | Retry with exponential backoff ×3; if all fail, surface graceful error with manual booking option |
| **Notification delivery failure** | Retry as in-app toast/bottom-sheet and log delivery status in booking record |

---

## 16. Stress-Test Scenarios

### Scenario 1 — Zero Provider Availability

**Input:** User requests AC repair for today between 2–4 PM in a low-density area.

**System behavior:** Antigravity Matching Agent finds zero providers available in the window. Expands radius in 5 km steps. If still no match at 25 km, adds user to waitlist, shows next available slot (tomorrow 10 AM), and sends a notification when a cancellation opens up.

**Trace output:** `fallback_activated: radius_expansion → waitlist_enrolled → next_slot_suggested`

---

### Scenario 2 — Provider Cancels After Confirmation

**Input:** Provider cancels 30 minutes before the 10 AM appointment.

**System behavior:** Scheduling Agent detects cancellation event, immediately re-runs Matching Agent on remaining providers with availability in the 10–12 AM window. New provider assigned, new confirmation sent to user within 2 minutes. Original provider's `cancellation_rate` updated. If this is their third late cancellation in 30 days, a Level 2 review flag is raised.

---

### Scenario 3 — Misspelled, Mixed-Language, Ambiguous Input

**Input:** `"ac thecnician chal gya g13 kl subha plss budget thora kam rakhna"`

**System behavior:** Intent Agent applies phonetic normalization (`thecnician → technician`, `kl → kal`). Detects Roman Urdu + English mix. Extracts: service = AC Repair, issue = broken/stopped, location = G-13, time = tomorrow morning, budget = low. Confidence = 0.82. Soft confirmation issued: *"کیا آپ کو کل صبح G-13 میں AC repair چاہیے، کم بجٹ میں؟"* User confirms → proceed.

---

### Scenario 4 — Two Users Book Same Last-Available Provider Simultaneously

**Input:** User A and User B both attempt to book PRV-0041 for 10 AM tomorrow at the exact same second.

**System behavior:** Booking Agent uses a DB transaction lock. User A's request commits first (milliseconds earlier). User B's transaction detects the locked slot, immediately re-runs Scheduling Agent, and is offered the next best provider (PRV-0007, score 74.2) with a new quote. Both users receive their respective confirmations. Race condition is logged in audit trail.

---

### Scenario 5 — Customer Disputes Price or Quality After Completion

**Input:** User complains that the provider charged PKR 3,500 but the quote said PKR 1,692, and the AC is still not cooling.

**System behavior:** Dispute Agent opens a `price_disagreement + quality` dispute. Requests photo evidence from user. Compares final charge (PKR 3,500) against quoted range (PKR 1,500–2,100) — overcharge confirmed. Issues PKR 1,400 refund (delta). Quality complaint sent to Level 2 review because it combines both types. Provider's `dispute_count` and `risk_score` updated. User receives refund confirmation within 48h.

---

### Scenario 6 — High-Rated Provider with Recent Negative Reviews and High Cancellation Rate

**Input:** Provider PRV-0055 has a 4.6 overall rating but 3 one-star reviews in the last 7 days and a cancellation rate that jumped from 0.05 to 0.19 this month.

**System behavior:** Antigravity Matching Agent applies **review recency decay** — the 3 recent one-star reviews pull the effective recency-weighted score to 3.1. The elevated cancellation rate drops the cancellation-risk score. Composite score falls from a nominal 84 to 61, pushing PRV-0055 to rank 4. Trace note: *"Deprioritized PRV-0055: recency-adjusted rating 3.1, elevated cancellation risk (0.19). Flagged for Level 2 monitoring."* The provider is not shown as a top recommendation until scores recover over 14 days.

---

## 17. Assumptions

- Provider data is seeded from a mock dataset of 50–200 providers covering Islamabad, Rawalpindi, Karachi, and Lahore.
- Distance between user and provider is calculated using the **Haversine formula** on pre-seeded `GeoPoint` coordinates. No external maps API is called. Travel time is estimated as `distance_km / 30 km/h` (average urban speed).
- Notifications are **fully simulated** as in-app toasts and modals. No third-party notification API is used in the prototype.
- Payments are simulated (no real payment gateway integrated in the prototype). A payment confirmation webhook stub is used.
- Provider GPS location during en-route simulation is mocked with a linear interpolation between provider base and job address.
- The prototype assumes mobile users have a stable internet connection; offline mode is not supported in v1.
- All prices are in Pakistani Rupees (PKR).
- The system assumes the user's device can provide GPS location for accurate distance calculation; manual area entry is the fallback.
- Provider onboarding (ID verification, background check) is outside the scope of this prototype and is represented as a `verified: true/false` flag.
- Antigravity agent timeout threshold is set at 8 seconds per reasoning step.
- All LLM calls use **Gemini 1.5 Flash** (free tier, 15 requests/min, 1M tokens/day) — no paid Gemini tier is used.
- Firebase Firestore is used on the **Spark free plan**. The prototype's demo load (< 500 bookings) stays well within the 50K reads/day and 20K writes/day limits.
- Google Cloud Run free tier (2M requests/month) covers all prototype traffic. The $5 GCP credit is held as a safety buffer only.

---

## 18. Cost and Latency Analysis

### 18.1 Prototype Cost — $0 (Demo / Hackathon)

| Operation | How It's Handled | Cost |
|---|---|---|
| Intent extraction + NLU | Gemini 1.5 Flash — free tier | $0 |
| Distance calculation | Haversine formula — runs locally, no API | $0 |
| Provider lookup | Static JSON mock dataset — no API | $0 |
| Provider DB query | Firebase Firestore Spark free plan | $0 |
| Notifications | In-app simulation (toast / modal) | $0 |
| Booking audit log | Google Sheets API — free with GCP | $0 |
| Hosting | Google Cloud Run free tier | $0 |
| **Total prototype cost** | | **$0** |
| **GCP credit ($5)** | Held as safety buffer, not expected to be used | $5 reserved |

### 18.2 Production Cost Estimate

This repository intentionally avoids paid service dependencies. All flows are designed for free-tier or local-only operation (Gemini 1.5 Flash free tier, static provider JSON, local Haversine distance, and in-app notifications).

### 18.2 Latency Breakdown (P50 / P95)

| Stage | P50 Latency | P95 Latency |
|---|---|---|
| Intent extraction | 800 ms | 1,800 ms |
| Provider discovery + ranking | 1,200 ms | 2,500 ms |
| Scheduling check | 400 ms | 900 ms |
| Pricing calculation | 300 ms | 700 ms |
| Booking confirmation + notifications | 1,100 ms | 2,200 ms |
| **End-to-end (intent → confirmation)** | **~4.0 s** | **~8.5 s** |

### 18.3 Scalability Notes

- Antigravity agents are stateless and horizontally scalable via Cloud Run
- Firestore scales automatically; no manual sharding required for < 10,000 concurrent users
- Haversine distance calculation is O(n) over the provider list and runs in < 5 ms for 200 providers — no external API bottleneck

---

## 19. Baseline Comparison

| Capability | Informal Network (WhatsApp/Calls) | Basic Directory App (e.g., OLX, Zameen Services) | This System |
|---|---|---|---|
| Multilingual input | ✅ (human handles) | ❌ | ✅ Automated (Urdu, Roman Urdu, English, mixed) |
| Structured intent extraction | ❌ | ❌ | ✅ With confidence scoring |
| Multi-factor provider ranking | ❌ | Partial (distance only) | ✅ 10-factor composite score |
| Real-time scheduling conflict check | ❌ | ❌ | ✅ |
| Dynamic, transparent pricing | ❌ | ❌ | ✅ Itemized breakdown |
| Automated booking + notifications | ❌ | Partial | ✅ In-app notification simulation (production: SMS + WhatsApp) |
| Post-service feedback loop | ❌ | Partial | ✅ Rating + reputation update |
| Dispute resolution | ❌ (informal) | ❌ | ✅ Automated + escalation ladder |
| Provider-side optimization | ❌ | ❌ | ✅ Demand forecast + fair allocation |
| Reasoning transparency | ❌ | ❌ | ✅ Antigravity trace logs |
| Average time to confirmed booking | 15–60 min | 5–15 min | **< 60 seconds** |
| Pricing predictability | Very low | Low | High |
| Trust mechanism | Referral only | Star rating (unverified) | Verified score + dispute history |

---

## 20. Privacy Note

- **User data collected:** Phone number, service request text, location (GPS or manual entry), booking history, ratings given.
- **Provider data collected:** Phone number, business name, location, availability, performance metrics, earnings.
- **Data storage:** All records stored in Firebase Firestore with role-based access control. User data and provider data are stored in separate collections with no cross-collection public access.
- **Location data:** GPS coordinates are used only for local distance calculation and are not shared with third-party Maps APIs. Coordinates are not stored in plain text after the booking is confirmed; only the human-readable address is retained.
- **Notification data:** Notifications are simulated entirely in-app and no phone numbers are passed to any external notification service.
- **Data retention:** Booking records retained for 12 months; dispute records retained for 24 months for compliance. User accounts and provider profiles retained until deletion is requested.
- **Third-party APIs:** Firebase and Google Cloud services each have their own privacy policies. Users are informed of this at onboarding.
- **No advertising:** User data and provider data are not used for advertising or sold to third parties.
- **Right to deletion:** Users and providers may request full data deletion via the app; records are purged within 30 days, subject to dispute-related legal retention requirements.
- **Prototype note:** The prototype uses anonymized or synthetic data. No real user PII is collected during hackathon demonstration.

---

## 21. Limitations

- **No real payment processing:** Payments are simulated. Production would require PCI-compliant payment gateway integration (e.g., JazzCash, EasyPaisa, Stripe).
- **Mock provider dataset:** The 50–200 provider dataset is synthetic. Real deployment requires a provider onboarding pipeline with identity verification.
- **GPS simulation:** En-route provider tracking uses linear interpolation, not live GPS. Real deployment would require a provider-side mobile SDK with background location permission.
- **Haversine distance accuracy:** The prototype uses Haversine straight-line distance with an estimated travel speed of 30 km/h. This approximates travel time but does not account for traffic, road layout, or one-way streets.
- **No external notification gateways:** Notifications are simulated as in-app toasts/modals to keep the prototype fully free-tier and local-first.
- **Antigravity availability:** The system's core reasoning capability is dependent on Google Antigravity's uptime and API quota. No non-Antigravity fallback orchestrator exists in v1.
- **Gemini free tier rate limits:** Gemini 1.5 Flash free tier allows 15 requests/minute. Under concurrent load (e.g., multiple simultaneous bookings), requests may be queued. A retry-with-backoff strategy is implemented.
- **Urdu NLU accuracy:** While Gemini handles multilingual input well, highly dialectal or heavily slang-laden input may still produce low-confidence parses requiring manual confirmation.
- **Review sentiment analysis:** Review recency scoring currently uses star ratings only. Full sentiment analysis of free-text reviews is planned for v2.
- **No offline mode:** The app requires internet connectivity throughout the booking flow.
- **Provider app not in scope:** This prototype focuses on the customer-facing flow. A dedicated provider-side app for availability management and job acceptance is a future deliverable.
- **Demand forecasting accuracy:** The 7-day demand forecast is based on historical booking patterns from the mock dataset. Real accuracy depends on volume of production data.
- **Multi-city coverage:** The prototype covers Islamabad, Rawalpindi, Karachi, and Lahore. Expansion to smaller cities requires additional provider onboarding and local demand calibration.

---

## 22. Judge Verification: Proving Antigravity Usage

To make Antigravity usage auditable during judging, provide all three artifacts below:

1. **Trace Artifact (`antigravity_traces.json`)**
   - Generate via:
     - `python3 functions/tests/export_traces.py`
   - This file includes:
     - `antigravity_metadata.platform = "Google Antigravity"`
     - Full step-by-step agent decisions, tool calls, and outputs
     - Multi-agent invocation chain (Intent, Surge, Matching, Pricing, Scheduling, Booking, Dispute)

2. **Stress-Test Evidence (`stress_test_report.json`)**
   - Generate via:
     - `python3 functions/tests/stress_test.py`
   - Shows pass/fail behavior across required edge cases and end-to-end booking simulation.

3. **Live Demo Evidence**
   - In-app: show **Live Agent Reasoning** panel while submitting a request.
   - During booking: show **7-step Booking Pipeline** completion with timestamps and final confirmation.

### Judge Checklist (Fast)
- Confirm `antigravity_traces.json` exists and includes Antigravity metadata.
- Confirm at least one trace reaches `booking_confirmed` with full chain.
- Confirm stress report includes end-to-end scenario and edge-case handling.
- Confirm live UI reasoning panel matches the same agent stages shown in traces.

---

*Built for the AI Service Orchestrator Challenge · Powered by Google Antigravity*
