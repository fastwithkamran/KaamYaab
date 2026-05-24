# 🛠️ KaamYaab (کامیاب) — AI-Powered Service Orchestrator for Pakistan's Informal Economy

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org)
[![Cohere](https://img.shields.io/badge/Cohere%20AI-00C7B7?style=for-the-badge&logo=cohere&logoColor=white)](https://cohere.com)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-blue?style=for-the-badge)](#)

An agentic, end-to-end service lifecycle platform for informal-economy professionals in Pakistan — plumbers, electricians, AC technicians, tutors, beauticians, drivers, mechanics, painters, and cleaners. Powered by **Cohere command-a-03-2025** and a robust multi-agent orchestration architecture, **KaamYaab** connects customers with workers using voice booking, dynamic matching, smart negotiation, travel-aware scheduling, transparent pricing, and automated dispute resolution.

---

## 🚀 Quick Judge Demo & Testing Essentials

To make it as easy as possible to evaluate and test the KaamYaab application, we have provided a pre-compiled Android build and test credentials:

* **📱 Download Android APK:** [KaamYaab APK (Google Drive)](https://drive.google.com/file/d/14QK5gLzhHbQfKpBiFX63M_4yTsrrOstM/view?usp=drive_link)
* **🔑 Firebase OTP Test Credentials:**
  Skip the SMS wait times. Use these pre-configured sandbox numbers to test both user roles in the system:
  * **👤 Customer Account:**
    * Phone Number: `+92 331 1234567`
    * Verification OTP Code: `123456`
  * **🛠️ Service Provider (Worker) Account:**
    * Phone Number: `+92 331 1234568`
    * Verification OTP Code: `123456`

---

## 📖 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Multi-Agent Architecture](#2-multi-agent-architecture)
3. [Core Multi-Agent Ecosystem](#3-core-multi-agent-ecosystem)
4. [Tech Stack & APIs](#4-tech-stack-&-apis)
5. [Folder Structure](#5-folder-structure)
6. [Supported Input Modes](#6-supported-input-modes)
7. [Advanced Provider Matching Algorithm](#7-advanced-provider-matching-algorithm)
8. [Job Complexity Classification](#8-job-complexity-classification)
9. [Dynamic Pricing Engine](#9-dynamic-pricing-engine)
10. [Dispute & Escalation Workflow](#10-dispute-&-escalation-workflow)
11. [Developer Installation & Setup](#11-developer-installation-&-setup)
12. [Engineering Rigor & Quality Control (Bug Fixes)](#12-engineering-rigor-&-quality-control-bug-fixes)
13. [Hackathon Demo & Pitch Simulator](#13-hackathon-demo-&-pitch-simulator)

---

## 1. Project Overview

The informal service economy in South Asia relies on highly fragmented and unreliable channels: local referrals, WhatsApp groups, and word-of-mouth networks. This results in:
* **Unpredictable & Opaque Pricing:** Standard rates do not exist; both sides feel shortchanged.
* **No Verifiable Trust:** Zero rating histories, background checks, or quality guarantees.
* **Scheduling Friction:** Frequent no-shows, missed slots, and no consideration of transit times.
* **Exclusion of Low-Literacy Users:** Complex forms and English-centric layouts exclude typical users.

**KaamYaab** addresses this by automating the entire service lifecycle using a **Unified Conversational Agent**. Customers can type or speak naturally in **Urdu, English, Roman Urdu, or mixed code-switched text**, and KaamYaab handles the rest — parsing intentions, matching the ideal provider via a 10-factor composite score, managing prices dynamically, booking the service, tracking en-route status, collecting reviews, and mediating disputes autonomously.

---

## 2. Multi-Agent Architecture

The orchestration engine coordinates several specialized, autonomous agents that manage specific segments of the service lifecycle:

```
                      ┌──────────────────────────────────────┐
                      │             CLIENT LAYER             │
                      │  Voice/Text Input in Roman Urdu/Eng  │
                      └──────────────────┬───────────────────┘
                                         │
                                         ▼
                      ┌──────────────────────────────────────┐
                      │       UNIFIED CHAT AGENT (COHERE)    │
                      │  Detects greeting, chats, or triggers│
                      └──────────────────┬───────────────────┘
                                         │
                                         ▼ [Search Intent]
                      ┌──────────────────────────────────────┐
                      │    COHERE MULTI-AGENT ORCHESTRATOR   │
                      │                                      │
                      │  ┌──────────────┐  ┌──────────────┐  │
                      │  │ Intent Agent │  │ Surge Agent  │  │
                      │  └──────┬───────┘  └──────┬───────┘  │
                      │         │                 │          │
                      │  ┌──────▼───────┐  ┌──────▼───────┐  │
                      │  │ Matching Agt.│  │ Pricing Agt. │  │
                      │  └──────┬───────┘  └──────┬───────┘  │
                      │         │                 │          │
                      │  ┌──────▼───────┐  ┌──────▼───────┐  │
                      │  │ Negot. Agent │  │ Sched. Agent │  │
                      │  └──────┬───────┘  └──────┬───────┘  │
                      │         │                 │          │
                      │  ┌──────▼───────┐  ┌──────▼───────┐  │
                      │  │ Booking Agt. │  │ Dispute Agt. │  │
                      │  └──────────────┘  └──────────────┘  │
                      │                                      │
                      └──────────────────┬───────────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    ▼                                         ▼
        ┌───────────────────────┐                 ┌───────────────────────┐
        │       DATA STORE      │                 │  EXTERNAL SERVICES    │
        │ Firebase Firestore    │                 │ Local Haversine Math  │
        │ Shared Runtime Config │                 │ Google Maps API       │
        └───────────────────────┘                 └───────────────────────┘
```

---

## 3. Core Multi-Agent Ecosystem

| Component | Technology | Responsibility |
|:---|:---|:---|
| **Intent Agent** | Cohere Chat / Rules | Analyzes customer text, extracts service categories, urgency, and resolves location coordinates. Falls back to a regex-based `fast_parse` rules engine. |
| **Surge Agent** | Python Orchestrator | Computes real-time dynamic multipliers based on provider-to-demand ratio. Offers off-peak slot suggestions. |
| **Matching Agent** | Multi-factor / DNA | Computes a 10-factor composite DNA score for candidates, checking tool ownership and experience. |
| **Pricing Agent** | 7-Component Engine | Formulates quotes: base + urgency + distance + complexity + surge − loyalty − budget sensitivity. |
| **Negotiation Agent** | Cohere / Rule Fallback | Handles price bargaining. Employs Cohere command-a-03-2025 for dynamic counters while enforcing an 85% absolute price floor. |
| **Scheduling Agent** | Transit & Buffers | Eliminates double-booking, enforces 45 min + travel buffers, limits active daily jobs, and suggests alternatives. |
| **Booking Agent** | 7-Step Pipeline | Confirms slots atomically, sends in-app/push alerts, generates billing receipts, and queues reminders. |
| **Dispute Agent** | Mediation & Audit | Mediates no-shows, overcharges, or quality complaints. Applies provider reputation (DNA) penalties or bans. |
| **Provider Optimization** | Routing & Advisories | Suggests peak-hour schedules, forecasts weekly earnings, and recommends hot-spot geographic routing. |

---

## 4. Tech Stack & APIs

> [!TIP]
> **Free-Tier Optimized:** This architecture is specifically engineered to run efficiently under free limits, bypassing expensive Map APIs with local Haversine calculations and utilizing optimized database batch writes.

* **Mobile App Framework:** Flutter (SDK 3.29.0+ compliant), written in modern declarative Dart with full screen responsiveness.
* **State Management:** Riverpod (`flutter_riverpod` + code generation via `build_runner` / `riverpod_generator`) for high-fidelity state flows.
* **LLM Engine:** Cohere API (`command-a-03-2025` runtime config for Flutter app, and `command-a-03-2025` for Python agents).
* **Database & Auth:** Firebase Auth + Firestore Spark Plan (50K reads/day, 20K writes/day).
* **Location Systems:** Straight-line Haversine math running client/server-side for distances, with optional `google_maps_flutter` integration.
* **Speech Services:** TTS (`flutter_tts`) and STT (`speech_to_text`) for voice bookings to accommodate low-literate users.

---

## 5. Folder Structure

```
.
├── android/                   # Native Android configuration
├── ios/                       # Native iOS configuration
├── windows/                   # Native Windows configuration
├── assets/                    # Graphical assets and data schemas
│   ├── animations/            # Lottie animation JSON files
│   ├── data/                  # Local mock datasets (providers_mock.json)
│   └── images/                # Static image assets and logo
├── functions/                 # Backend agent codebase (Python)
│   ├── agents/
│   │   ├── intent_agent.py    # Intent extraction agent and fallback parser
│   │   ├── matching_agent.py  # 10-factor DNA matching algorithm
│   │   └── orchestrator_agents.py # Multi-agent pricing, scheduling & disputes
│   ├── .env                   # Python environment secrets (Cohere API Key)
│   └── requirements.txt       # Python backend dependencies
├── lib/                       # Core Flutter application source
│   ├── config/                # Runtime and environment configurations
│   ├── models/                # Typed data schemas (User, Provider, Bookings)
│   ├── screens/               # Mobile UI layouts (Voice, Home, Browse, Dashboard)
│   ├── services/              # API gateways, Firebase, location & AI services
│   ├── theme/                 # Dark glassmorphism-ready design tokens
│   ├── widgets/               # Reusable styled UI components
│   └── main.dart              # Flutter application entry point
├── seedworkers.js             # Node.js Firestore seeder script
├── storage.rules              # Firebase Storage protection rules
└── firestore.rules            # Firestore security policies
```

---

## 6. Supported Input Modes

The Unified Chat Agent handles extreme variation in language and style, normalizing phonetic typos and code-switching:

* **Urdu (Nastaliq):** `کل صبح جی تیرہ میں اے سی ٹھیک کروانا ہے`
* **Roman Urdu:** `Kal subah G-13 mein AC theek karwana hai`
* **English:** `I need an AC technician tomorrow morning in G-13`
* **Code-switched (Mixed):** `AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai`
* **Noisy / Misspelled:** `ac thecnician chal gya g13 kl subha plss`

---

## 7. Advanced Provider Matching Algorithm

To assure the best match quality, the **Matching Agent** ranks candidates based on a 10-factor composite score:

$$\text{Composite Score} = \sum_{i=1}^{10} (\text{Factor Score}_i \times \text{Weight}_i)$$

```
┌─────────────────────────────────────────────────────────────┐
│                   Composite Scoring Factors                 │
├──────────────────────────────┬────────┬─────────────────────┤
│ Factor                       │ Weight │ Evaluation Metric   │
├──────────────────────────────┼────────┼─────────────────────┤
│ 1. Availability              │  15%   │ Clear calendar slot │
│ 2. Skill Specialization      │  15%   │ NLU match density   │
│ 3. On-Time Reliability       │  14%   │ Historical arrivals │
│ 4. Distance / Transit        │  12%   │ Haversine travel time│
│ 5. Overall Rating            │  12%   │ Weighted reviews    │
│ 6. Review Recency            │   8%   │ Star-recency decay  │
│ 7. Cancellation Risk         │   8%   │ Last 14 days cancel │
│ 8. Price Fit                 │   8%   │ Budget tolerance    │
│ 9. Capacity Headroom         │   4%   │ Remaining daily limit│
│ 10. User Preference          │   4%   │ Previous bookings   │
└──────────────────────────────┴────────┴─────────────────────┘
```

---

## 8. Job Complexity Classification

KaamYaab classifies requested work into distinct tiers to ensure appropriate provider routing:

1. **Basic:** Routine maintenance, minor adjustments. Enforces $\ge 1$ year of experience and basic tools.
2. **Intermediate:** Refills, fault diagnosis, electrical assembly. Enforces $\ge 3$ years of experience and specialized tools.
3. **Complex:** Unit replacements, wiring overhauls. Enforces $\ge 5$ years of experience, advanced certifications, and heavyweight equipment.

---

## 9. Dynamic Pricing Engine

KaamYaab calculates transparent, itemized quotes to ensure fairness:

```
  Base Rate (Provider Standard)
+ Distance Surcharge (PKR 30/km beyond 5km)
+ Complexity Premium (Basic: 0% · Intermediate: +20% · Complex: +40%)
+ Urgency Premium (Same-day: +25% · Next-morning: +10%)
+ Demand Surge (0-35% based on real-time zone requests)
- Loyalty Discount (5% reduction for returning clients)
- Budget Relief (Optional 5% discount for low-budget tags)
─────────────────────────────────────────────────────────────────
= Final Transparent Quote
```

---

## 10. Dispute & Escalation Workflow

When a dispute is initiated, the system executes an automated mediation protocol:

```
                  ┌──────────────────────────────┐
                  │       Dispute Category       │
                  └──────────────┬───────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
    [No-Show]           [Price Disagreement]    [Quality Complaint]
 ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
 │ Full refund  │        │ Verify quote │        │ Review photo │
 │ + PKR 200    │        │ vs charged.  │        │ evidence &   │
 │ compensation │        │ Refund delta │        │ DNA history. │
 └──────┬───────┘        └──────┬───────┘        └──────┬───────┘
        │                       │                       │
        ▼                       ▼                       ▼
 ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
 │ DNA penalty  │        │ Warn worker; │        │ Issue partial│
 │ (-15 points) │        │ DNA penalty  │        │ refund or go │
 │ and rebook.  │        │ if repetitive│        │ to review.   │
 └──────┬───────┘        └──────┬───────┘        └──────┬───────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                                ▼
                 ┌─────────────────────────────┐
                 │    Level 2 Trigger Gate     │
                 │   Escalate if disputes >=3  │
                 │   or value > PKR 5,000      │
                 └──────────────┬──────────────┘
                                │
                                ▼
                 ┌─────────────────────────────┐
                 │     Human Operator Review   │
                 │   Can apply permanent ban  │
                 └─────────────────────────────┘
```

---

## 11. Developer Installation & Setup

### Frontend Mobile App (Flutter)

#### 1. System Requirements
* Flutter SDK `^3.29.0`
* Android Studio (with emulator) or Xcode (for iOS simulations)

#### 2. Get Dependencies
Run this in the root directory:
```bash
flutter pub get
```

#### 3. Build & Run
To run the app with live Cohere integrations, launch using the `--dart-define` key injection:
```bash
flutter run --dart-define=COHERE_API_KEY=your_cohere_api_key_here
```

---

### Backend Agent Ecosystem (Python)

#### 1. Virtual Environment Setup
Navigate to the functions folder and create a virtual environment:
```bash
cd functions
python -m venv venv
```
Activate the environment:
* **Windows (Powershell):**
  ```powershell
  .\venv\Scripts\Activate.ps1
  ```
* **macOS/Linux:**
  ```bash
  source venv/bin/activate
  ```

#### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

#### 3. Configure Secrets
Create a `.env` file inside the `functions` directory and add your Cohere API Key:
```env
COHERE_API_KEY=your_cohere_api_key_here
```

#### 4. Run Self-Test Traces
Each agent contains a standalone self-test block. Execute these scripts to verify outputs and view reasoning traces:
```bash
# Test Intent Parsing
python agents/intent_agent.py

# Test Multi-Factor DNA Matcher
python agents/matching_agent.py

# Test Orchestrator flow (Surge, Pricing, Scheduling, Booking, Dispute)
python agents/orchestrator_agents.py
```

---

## 12. Engineering Rigor & Quality Control (Bug Fixes)

We maintain exceptional engineering discipline. Our production agents include key stabilization patches for high-stress transaction handling:

* **Price Negotiation Consistency (FIX-3):** Aligned `PricingAgent` and `MatchingAgent` price calculations to use a unified `_PRICE_FLOOR_RATIO = 0.85` limit, eliminating counter-offer synchronization failures.
* **Stateless Multi-Process Threading (FIX-4):** Removed module-level state variables in `orchestrator_agents.py` and replaced them with dependency-injected booking dictionaries, permitting seamless clustering across Cloud Run.
* **Service Coverage Expansion (FIX-5):** Re-coded the fallback classifier in `matching_agent.py` to use a global service parser covering all 12 operational categories, avoiding silent request drops for painting/carpentry.
* **Time Normalization Safeguards (FIX-7):** Integrated time-string standardizers (`_normalise_slot`) in `SchedulingAgent` and `MatchingAgent` so that different formats (e.g. `9:00` vs `09:00`) resolve to identical slots.
* **Surge Revenue Forecast Correction (FIX-8):** Fixed earnings estimation math in `ProviderOptimizationAgent` to incorporate real-time surge multipliers, correcting under-forecasting in high-traffic periods.
* **Escalation Loop Logic (BUG-12):** Replaced fuzzy string containment searches (`in`) with exact equality operators in `DisputeAgent` metrics, preventing incorrect reputation penalty applications.

---

## 13. Hackathon Demo & Pitch Simulator

KaamYaab includes a specialized **Hackathon Diagnostics Dashboard** to facilitate live pitching.

1. **Accessing the Dashboard:**
   * Compile and launch the Flutter mobile app.
   * Navigate to the **Account** tab, and press **Hackathon Diagnostics** (or route to `/agent-logs`).
2. **Simulations Supported:**
   * **Booking Alerts:** Triggers simulated push notifications confirming worker selection.
   * **ETA Tracker:** Triggers simulated travel coordinates and en-route bottom-sheet drawers.
   * **Completion Loops:** Simulates service checklist validations and user reviews.
   * **Disputes Live:** Simulates client disputes (e.g. overcharges) demonstrating automated DNA adjustments and refund actions.

---

*Built for Pakistan's Service Economy · For the Hackathon organized by Google Developers Group Pakistan, built in AntiGravity*
