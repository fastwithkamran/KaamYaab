import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/runtime_config.dart';

/// The core AI Agent for KaamYaab. 
/// Removed all rigid rule-based parsing to allow for true conversational intelligence.
class AiService {
  static const String _cohereUrl = 'https://api.cohere.ai/v1/chat';
  static final String _cohereKey = RuntimeConfig.cohereApiKey.trim();

  static bool get _hasCohereKey => _cohereKey.isNotEmpty && _cohereKey != 'YOUR_COHERE_API_KEY_HERE';

  // ─── Unified Conversational Agent ──────────────────────────────────────────
  /// The single entry point for user interaction. 
  /// Decides whether to just talk, search for workers, or ask for details.
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
      final result = await _callCohere(userMessage, preamble: systemPrompt, chatHistory: cohereHistory);
      if (result != null && result is Map) return Map<String, dynamic>.from(result);
    }

    // Basic Mock for chat
    return {
      'reply': "Bhai, net ka masla lag raha hai. I'm having trouble connecting, but I'm here for you! What do you need?",
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

    final preamble = "You are the Matching Agent for KaamYaab. You prioritize DNA score, reliability, and location proximity.";
    
    dynamic result;
    if (_hasCohereKey) result = await _callCohere(prompt, preamble: preamble);
    if (result != null && result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {
      'ranked_ids': providers.take(3).map((p) => p['id']).toList(),
      'reasoning': "Using standard ranking due to connection issues.",
      'top_choice_reasoning': "Best overall match based on rating and distance.",
      'top_choice_reasoning_urdu': "ریٹنگ اور فاصلے کی بنیاد پر بہترین انتخاب۔",
    };
  }

  // ─── Negotiation Agent ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> negotiatePrice({
    required double originalQuote,
    required double userOffer,
    required String providerName,
    String? serviceType,
    int? providerDnaScore,
    double? surgeMultiplier,
    bool? isRepeatCustomer,
  }) async {
    final prompt = '''
$providerName quoted Rs.$originalQuote for ${serviceType ?? "service"}. User offered Rs.$userOffer.
Context:
- Provider DNA Score: ${providerDnaScore ?? 750}
- Surge Multiplier: ${surgeMultiplier ?? 1.0}
- Is Repeat Customer: ${isRepeatCustomer ?? false}

Decide a fair counter-offer (min 85% of quote unless repeat customer or low surge, then counter could be lower).
Return JSON:
{
  "counter_offer_pkr": number,
  "accepted": boolean,
  "reasoning": "Short friendly explanation for the user in Roman Urdu mixed with English (Pakistani style)"
}
''';

    final preamble = "You are the Negotiation Agent for KaamYaab. Be fair to both the worker and the customer.";
    
    dynamic result;
    if (_hasCohereKey) result = await _callCohere(prompt, preamble: preamble);
    if (result != null && result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {
      'counter_offer_pkr': originalQuote * 0.95,
      'accepted': userOffer >= originalQuote * 0.9,
      'reasoning': "Bhai, thora sa adjust kar lein worker ke liye bhi.",
    };
  }

  // ─── Cohere API Helper ─────────────────────────────────────────────────────
  static Future<dynamic> _callCohere(String prompt, {String? preamble, List<Map<String, String>>? chatHistory}) async {
    try {
      final payload = {
        'message': prompt,
        'model': 'command-r',
        'preamble': preamble ?? '',
        'temperature': 0.1,
        if (chatHistory != null) 'chat_history': chatHistory,
      };

      final response = await http.post(Uri.parse(_cohereUrl), 
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_cohereKey'},
        body: jsonEncode(payload));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned);
      }
    } catch (e) { debugPrint('Cohere Error: $e'); }
    return null;
  }

  // ─── Legacy Fallbacks (Redirected) ──────────────────────────────────────────
  static Future<Map<String, dynamic>> extractIntent(String rawInput) async {
    final res = await chat(
      userMessage: rawInput,
      cohereHistory: [],
      userArea: 'Unknown',
      userLanguage: 'english',
    );
    if (res['action'] == 'SEARCH') {
      return {...res['search_params'], 'confidence': 0.9, 'clarification_needed': false};
    }
    return {'service_type': 'Unknown', 'confidence': 0.4, 'clarification_needed': true, 'clarification_question': res['reply']};
  }

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

    final systemPrompt = '''
You are the AI Judge for KaamYaab. Decide a fair resolution.
Use your judgment to decide in user's favor, provider's favor, or mediate a settlement.

RESOLUTION POLICIES:
1. "user_favor": If the provider did not show up (no-show), quality is extremely poor, or they overcharged without user's agreement. Refund amount can be up to the charged amount.
2. "provider_favor": If the user complains without a valid reason, or demands extra work not originally agreed upon. Refund is Rs. 0.
3. "mediated": If both parties have some merit (e.g. extra work was done but price wasn't clearly agreed). Refund is typically a portion of the difference (e.g. 50% of the overcharge).
4. "escalate": If the situation is highly complex or abusive.

Return ONLY JSON:
{
  "verdict": "user_favor" | "provider_favor" | "mediated" | "escalate",
  "action": "full_refund" | "partial_refund" | "no_refund" | "warning_provider" | "ban_provider" | "escalated",
  "refund_amount_pkr": number,
  "penalty_to_provider": "none" | "warning" | "suspend" | "fined",
  "reasoning": "A warm, clear, and fair explanation for the customer in Roman Urdu mixed with English (Pakistani style), explaining why the decision was made.",
  "escalate_to_human": true | false
}
''';

    dynamic result;
    if (_hasCohereKey) {
      result = await _callCohere(prompt, preamble: systemPrompt);
    }

    if (result != null && result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return result ?? {
      'verdict': 'mediated',
      'action': 'partial_refund',
      'refund_amount_pkr': (chargedPrice - quotedPrice) > 0 ? (chargedPrice - quotedPrice) * 0.5 : 0.0,
      'penalty_to_provider': 'warning',
      'reasoning': 'Bhai, lagta hai network ka masla hai, par humne aapki shikayat ke mutabiq 50% refund mediate kar diya hai.',
      'escalate_to_human': false
    };
  }

  static Future<Map<String, dynamic>> processWorkerChat({
    required String message,
    required List<Map<String, String>> chatHistory,
    required String currentState,
  }) async {
    final systemPrompt = '''
You are the Onboarding Agent for KaamYaab. Your goal is to guide a new service provider (worker) through their profile setup.
Identify their:
1. Category of service (e.g. Plumbing, AC Repair, Electrical, Carpentry, Painting, Cleaning, Tutoring, Gardening, Cooking, Driving, Security).
2. Specific skills/sub-services.
3. Availability rules (e.g. weekdays, 9am-5pm).

CURRENT STATE: $currentState

STATE TRANSITION LOGIC:
- If currentState is "asking_service", listen to what service they offer.
  * If they mention a service, extract it in "category", and transition to "asking_skills". Ask them to specify their specific skills or tools they are good at in that category.
  * If they do not specify a service, keep next_state as "asking_service" and ask them again nicely.
- If currentState is "asking_skills", listen to their skills.
  * If they list skills, extract them as a list of strings in "skills", and transition to "asking_availability". Ask them what days or times they are available to work.
  * If they do not specify skills, keep next_state as "asking_skills" and ask them again.
- If currentState is "asking_availability", listen to their availability.
  * If they say something like "anytime", "weekdays", or specific times, extract it as list of strings in "availability_rules". Set "should_commit" to true and transition next_state to "idle".
  * Thank them and welcome them to KaamYaab.

CONVERSATIONAL TONE:
- Be informal, friendly, and speak in a warm Roman Urdu mixed with English (e.g. "Bilkul sahi", "Fikar na karein", "Bhai", "Ji bilkul").
- Ensure your reply is conversational.

Return ONLY JSON:
{
  "reply": "Conversational reply in Roman Urdu/English",
  "should_commit": true | false,
  "extracted_data": {
    "category": "Plumbing" | "Electrical" | "AC Repair" | etc.,
    "skills": ["pipe fixing", "leak repair", ...],
    "availability_rules": ["Monday to Friday", "9am - 5pm", ...]
  },
  "next_state": "asking_service" | "asking_skills" | "asking_availability" | "idle",
  "reasoning": "Brief technical explanation of why you made this decision",
  "is_mock": false
}
''';

    dynamic result;
    if (_hasCohereKey) {
      result = await _callCohere(message, preamble: systemPrompt, chatHistory: chatHistory);
    }
    if (result != null && result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return result ?? {
      'reply': "Ji bhai, thora network slow lag raha hai. Apne details dobara likhein taake main process kar sakoon.",
      'should_commit': false,
      'extracted_data': {},
      'next_state': currentState,
      'reasoning': 'API call fallback due to missing keys or timeout.',
      'is_mock': true,
    };
  }
}