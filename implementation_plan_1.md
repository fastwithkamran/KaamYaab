# 🚀 KhidmatGaar — AI Service Orchestrator (Challenge 2)
### AI Seekho Hackathon 26 | Team Implementation Plan

> **"KhidmatGaar"** (The One Who Serves) — An agent-first Flutter mobile app that transforms Pakistan's informal service economy from WhatsApp chaos into an intelligent, trust-based ecosystem.

---

## Background & Problem

Pakistan's informal service economy (plumbers, AC technicians, tutors, electricians) runs on WhatsApp groups, missed calls, and word-of-mouth referrals. The result: unpredictable pricing, zero trust signals, no accountability, and missed opportunities.

**KhidmatGaar** solves this end-to-end using **Google Antigravity as the central orchestrator**, powering a fleet of specialized AI agents that handle everything from understanding a noisy Urdu voice message to resolving a post-service dispute.

---

## User Review Required

> [!IMPORTANT]
> **Deadline:** May 15, 2026 is the challenge/idea selection deadline. May 20, 2026 is final submission. We must move fast.

> [!IMPORTANT]
> **Flutter is mandatory.** Mobile app must be built in Flutter (Dart). Web dashboard is optional and can be built in parallel.

> [!WARNING]
> **Antigravity must remain the core orchestrator.** All agent logic (intent, matching, pricing, scheduling, dispute) must run through Antigravity workflows — not simple if-else code. Judges will check reasoning traces.

> [!CAUTION]
> **Robustness evidence is mandatory** — we must demo at least one edge case: provider cancels after booking, user input is ambiguous, no provider available, or a dispute is raised.

---

## Open Questions

- [ ] Who on the team will own Flutter UI vs. Antigravity agent logic vs. mock dataset?
- [ ] Do we have access to Google Maps/Places API keys for live provider geo-lookup?
- [ ] Will we simulate SMS/WhatsApp notifications (recommended) or use a real API (Twilio/Meta)?
- [ ] Should the web dashboard be built or skipped to focus effort on mobile?

---

## Evaluation Criteria Mapping

| Criterion | Weight | Our Strategy |
|---|---|---|
| Antigravity Integration | **20%** | Every agent action routed through Antigravity; full reasoning traces exported |
| Matching & Decision Quality | **25%** | 8-factor DNA Score algorithm with transparent ranking rationale |
| Multilingual Robustness | **15%** | Gemini-powered intent agent with confidence scoring + fallback prompts |
| Scheduling, Pricing & Workflow | **15%** | Full booking simulation with surge detection & negotiation agent |
| Dispute Handling & Scalability | **15%** | Full dispute resolution workflow with compensation & blacklist logic |
| Innovation & UX | **10%** | Live Agent Reasoning Panel (industry-first transparency feature) |

---

## Unique & Differentiating Features

### 1. Live Agent Reasoning Panel *(Industry-First)*
A real-time, animated overlay in the app that **shows the user what the AI is thinking** at every step. Think of it like "X-ray vision into the AI's brain."

- Shows the active Antigravity agent name + task
- Displays reasoning steps: `"Provider B is 2km away but has 3 cancellations this month → downranked"`
- Animated thinking indicator with step-by-step decision log
- Can be toggled on/off by the user
- **Why sponsors love it:** Directly demonstrates Antigravity's agentic depth. Judges SEE the AI working, not just the output.

---

### 2. Provider DNA Score *(Beyond Star Ratings)*
A composite, multi-dimensional trust score (0-1000) computed by the **Matching Agent**. It's not just a star average — it's a living score that decays and grows.

**DNA Score = weighted sum of 8 factors:**

| Factor | Weight | Description |
|---|---|---|
| On-Time Reliability | 25% | Historical arrival vs. promised time |
| Review Recency | 20% | Recent reviews weighted 3x more than old ones |
| Job Completion Rate | 15% | Jobs completed vs. abandoned |
| Skill Specialization Match | 15% | How well their skills match the exact job |
| Cancellation Risk | 10% | Penalizes last-minute cancellations |
| Price Fairness Score | 8% | Whether final price matched quoted price |
| Dispute History | 5% | Weighted penalty for past disputes |
| Surge Acceptance Rate | 2% | Willingness to take urgent jobs |

Visual: A hexagonal "DNA chart" in the provider card — sponsors will screenshot this.

---

### 3. Provider Discovery + Surge Detection Agent *(Real-time Market Intelligence)*
The **Surge Agent** runs in the background and:
- Detects when multiple users request the same service type in the same area within a 30-minute window
- Calculates a **Surge Multiplier** (1.0x-2.5x) with transparent breakdown
- Notifies available providers first ("Earn 1.8x tonight!")
- Gives users a **Surge Alert** with an option to book now or wait for prices to drop
- Uses demand forecasting to recommend off-peak booking times

**Tech:** Google Maps Geocoding API + mock demand dataset + Antigravity Surge Agent.

---

### 4. Negotiation Agent *(Unique to KhidmatGaar)*
After the initial price quote, the user can **negotiate** in natural language:
- User: *"Bhai 1500 mein ho sakta hai?"*
- Negotiation Agent considers: provider's current workload, job complexity, user's loyalty status, surge conditions
- Counter-offer with reasoning: *"Provider can do Rs. 1,700 — Rs. 200 discount applied due to your repeat booking. Final offer."*
- Provider also gets a smart notification: *"User offered Rs. 1,500. Your counter-offer: Rs. 1,700 based on current demand."*

---

### 5. Booking Confirmation Workflow *(Full Simulation Chain)*
A 7-step simulated booking chain orchestrated entirely by Antigravity:

```
Step 1: Slot Lock       → Reserve provider's calendar slot (prevents double-booking)
Step 2: Confirmation    → Simulated WhatsApp/SMS to user + provider
Step 3: Receipt         → Generate PDF-style booking receipt in-app
Step 4: Reminder Chain  → T-24h, T-1h, T-15min reminders simulated
Step 5: En-Route Update → Provider "I'm on my way" ping with ETA
Step 6: Completion      → Service done checklist + photo placeholder
Step 7: Feedback Loop   → 5-star + text review → DNA Score update
```

Every step logged in Antigravity trace. **This is what judges want to see.**

---

### 6. Dispute & Escalation Engine *(Trust Infrastructure)*
When something goes wrong, the **Dispute Agent** activates:

| Scenario | Agent Action |
|---|---|
| Provider no-show | Auto-rebook next available; provider penalized in DNA score |
| Price disagreement | Pull original quote receipt; flag discrepancy; mediate |
| Quality complaint | Trigger service re-do request or partial refund simulation |
| Blacklist trigger | If 3+ disputes confirmed against provider: soft ban + human escalation alert |
| Human escalation | Generate support ticket with full Antigravity trace attached |

---

### 7. Provider Workload Balancing Dashboard *(Provider-Side Innovation)*
A **Provider Mode** in the app showing:
- Current booking queue
- Recommended slots for maximum earnings based on demand forecast
- "Hot zones" map — areas with high demand right now
- Weekly earnings simulation
- Antigravity advice: *"Accept 2 more AC jobs today — surge window closes at 6 PM"*

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart) — iOS + Android |
| **AI Orchestrator** | Google Antigravity (core workflow engine) |
| **LLM / NLU** | Gemini 1.5 Pro via Google AI Studio |
| **Maps & Geo** | Google Maps + Places API |
| **Backend / DB** | Firebase Firestore (real-time) + Cloud Functions |
| **Notifications** | Firebase Cloud Messaging (simulated WhatsApp/SMS) |
| **State Management** | Flutter Riverpod |
| **Animations** | Flutter Lottie + custom animated widgets |
| **Agent Framework** | LangGraph (connected via Antigravity) |

---

## System Architecture

```
+-----------------------------------------------------+
|                KhidmatGaar App (Flutter)             |
|  +----------+ +----------------+ +----------------+  |
|  | User Mode| | Provider Mode  | | Live Reasoning |  |
|  |          | |                | |     Panel      |  |
|  +----+-----+ +-------+--------+ +-------+--------+  |
+-------+-----------------+------------------+---------+
        |                 |                  |
        v                 v                  v
+----------------------------------------------------+
|           GOOGLE ANTIGRAVITY ORCHESTRATOR           |
|  +-----------+ +----------+ +------------------+   |
|  |  Intent   | | Matching | |    Surge         |   |
|  |   Agent   | |  Agent   | |    Agent         |   |
|  +-----------+ +----------+ +------------------+   |
|  +-----------+ +----------+ +------------------+   |
|  | Pricing + | |Scheduling| |   Dispute &      |   |
|  | Negotiate | |  Agent   | |  Escalation      |   |
|  +-----------+ +----------+ +------------------+   |
|  +-----------+ +----------+                         |
|  | Booking   | |Feedback/ |                         |
|  | Simulation| |DNA Update|                         |
|  +-----------+ +----------+                         |
+----------------------------------------------------+
        |                 |                  |
        v                 v                  v
+--------------+ +--------------+ +------------------+
|  Gemini 1.5  | |  Firestore   | |  Google Maps /   |
|     Pro      | |   + FCM      | |   Places API     |
+--------------+ +--------------+ +------------------+
```

---

## Proposed Changes (File Structure)

### Phase 1 — Flutter App Foundation (Day 1)

#### [NEW] `khidmatgaar/` (Flutter project root)
- `pubspec.yaml` — dependencies: riverpod, lottie, google_maps_flutter, firebase_core, dio
- `lib/main.dart` — app entry, theme definition

#### [NEW] `lib/theme/app_theme.dart`
- Deep Teal + Saffron Gold color palette (trust + premium feel)
- Custom typography (Poppins + Noto Nastaliq Urdu)
- Dark mode support

#### [NEW] `lib/screens/`
- `home_screen.dart` — Magic Search bar + Recent Bookings
- `agent_panel_screen.dart` — Live Agent Reasoning Panel overlay
- `provider_card.dart` — DNA Score hexagonal chart widget
- `booking_flow_screen.dart` — 7-step booking simulation UI
- `dispute_screen.dart` — Dispute/escalation UI
- `provider_dashboard_screen.dart` — Provider workload view

---

### Phase 2 — Antigravity Agent Layer (Day 1-2)

#### [NEW] `functions/agents/intent_agent.py`
- Gemini-powered multilingual NLU
- Confidence scoring (0.0-1.0)
- Output: `{service_type, location, urgency, time_preference, budget_sensitivity, confidence}`
- Fallback: clarification questions when confidence < 0.7

#### [NEW] `functions/agents/matching_agent.py`
- 8-factor DNA Score calculation
- Ranking with transparent rationale output (feeds Live Panel)
- Top-3 provider recommendations with comparison table

#### [NEW] `functions/agents/surge_agent.py`
- Demand clustering by geo-zone + time window
- Surge multiplier calculation
- Provider notification payload generation

#### [NEW] `functions/agents/pricing_agent.py`
- Dynamic quote = base_rate + urgency_adj + distance_cost + surge_mult + loyalty_discount
- Negotiation counter-offer logic
- Transparent line-item breakdown

#### [NEW] `functions/agents/scheduling_agent.py`
- Double-booking prevention
- Travel-time buffer calculation
- Waitlist management + auto-reschedule on cancellation

#### [NEW] `functions/agents/booking_agent.py`
- 7-step booking chain orchestration
- Antigravity task plan + reasoning trace generation

#### [NEW] `functions/agents/dispute_agent.py`
- Scenario detection + automated resolution actions
- Blacklist threshold logic
- Support ticket generation with full trace

---

### Phase 3 — Data Layer (Day 1)

#### [NEW] `data/providers_mock.json`
- 50 mock providers across 5 service categories
- Realistic DNA score factors, geo-coordinates, availability calendars
- Covers: AC repair, Plumbing, Electrical, Tutoring, Cleaning

#### [NEW] `data/demand_mock.json`
- Historical demand by area/time-of-day for surge simulation

---

### Phase 4 — Web Dashboard (Optional, Day 3)
#### [NEW] `web_dashboard/` (Next.js)
- Antigravity trace viewer
- Live booking map
- Provider analytics

---

## Milestone Timeline

| Day | Goal |
|---|---|
| **Day 1 (May 14)** | Flutter project setup, theme, home screen, mock data, intent + matching agents |
| **Day 2 (May 15)** | Surge agent, pricing + negotiation, scheduling agent, booking chain, Live Reasoning Panel |
| **Day 3 (May 16-17)** | Dispute engine, DNA Score UI, provider dashboard, edge case testing |
| **Day 4 (May 18-19)** | Polish UI, record demo video, write README, export Antigravity traces |
| **Day 5 (May 20)** | Final submission by deadline |

---

## Verification Plan

### Automated Tests
- Unit test each agent with 10+ input variations (Urdu, Roman Urdu, English, mixed, misspelled)
- Stress test: simulate 50 concurrent booking requests — check double-booking prevention
- Surge test: inject 5 same-service requests in G-13 within 20 mins — verify 1.4x surge trigger

### Demo Scenario Script (For Video)
1. User says: *"AC bilkul kaam nahi kar raha, kal subah G-13 mein chahiye, budget tight hai"*
2. Live Reasoning Panel lights up — Intent Agent extracts service/location/urgency
3. Surge Agent detects 3 AC requests in G-13 — 1.3x surge warning shown
4. Matching Agent ranks 5 providers — DNA Score hexagons animate in
5. Negotiation: User offers Rs. 1,500 — Agent counter-offers Rs. 1,700 with reasoning
6. Booking: All 7 steps animate on screen with Antigravity trace scrolling
7. Edge case: Provider cancels — Auto-reschedule triggers, user notified instantly
8. Post-service: Review + DNA Score update shown

### Robustness Evidence
- Demo "no provider available" scenario — fallback: waitlist + expand search radius
- Demo ambiguous input: *"bijli ka masla hai"* — confidence 0.6 — system asks: "Electrical wiring ya power outage?"
- Demo price dispute — Dispute Agent activates, original quote receipt surfaced

---

## Baseline Comparison (Mandatory for Submission)
Side-by-side comparison:
- **Without KhidmatGaar:** WhatsApp search — 4 phone calls — no price transparency — no confirmation
- **With KhidmatGaar:** 8-second natural language request — ranked matches — negotiated price — confirmed booking with receipt

---

## README Checklist (Submission Requirement)
- [ ] Architecture diagram
- [ ] Provider dataset schema (50 providers, 8 DNA factors)
- [ ] All matching factors documented
- [ ] Antigravity workflow diagram
- [ ] APIs/tools used
- [ ] Assumptions listed
- [ ] Cost per operation estimate (Gemini API calls)
- [ ] 10x/100x scalability discussion
- [ ] Latency estimates per agent
- [ ] Privacy note (no real user data stored)
- [ ] Limitations section
