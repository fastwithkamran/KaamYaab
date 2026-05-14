Challenge 2: AI Service Orchestrator for Informal Economy

CHALLENGE OVERVIEW
Informal service economy includes plumbers, electricians, tutors, beauticians, drivers, mechanics, AC technicians, home service providers, and small local professionals. Service discovery often happens through WhatsApp, phone calls, referrals, and informal networks, causing missed opportunities, poor matching, unpredictable pricing, weak follow-up, and limited trust. This challenge requires an agentic system that automates the end-to-end service lifecycle from natural-language request to matching, scheduling, pricing, booking, follow-up, quality feedback, and dispute handling.
PROBLEM STATEMENT
Understand multilingual service requests (for example Urdu, Roman Urdu, English, and mixed/code-switched language).
Extract service type, location, urgency, preferred time, constraints, and user preferences.
Discover providers using mock data, Google Maps/Places, or other APIs.
Rank providers using a multi-factor matching algorithm rather than distance alone.
Generate dynamic price quotes with transparent breakdowns.
Simulate booking, confirmation, reminders, service progress, feedback, reputation updates, and dispute resolution.
MANDATORY REQUIREMENT: GOOGLE ANTIGRAVITY
Use Google Antigravity as the main orchestrator for intent understanding, matching, scheduling, pricing, booking, follow-up, and service-quality workflows.
Show Antigravity reasoning traces for provider selection, price estimation, scheduling conflicts, confirmation actions, and dispute escalation. External LLMs, Maps/Places APIs, spreadsheets, mock datasets, and messaging APIs may be used, but Antigravity must control the agentic workflow.
SYSTEM REQUIREMENTS
Multilingual and noisy input handling: Handle Urdu, Roman Urdu, English, misspellings, slang, and code-switching such as "Mujhe kal morning main AC service chahiye". Provide confidence score and confirmation questions when confidence is low.
Advanced provider matching: Use at least six factors: distance/travel time, availability, rating, review recency, reliability/on-time score, skill specialization, price, capacity, cancellation rate, user preference, and risk score.
Skill and job complexity classification: Classify job complexity as basic, intermediate, or complex and match to provider specialization, experience, tools, or certifications.
Scheduling intelligence: Prevent double booking, include travel-time buffers, suggest alternate slots, manage waitlists, and reschedule automatically if a provider cancels.
Dynamic pricing: Calculate price using demand, urgency, distance, service complexity, provider rate, loyalty discount, and surge conditions. Show breakdown and fairness to both user and provider.
Booking simulation: Simulate booking confirmation, provider assignment, calendar update, SMS/WhatsApp notification, receipt, and database/spreadsheet update.
Service-quality loop: Simulate en-route update, service completion checklist, photo/video evidence placeholder, customer feedback, rating adjustment, and future matching impact.
Dispute and escalation workflow: Handle no-show, cancellation, quality complaint, price disagreement, overrun, refund, compensation, blacklist, or human escalation simulation.
Provider-side optimization: Show provider workload balancing, fair earning opportunity, demand forecasting, or recommended time slots for provider utilization.
Robustness and fallback: Handle no provider available, low-confidence language parsing, Maps/API failure, payment confirmation failure, and user preference conflicts.
EXAMPLE SCENARIO
User input: "AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai."
Understanding: Service = AC repair; issue severity = high; location = G-13; time = tomorrow morning; price sensitivity = high.
Matching: Ranks providers using travel time, availability, AC specialization, on-time score, review sentiment, rate, cancellation risk, and capacity.
Decision: Recommends Provider A despite Provider B being closer because Provider A has higher reliability and specialized AC repair reviews.
Pricing: Generates quote with visit fee, distance cost, urgency adjustment, and budget-sensitive alternative.
Simulation: Books 10:00 AM slot, sends confirmation, updates booking sheet, schedules reminder, simulates provider en-route update, collects feedback, and updates reputation score.
RECOMMENDED STRESS-TEST SCENARIOS
No suitable provider is available in the requested time window.
A provider cancels after confirmation and the system must reschedule.
User input is misspelled, mixed-language, or ambiguous.
Two users request the same provider at overlapping times.
Customer disputes price or quality after service completion. Provider has high rating but recent negative reviews and high cancellation rate.
DELIVERABLES
Working prototype with a mobile app as mandatory and web app as optional.
Demo video of 3-5 minutes showing user request -> intent extraction -> provider ranking -> pricing -> booking -> follow-up -> feedback/dispute workflow.
Antigravity agent trace/logs showing language parsing confidence, provider ranking rationale, scheduling decisions, price logic, action execution, and fallback behavior.
README with architecture, provider dataset schema, matching factors, Antigravity workflow, APIs/tools, assumptions, cost/latency analysis, baseline comparison, privacy note, and limitations.
EVALUATION CRITERIA
Antigravity integration 20%
Matching and decision quality 25%
Multilingual robustness and edge cases 15%
Scheduling, pricing and service workflow 15%
Dispute handling, reliability and scalability 15%
Innovation and UX 10%

