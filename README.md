# Challenge 2: AI Service Orchestrator for Informal Economy

## 📌 Challenge Overview
The informal service economy—comprising plumbers, electricians, tutors, and local technicians—often suffers from fragmented discovery and a lack of trust. Service matching typically happens via informal networks like WhatsApp or word-of-mouth, leading to unpredictable pricing and poor follow-up.

This challenge tasks participants with building an **agentic system** that automates the end-to-end service lifecycle. From natural-language intent extraction to dispute resolution, the system must provide a seamless bridge between local professionals and customers.

---

## 📑 Problem Statement
The goal is to develop a system capable of:
*   **Multilingual Understanding:** Processing requests in Urdu, Roman Urdu, English, and code-switched "hinglish/urdish" text.
*   **Intent Extraction:** Identifying service type, location, urgency, and constraints.
*   **Provider Discovery:** Utilizing mock data or real-world APIs (Google Maps/Places) to find the best local talent.
*   **Dynamic Logic:** Implementing complex ranking, pricing, and scheduling algorithms.
*   **Full Lifecycle Simulation:** Managing bookings, reminders, service progress, and reputation updates.

---

## 🛠 Mandatory Requirement: Google Antigravity
> [!IMPORTANT]
> **Google Antigravity** must serve as the core orchestrator for all agentic workflows.

*   **Orchestration:** Use Antigravity for intent understanding, provider matching, and scheduling logic.
*   **Transparency:** You must provide **Antigravity reasoning traces** for every major decision (e.g., why Provider A was chosen over Provider B).
*   **Integration:** While you may use external LLMs or Maps APIs, Antigravity must control the execution flow and decision-making.

---

## ⚙️ System Requirements

### 1. Multilingual & Noisy Input Handling
*   Handle slang and code-switching (e.g., *"Mujhe kal morning main AC service chahiye"*).
*   Provide confidence scores; trigger confirmation questions if the intent is ambiguous.

### 2. Advanced Provider Matching
Rank providers based on at least **six factors**:
*   Distance & travel time
*   Availability & capacity
*   Rating & review recency
*   Reliability (on-time score)
*   Skill specialization & job complexity (Basic/Intermediate/Complex)
*   Cancellation rates & risk scores

### 3. Scheduling & Pricing Intelligence
*   **Scheduling:** Prevent double bookings, include travel-time buffers, and handle auto-rescheduling for cancellations.
*   **Dynamic Pricing:** Calculate quotes based on demand, urgency, distance, and provider experience. Provide a transparent breakdown for fairness.

### 4. Service-Quality & Dispute Loop
*   **Execution:** Simulate en-route updates and service completion checklists.
*   **Feedback:** Collect ratings and photo/video evidence.
*   **Disputes:** Handle no-shows, price disagreements, and refund requests via an escalation workflow.

---

## 🏃 Example Scenario
*   **User Input:** *"AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai."*
*   **Antigravity Understanding:** 
    *   **Service:** AC Repair | **Urgency:** High | **Location:** G-13 | **Constraint:** Budget Sensitive.
*   **Decision:** System recommends Provider A (Higher reliability) over Provider B (Closer proximity) due to specialized repair history.
*   **Result:** Generates a quote with a visit fee breakdown and schedules a 10:00 AM slot.

---

## 🧪 Stress-Test Scenarios
Your system should be robust enough to handle:
1.  **Zero Availability:** No providers found in the requested window.
2.  **Provider Flaking:** A provider cancels 30 minutes before the appointment.
3.  **Conflict Resolution:** Two users booking the same "last available" provider simultaneously.
4.  **Trust Issues:** Matching a high-rated provider who has had a recent string of negative reviews.

---

## 📦 Deliverables
*   **Working Prototype:** Mobile App (Mandatory) / Web App (Optional).
*   **Demo Video:** A 3-5 minute walkthrough of the entire user journey.
*   **Reasoning Logs:** Antigravity agent traces showing the logic behind ranking, pricing, and fallbacks.
*   **README:** Documentation covering architecture, data schemas, cost/latency analysis, and privacy notes.

---

## 📊 Evaluation Criteria

| Criteria | Weight |
| :--- | :--- |
| **Antigravity Integration** | 20% |
| **Matching & Decision Quality** | 25% |
| **Multilingual Robustness** | 15% |
| **Workflow Logic (Scheduling/Pricing)** | 15% |
| **Dispute & Reliability Handling** | 15% |
| **Innovation & UX** | 10% |
