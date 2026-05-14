# KaamYaab — AI Service Orchestrator

### AI Seekho Hackathon 26 | Challenge 2 | Team Submission

An **agent-first Flutter mobile app** that transforms Pakistan's informal service economy from WhatsApp chaos into an intelligent, trust-based ecosystem — powered by **Google Antigravity** as the central orchestrator.

---

## Architecture Overview

**KaamYaab App (Flutter)** (User Mode | Provider Dashboard | Disputes)

|

**GOOGLE ANTIGRAVITY ORCHESTRATOR**

* Intent Agent | Matching Agent
* Surge Agent | Pricing + Negotiate
* Booking Chain | Dispute Engine
|
**Gemini 1.5 Pro | Firebase Firestore**

---

## Unique Features

| Feature | Description |
| --- | --- |
| **Live Agent Reasoning Panel** | Real-time X-ray of Antigravity's thinking — each agent step shown with reasoning, tool calls, and decisions |
| **Provider DNA Score (0-1000)** | 8-factor composite trust score visualized as animated hexagonal radar chart |
| **Surge Detection Agent** | Detects demand spikes by geo-zone/time window, computes 1.0x-2.5x multiplier |
| **Negotiation Agent** | Natural language price negotiation with AI-mediated counter-offers |
| **7-Step Booking Chain** | Slot lock -> confirmation -> receipt -> reminders -> en-route -> completion -> DNA update |
| **Dispute & Escalation Engine** | AI verdict for no-show, price dispute, quality complaint; blacklist trigger at threshold |
| **Provider Dashboard** | Workload view with earnings chart, hot-zone map, and AI slot recommendations |

---

## Provider Dataset Schema

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Unique provider ID |
| `name` | string | Full name |
| `service_category` | string | AC Repair / Plumbing / Electrical / Tutoring / Cleaning |
| `skills` | array | Specific skills list |
| `lat`, `lng` | float | Geo-coordinates |
| `dna_score` | int | Composite trust score 0-1000 |
| `on_time_rate` | float | Historical on-time arrival ratio |
| `cancellation_rate` | float | Cancellation ratio |
| `price_fairness_score` | float | Ratio of actual vs quoted price matches |
| `dispute_count` | int | Historical dispute count |
| `surge_acceptor` | bool | Willingness to accept surge bookings |
| `base_rate_pkr` | float | Base service rate in PKR |
| `experience_level` | string | basic / intermediate / complex |
| `certifications` | array | Professional certifications |
| `available_slots` | array | Today's available time slots |

---

## DNA Score Matching Factors

| Factor | Weight | Signal |
| --- | --- | --- |
| On-Time Reliability | 25% | Historical arrival vs. promised time |
| Review Recency | 20% | Recent reviews weighted 3x more |
| Job Completion Rate | 15% | Jobs completed vs. abandoned |
| Skill Specialization | 15% | Skills depth + complexity match |
| Cancellation Risk | 10% | Penalizes last-minute cancellations |
| Price Fairness | 8% | Final price vs. quoted price match |
| Dispute History | 5% | Weighted penalty for past disputes |
| Surge Acceptance | 2% | Willingness during high-demand periods |

---

## Antigravity Workflow

**User Input**

1. **Intent Agent (Gemini 1.5 Pro)**
* Multilingual parsing (Urdu/Roman Urdu/English/Mixed)
* Confidence score; clarification if < 0.70


2. **Surge Agent**
* Demand clustering by geo-zone + 30-min window
* Surge multiplier 1.0x-2.5x


3. **Matching Agent (8-factor DNA)**
* Ranks providers; distance penalty applied
* Top-5 with transparent rationale


4. **Pricing Agent**
* Dynamic quote = base + urgency + distance + surge - loyalty
* Negotiation sub-agent if budget_sensitivity > 0.55


5. **Scheduling Agent**
* Prevents double-booking
* Travel-time buffer validation
* Alternate slots / waitlist if needed


6. **Booking Agent (7-step chain)**
* Slot lock -> confirmation -> receipt -> reminders
* En-route -> completion -> feedback


7. **Dispute Agent (post-service)**
* AI verdict: user_favor / mediated / escalate
* Refund, penalty, DNA update, blacklist



---

## APIs & Tools Used

| Tool | Purpose |
| --- | --- |
| Google Antigravity | Core agent orchestration platform |
| Gemini 1.5 Pro | Intent extraction, negotiation, dispute analysis |
| Google Maps / Geocoding | Provider location + distance calculation |
| Firebase Firestore | Booking & provider data persistence |
| Firebase Cloud Messaging | Simulated WhatsApp/SMS notifications |
| LangGraph | Agent workflow graphs (connected via Antigravity) |
| Flutter + Riverpod | Mobile app + state management |
| fl_chart | Provider earnings visualization |

---

## Assumptions

1. User location is Islamabad (G-13 as default for demo).
2. Notification delivery is simulated via FCM (real WhatsApp Business API integration is architecture-ready).
3. Payment is cash-on-delivery (payment gateway integration is modular).
4. Provider availability uses mock calendar data; real-time sync via Firestore is implemented.
5. Maps are functional with a real Google Maps API key (key required at build time).

---

## Cost / Latency Estimates

| Operation | Model | Estimated Cost | Latency |
| --- | --- | --- | --- |
| Intent extraction | Gemini 1.5 Pro | ~$0.0003/call | 600-900ms |
| Negotiation | Gemini 1.5 Pro | ~$0.0004/call | 700-1100ms |
| Dispute analysis | Gemini 1.5 Pro | ~$0.0005/call | 800-1200ms |
| Matching (pure compute) | N/A | ~$0.000/call | <50ms |
| Surge detection | N/A | ~$0.000/call | <20ms |
| **Full booking flow** | **Total** | **~$0.001/booking** | **3-5 seconds** |

---

## Scalability Discussion

| Scale | Strategy |
| --- | --- |
| **10x (10K bookings/day)** | Current architecture handles it — Firestore auto-scales, Gemini API rate limits manageable |
| **100x (100K bookings/day)** | Add Redis caching for surge data; batch intent parsing; Gemini Flash for low-latency agents |
| **1000x (1M bookings/day)** | Kafka for event streaming; horizontal Cloud Run scaling; regional Firestore sharding |

---

## Baseline Comparison

| Metric | Without KaamYaab | With KaamYaab |
| --- | --- | --- |
| Time to find provider | 20-45 min (WhatsApp search) | 8-15 seconds |
| Price transparency | None | Full itemized breakdown |
| Trust signals | Word of mouth | 8-factor DNA Score |
| Booking confirmation | None | SMS + WhatsApp + In-app receipt |
| Dispute resolution | Informal / ignored | AI verdict in <30 seconds |
| Provider accountability | None | DNA Score decay on violations |

---

## Robustness & Edge Cases Demonstrated

1. **No provider available** -> Waitlist + expand search radius suggestion
2. **Ambiguous input** ("bijli ka masla") -> Confidence 0.60 -> Clarification question shown
3. **Provider cancels after booking** -> Auto-reschedule + user notification
4. **Two users request same provider** -> Scheduling Agent prevents double-booking; alternate slots offered
5. **Price dispute post-service** -> Dispute Agent activates; original receipt pulled; refund/penalty issued
6. **High surge scenario** -> Surge Agent detects -> user shown Book Now or Wait option

---

## Privacy Note

* No real user names, phone numbers, or location data stored in this demo.
* All provider data is mock/synthetic.
* In production: user data encrypted at rest in Firestore; GPS processed on-device only.
* No raw audio/images stored; all agent inputs are text.

---

## Limitations

1. Gemini API requires internet connectivity; fallback uses rule-based parsing.
2. Maps features require a valid Google Maps API key (not included in repo).
3. WhatsApp notifications are simulated; real integration requires Meta Business API approval.
4. Payment processing is not implemented (architecture is ready for Easypaisa/JazzCash integration).
5. Provider onboarding flow (KYC, verification) is out of scope for this demo.

---

## Setup Instructions

```bash
# 1. Install Flutter SDK (3.x or higher)
# 2. Clone and open project
cd kaamYaab

# 3. Install dependencies
flutter pub get

# 4. Set runtime secrets/config
# PowerShell:
$env:GEMINI_API_KEY="your_gemini_api_key"
$env:SUPER_ADMIN_PHONE="03001234567"
$env:SMS_ENABLED="false"
$env:OTP_EXPIRY_SECONDS="120"
# Bash:
export GEMINI_API_KEY="your_gemini_api_key"
export SUPER_ADMIN_PHONE="03001234567"
export SMS_ENABLED="false"
export OTP_EXPIRY_SECONDS="120"
# Note: dart-define values are passed as strings and parsed by the app.
# Also replace YOUR_GOOGLE_MAPS_API_KEY in:
# - android/app/src/main/AndroidManifest.xml
# - web/index.html

# 5. Run on Android device/emulator
# Bash:
flutter run \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY \
  --dart-define=SUPER_ADMIN_PHONE=$SUPER_ADMIN_PHONE \
  --dart-define=SMS_ENABLED=$SMS_ENABLED \
  --dart-define=OTP_EXPIRY_SECONDS=$OTP_EXPIRY_SECONDS
# PowerShell:
flutter run `
  --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY `
  --dart-define=SUPER_ADMIN_PHONE=$env:SUPER_ADMIN_PHONE `
  --dart-define=SMS_ENABLED=$env:SMS_ENABLED `
  --dart-define=OTP_EXPIRY_SECONDS=$env:OTP_EXPIRY_SECONDS

# 6. Run Python agents test
cd functions/agents
pip install google-generativeai
export GEMINI_API_KEY="your_gemini_api_key"
python intent_agent.py
python orchestrator_agents.py

```

---

## Team

| Role | Responsibility |
| --- | --- |
| Flutter Developer | UI screens, widgets, animations |
| AI/Agent Engineer | Antigravity workflows, Gemini integration |
| Data Engineer | Mock datasets, DNA score algorithm |
| Product/Demo | Video script, presentation, README |

---

*Built for AI Seekho Hackathon 26 — Challenge 2: AI Service Orchestrator for Informal Economy*

*Powered by Google Antigravity + Gemini 1.5 Pro*
