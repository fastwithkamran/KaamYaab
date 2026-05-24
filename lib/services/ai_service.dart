import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/runtime_config.dart';

/// The core AI Agent for KaamYaab.
class AiService {
  static const String _cohereUrl = 'https://api.cohere.ai/v1/chat';

  /// Cohere model identifier — update in RuntimeConfig.cohereModel if the model changes.
  static String get _cohereModel => RuntimeConfig.cohereModel;

  static final String _cohereKey = RuntimeConfig.cohereApiKey.trim();

  static bool get _hasCohereKey => _cohereKey.isNotEmpty;

  // ─── Unified Conversational Agent ──────────────────────────────────────────

  static Future<Map<String, dynamic>> chat({
    required String userMessage,
    required List<Map<String, String>> cohereHistory,
    String userArea = 'Unknown',
    String userLanguage = 'mixed',
  }) async {
    final systemPrompt = '''
You are KaamYaab AI, a warm and helpful Pakistani assistant (Bhai-like).
Speak naturally in English, Urdu, or Roman Urdu (mixed).
Be informal, professional, and friendly. Use phrases like "Ji bhai", "Fikar na karein", "Theek hai", "Bilkul".

GOAL:
Help users book services: Plumbing, Electrical, AC Repair, Carpentry, Painting, Cleaning, Tutoring, Gardening, Cooking, Driving, Security.

KNOWLEDGE:
- User Current Area: $userArea
- Language: $userLanguage

YOUR DECISION LOGIC:
1. If the user just greets you (hi, salam), respond warmly and ask how you can help.
2. If the user asks a general question, answer it helpfully in a conversational way.
3. If the user wants a service but info is missing (e.g. they didn't say which service or where), ask them naturally in the chat.
4. If you have enough info (Service Type + Area), set action to "SEARCH".

Return ONLY JSON:
{
  "reply": "Conversational response in Roman Urdu/English",
  "action": "CHAT | SEARCH | CLARIFY",
  "search_params": {
    "service": "Plumbing | AC Repair | Electrical | Cleaning | etc.",
    "area": "neighborhood name",
    "urgency": "low | medium | high | emergency"
  }
}
''';

    if (_hasCohereKey) {
      final result = await _callCohere(
        userMessage,
        preamble: systemPrompt,
        chatHistory: cohereHistory,
      );
      if (result != null && result is Map) return Map<String, dynamic>.from(result);
    }

    return {
      'reply':
          "Bhai, net ka masla lag raha hai. I'm having trouble connecting, but I'm here for you! What do you need?",
      'action': 'CHAT',
      'search_params': null,
    };
  }

  // ─── Ranking Agent ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> rankProviders({
    required List<Map<String, dynamic>> providers,
    Map<String, dynamic>? intent,
    Map<String, dynamic>? searchParams,
    double? surgeMultiplier,
  }) async {
    final finalParams = intent ?? searchParams ?? {};
    final prompt = '''
User wants: ${jsonEncode(finalParams)}
Surge Multiplier: ${surgeMultiplier ?? 1.0}
Available Providers: ${jsonEncode(providers)}

Rank the top 3 providers based on match quality.
Return ONLY JSON:
{
  "ranked_ids": ["ID1", "ID2", ...],
  "reasoning": "Explain why these are the best in Roman Urdu/English",
  "top_choice_reasoning": "Brief English rationale for the #1 choice",
  "top_choice_reasoning_urdu": "Brief Urdu rationale for the #1 choice"
}
''';

    const preamble =
        'You are the Matching Agent for KaamYaab. You prioritize DNA score, reliability, and location proximity.';

    dynamic result;
    if (_hasCohereKey) result = await _callCohere(prompt, preamble: preamble);
    if (result != null && result is Map) return Map<String, dynamic>.from(result);

    return {
      'ranked_ids': providers.take(3).map((p) => p['id']).toList(),
      'reasoning': 'Using standard ranking due to connection issues.',
      'top_choice_reasoning': 'Best overall match based on rating and distance.',
      'top_choice_reasoning_urdu': 'ریٹنگ اور فاصلے کی بنیاد پر بہترین انتخاب۔',
    };
  }

  // ─── Negotiation Agent ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> negotiatePrice({
    required double originalQuote,
    required double userOffer,
    required String providerName,
    String? serviceType,
    int? providerDnaScore,
    double? surgeMultiplier,
    bool? isRepeatCustomer,
    double? workerMinRatePkr,
    String? workerNegotiationStyle,
  }) async {
    final prompt = '''
$providerName quoted Rs.$originalQuote for ${serviceType ?? "service"}. User offered Rs.$userOffer.
Context:
- Provider DNA Score: ${providerDnaScore ?? 750}
- Surge Multiplier: ${surgeMultiplier ?? 1.0}
- Is Repeat Customer: ${isRepeatCustomer ?? false}
- Worker Minimum Rate: ${workerMinRatePkr != null ? "Rs. $workerMinRatePkr" : "Not specified"}
- Worker Negotiation Style: ${workerNegotiationStyle ?? "moderate"}

Decide a fair counter-offer (min 85% of quote unless repeat customer or low surge, then counter could be lower; never go below worker minimum rate).
Return JSON:
{
  "counter_offer_pkr": number,
  "accepted": boolean,
  "reasoning": "Short friendly explanation for the user in Roman Urdu mixed with English (Pakistani style)"
}
''';

    const preamble =
        'You are the Negotiation Agent for KaamYaab. Be fair to both the worker and the customer.';

    dynamic result;
    if (_hasCohereKey) result = await _callCohere(prompt, preamble: preamble);
    if (result != null && result is Map) return Map<String, dynamic>.from(result);

    final floor = workerMinRatePkr ?? originalQuote * 0.8;
    double counter = originalQuote * 0.95;
    if (workerNegotiationStyle == 'flexible') {
      counter = originalQuote * 0.88;
    } else if (workerNegotiationStyle == 'firm') {
      counter = originalQuote * 0.98;
    }
    if (counter < floor) {
      counter = floor;
    }

    return {
      'counter_offer_pkr': counter,
      'accepted': userOffer >= counter,
      'reasoning': 'Bhai, thora sa adjust kar lein worker ke liye bhi.',
    };
  }

  // ─── Dispute Agent ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> analyzeDispute({
    required String disputeType,
    required String description,
    required double quotedPrice,
    required double chargedPrice,
    required int providerDnaScore,
    required int providerDisputeCount,
  }) async {
    final prompt = '''
Decide a fair resolution for this dispute.
Dispute Category: $disputeType
User Description: "$description"
Quoted Price: Rs. $quotedPrice
Charged Price: Rs. $chargedPrice
Provider DNA Score: $providerDnaScore
Provider Dispute Count: $providerDisputeCount
''';

    const systemPrompt = '''
You are the AI Judge for KaamYaab. Decide a fair resolution.

RESOLUTION POLICIES:
1. "user_favor": If the provider did not show up, quality is extremely poor, or they overcharged without agreement.
2. "provider_favor": If the user complains without a valid reason, or demands extra work not originally agreed upon.
3. "mediated": If both parties have some merit. Refund is typically 50% of the overcharge.
4. "escalate": If the situation is highly complex or abusive.

Return ONLY JSON:
{
  "verdict": "user_favor" | "provider_favor" | "mediated" | "escalate",
  "action": "full_refund" | "partial_refund" | "no_refund" | "warning_provider" | "ban_provider" | "escalated",
  "refund_amount_pkr": number,
  "penalty_to_provider": "none" | "warning" | "suspend" | "fined",
  "reasoning": "A warm, clear, fair explanation for the customer in Roman Urdu mixed with English.",
  "escalate_to_human": true | false
}
''';

    dynamic result;
    if (_hasCohereKey) result = await _callCohere(prompt, preamble: systemPrompt);

    if (result != null && result is Map) return Map<String, dynamic>.from(result);

    return {
      'verdict': 'mediated',
      'action': 'partial_refund',
      'refund_amount_pkr':
          (chargedPrice - quotedPrice) > 0 ? (chargedPrice - quotedPrice) * 0.5 : 0.0,
      'penalty_to_provider': 'warning',
      'reasoning':
          'Bhai, lagta hai network ka masla hai, par humne aapki shikayat ke mutabiq 50% refund mediate kar diya hai.',
      'escalate_to_human': false,
    };
  }

  // ─── Worker Onboarding Agent ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> processWorkerChat({
    required String message,
    required List<Map<String, String>> chatHistory,
    required String currentState,
    Map<String, dynamic>? partialProfile,
  }) async {
    final systemPrompt = '''
You are the Onboarding Agent for KaamYaab — a friendly Pakistani service marketplace.
Your job: guide a new worker (service provider) through setting up their profile step by step.
Speak in friendly Roman Urdu mixed with English (like a helpful bhai).
Use phrases like "Bilkul", "Theek hai bhai", "Bohat acha", "Shukriya".

CURRENT STATE: $currentState
PARTIALLY COLLECTED PROFILE SO FAR: ${partialProfile ?? {}}

PROFILE FIELDS TO COLLECT (in order):
1. greeting         → Welcome the worker, ask what service they provide.
2. asking_service   → Extract: category (Plumbing/Electrical/AC Repair/Carpentry/Painting/Cleaning/Tutoring/Gardening/Cooking/Driving/Security) and sub_role (their specialty e.g. "AC Gas Charging", "House Wiring").
3. asking_skills    → Extract: skills (list of specific tasks they can do, e.g. ["pipe fixing", "leak repair"]).
4. asking_experience → Extract: experience_years (integer, years of experience in their field).
5. asking_rates     → Ask for their charges. Extract: base_rate_pkr (standard hourly/per-job rate in PKR), min_rate_pkr (lowest they accept), max_rate_pkr (highest they charge). Also extract negotiation_style: "flexible" | "moderate" | "firm" based on how they describe their pricing.
6. asking_availability → Extract: availability_rules (list e.g. ["Monday to Friday", "9am to 6pm"]).
7. asking_bio       → Ask them to describe themselves in 1-2 lines. Extract: bio (short professional description).
8. confirming       → Summarize everything collected. Ask "Sab theek hai? Profile save kar dein?" Wait for YES/OK/Han/Confirm. If confirmed: set should_commit: true and next_state: "idle".

STATE TRANSITION RULES:
- greeting          → after welcome message: next_state = "asking_service"
- asking_service    → after extracting category+sub_role: next_state = "asking_skills"
- asking_skills     → after extracting skills: next_state = "asking_experience"
- asking_experience → after extracting experience_years: next_state = "asking_rates"
- asking_rates      → after extracting base_rate_pkr+min_rate_pkr: next_state = "asking_availability"
- asking_availability → after extracting availability_rules: next_state = "asking_bio"
- asking_bio        → after extracting bio: next_state = "confirming"
- confirming        → if user confirms (YES/OK/Han/Bilkul/Theek hai): set should_commit = true, next_state = "idle"
                    → if user says NO or wants to change something: go back to the relevant state
- If START_ONBOARDING message received: next_state = "asking_service"

IMPORTANT:
- Only collect one field/topic per message. Do NOT bombard with multiple questions at once.
- If the user provides extra info early (e.g. mentions their rate while giving service type), extract it and skip that state later.
- Always keep track of PARTIALLY COLLECTED PROFILE to avoid re-asking already-answered fields.
- For rates: ask in PKR (Pakistani Rupees). Help them if unsure (e.g. "e.g. agar aap Rs.500/hour lete hain toh woh base rate hai").
- For experience: accept any format ("5 saal", "3 years", "6 months" → convert to years as float).

Return ONLY valid JSON (no markdown, no code blocks):
{
  "reply": "Conversational response in Roman Urdu/English",
  "should_commit": false,
  "extracted_data": {
    "category": null,
    "sub_role": null,
    "skills": null,
    "experience_years": null,
    "base_rate_pkr": null,
    "min_rate_pkr": null,
    "max_rate_pkr": null,
    "negotiation_style": null,
    "availability_rules": null,
    "bio": null
  },
  "next_state": "asking_service",
  "reasoning": "Brief internal note",
  "is_mock": false
}
Only include non-null values in extracted_data that were actually mentioned by the user in THIS message.
''';

    dynamic result;
    if (_hasCohereKey) {
      result = await _callCohere(message, preamble: systemPrompt, chatHistory: chatHistory);
    }
    if (result != null && result is Map) return Map<String, dynamic>.from(result);

    // Fallback: generate a contextual response and transition states
    String nextState = currentState;
    Map<String, dynamic> extractedData = {};
    bool shouldCommit = false;

    final msgLower = message.trim().toLowerCase();

    if (message == 'START_ONBOARDING') {
      nextState = 'asking_service';
    } else {
      switch (currentState) {
        case 'greeting':
        case 'asking_service':
          String category = 'Plumber';
          if (msgLower.contains('plumb')) {
            category = 'Plumber';
          } else if (msgLower.contains('electr')) {
            category = 'Electrician';
          } else if (msgLower.contains('ac') || msgLower.contains('cool')) {
            category = 'AC Technician';
          } else if (msgLower.contains('carp')) {
            category = 'Carpenter';
          } else if (msgLower.contains('paint')) {
            category = 'Painter';
          } else if (msgLower.contains('clean')) {
            category = 'Cleaner';
          } else if (msgLower.contains('driv')) {
            category = 'Driver';
          } else if (msgLower.contains('guard') || msgLower.contains('sec')) {
            category = 'Security Guard';
          } else if (msgLower.contains('cook')) {
            category = 'Cook';
          } else if (msgLower.contains('mason')) {
            category = 'Mason';
          } else {
            category = message;
          }

          extractedData = {
            'category': category,
            'sub_role': '$category Specialist',
          };
          nextState = 'asking_skills';
          break;

        case 'asking_skills':
          List<String> skills = message.split(RegExp(r'[,|و]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (skills.isEmpty) skills = [message];
          extractedData = {
            'skills': skills,
          };
          nextState = 'asking_experience';
          break;

        case 'asking_experience':
          int years = int.tryParse(RegExp(r'\d+').stringMatch(message) ?? '') ?? 3;
          extractedData = {
            'experience_years': years,
          };
          nextState = 'asking_rates';
          break;

        case 'asking_rates':
          final numbers = RegExp(r'\d+').allMatches(message).map((m) => double.tryParse(m.group(0) ?? '') ?? 0.0).toList();
          double base = 800.0;
          double min = 600.0;
          double max = 1200.0;
          if (numbers.length >= 3) {
            base = numbers[0];
            min = numbers[1];
            max = numbers[2];
          } else if (numbers.length == 2) {
            base = numbers[0];
            min = numbers[1];
            max = base * 1.5;
          } else if (numbers.length == 1) {
            base = numbers[0];
            min = base * 0.8;
            max = base * 1.5;
          }
          extractedData = {
            'base_rate_pkr': base,
            'min_rate_pkr': min,
            'max_rate_pkr': max,
            'negotiation_style': 'moderate',
          };
          nextState = 'asking_availability';
          break;

        case 'asking_availability':
          extractedData = {
            'availability_rules': [message],
          };
          nextState = 'asking_bio';
          break;

        case 'asking_bio':
          extractedData = {
            'bio': message,
          };
          nextState = 'confirming';
          break;

        case 'confirming':
          final yesWords = ['yes', 'yup', 'haan', 'han', 'ok', 'theek', 'bilkul', 'confirm', 'done', 'جی', 'ہاں', 'ٹھیک'];
          bool confirmed = yesWords.any((w) => msgLower.contains(w)) || msgLower.startsWith('h') || msgLower.startsWith('y');
          if (confirmed) {
            shouldCommit = true;
            nextState = 'idle';
          } else {
            shouldCommit = true;
            nextState = 'idle';
          }
          break;
      }
    }

    final fallbackReply = _workerOnboardingFallback(nextState, {...?partialProfile, ...extractedData});
    return {
      'reply': fallbackReply,
      'should_commit': shouldCommit,
      'extracted_data': extractedData,
      'next_state': nextState,
      'reasoning': 'API call fallback with state machine transition.',
      'is_mock': true,
    };
  }

  /// Fallback responses for worker onboarding when API is unavailable.
  static String _workerOnboardingFallback(String state, Map<String, dynamic> profile) {
    switch (state) {
      case 'greeting':
      case 'asking_service':
        return 'Assalam o Alaikum bhai! KaamYaab mein aapka swaagat hai! 🎉\n\nAap kaun si service provide karte hain? Jaise Plumbing, Electrical, AC Repair, Carpentry, Painting, Cleaning, Tutoring wagera?';
      case 'asking_skills':
        return 'Bohat acha! Ab batayein aap exactly kaun kaun se kaam karte hain? Jaise specific tasks ya specialties?';
      case 'asking_experience':
        return 'Shukriya! Aap kitne saalon se yeh kaam kar rahe hain? Experience batayein please.';
      case 'asking_rates':
        return 'Theek hai! Ab aapki fees ke baare mein batayein:\n• Aap normally kitna charge karte hain? (Base rate in PKR)\n• Minimum kitna accept karte hain?\n• Maximum kitna charge karte hain?';
      case 'asking_availability':
        return 'Perfect! Aap kab available hote hain kaam ke liye? Jaise "Monday to Saturday, 9am to 6pm"?';
      case 'asking_bio':
        return 'Excellent! Last step — apne baare mein 1-2 lines mein batayein jo customers dekh sakein. Kuch aisa: "10 saal ka tajurba, reliable aur professional service."';
      case 'confirming':
        return 'Aapka profile ready hai! Kya sab theek lag raha hai? "Han" ya "OK" likhein toh main profile save kar deta hoon.';
      case 'idle':
        return 'Bohat acha bhai! 🎉 Aapka profile save ho gaya hai.\n\nAb aap job requests receive karna shuru karein ge. KaamYaab par aapka khushamadeed!';
      default:
        return 'Ji bhai, thora network slow lag raha hai. Dobara try karein please.';
    }
  }

  // ─── Legacy redirect ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> extractIntent(String rawInput) async {
    final res = await chat(
      userMessage: rawInput,
      cohereHistory: [],
      userArea: 'Unknown',
      userLanguage: 'english',
    );
    if (res['action'] == 'SEARCH') {
      return {
        ...res['search_params'] as Map<String, dynamic>,
        'confidence': 0.9,
        'clarification_needed': false,
      };
    }
    return {
      'service_type': 'Unknown',
      'confidence': 0.4,
      'clarification_needed': true,
      'clarification_question': res['reply'],
    };
  }

  // ─── Cohere API Helper ─────────────────────────────────────────────────────

  static Future<dynamic> _callCohere(
    String prompt, {
    String? preamble,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      final payload = {
        'message': prompt,
        'model': _cohereModel,
        'preamble': preamble ?? '',
        'temperature': 0.1,
        if (chatHistory != null) 'chat_history': chatHistory,
      };

      final response = await http.post(
        Uri.parse(_cohereUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_cohereKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Parse the response body — isolated try-catch so a malformed JSON
        // response never propagates as an unhandled exception to the caller.
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = data['text'] as String;
          if (kDebugMode) debugPrint('COHERE RESPONSE: $text');
          final cleaned =
              text.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(cleaned);
        } catch (parseError) {
          if (kDebugMode) debugPrint('Cohere parse error: $parseError');
          return null;
        }
      } else {
        if (kDebugMode) {
          debugPrint('COHERE STATUS: ${response.statusCode}');
          debugPrint('COHERE BODY: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Cohere HTTP error: $e');
      return null;
    }
  }
}