import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/runtime_config.dart';

/// Bridges Flutter app to the Cohere Chat API for all AI agent operations.
/// Replaces GeminiService to take advantage of Cohere's generous free tier.
class AiService {
  static const String _baseUrl = 'https://api.cohere.ai/v1/chat';

  static final String _apiKey = RuntimeConfig.cohereApiKey.trim();
  static bool get _hasApiKey => _apiKey.isNotEmpty;
  static const int _maxRetries = 3;
  // Actual backoff series: 1s, 2s, 4s, 4s (capped). Total max wait ≈ 11s across 3 retries.
  static const int _maxBackoffSeconds = 4;

  // ─── Intent Agent ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> extractIntent(String rawInput) async {
    if (!_hasApiKey) return _mockIntentParse(rawInput);

    final prompt = '''
Analyze this user request (may be Urdu, Roman Urdu, English, or mixed language):
"$rawInput"

IMPORTANT: You must reason through the request. If the user uses slang or local terms (e.g. "nal", "bijli", "tanda"), map them correctly.
Always extract the actual area/city from the text — do NOT default to any sector unless explicitly mentioned.

Return ONLY a JSON object with these exact fields:
{
  "service_type": "one of: Plumbing | AC Repair | Electrical | Cleaning | Carpentry | Painting | Tutoring | Gardening | Security Guard | Driver | Cook | Unknown",
  "location": "the full location/city string",
  "area": "extracted sector/neighborhood",
  "urgency": "low | medium | high | emergency",
  "preferred_time": "morning | afternoon | evening | flexible",
  "preferred_date": "today | tomorrow | flexible",
  "budget_sensitivity": 0.0 to 1.0,
  "confidence": 0.0 to 1.0,
  "language": "urdu | roman_urdu | english | mixed",
  "reasoning_steps": "1-sentence internal logic in English about how you parsed this",
  "clarification_needed": boolean,
  "clarification_question": "question in same language if confidence < 0.75",
  "job_complexity": "basic | intermediate | complex"
}
''';

    final result = await _callCohere(prompt, preamble: "You are the Intent Agent for KaamYaab, Pakistan's AI-powered service marketplace.");
    if (result != null) return result;

    return _mockIntentParse(rawInput);
  }

  // ─── Matching Agent ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> rankProviders({
    required Map<String, dynamic> intent,
    required List<Map<String, dynamic>> providers,
    required double surgeMultiplier,
  }) async {
    if (!_hasApiKey) {
      return {'ranked_ids': providers.take(3).map((p) => p['id']).toList(), 'top_choice_reasoning': 'Using mock ranking.'};
    }

    final prompt = '''
User Request Intent:
${jsonEncode(intent)}

Current Surge Multiplier: ${surgeMultiplier}x

Available Providers (JSON):
${jsonEncode(providers)}

YOUR TASK:
1. Analyze each provider based on distance, rating, skills, price vs budget, and reliability.
2. Handle Roman Urdu/Urdu context in the request.
3. Return a ranked list of the top 5 Provider IDs.
4. Provide a 2-sentence "reasoning" in English for the top choice.
5. Provide a 2-sentence "reasoning_urdu" in Urdu for the top choice.

Return ONLY JSON:
{
  "ranked_ids": ["ID1", "ID2", ...],
  "top_choice_reasoning": "...",
  "top_choice_reasoning_urdu": "...",
  "surge_explanation": "why this surge is applied or not"
}
''';

    final result = await _callCohere(prompt, preamble: "You are the Matching Agent for KaamYaab. Your goal is to rank the best service providers for a user request.");
    if (result != null) return result;

    return {'ranked_ids': providers.take(3).map((p) => p['id']).toList(), 'top_choice_reasoning': 'Ranking failed, used fallback.'};
  }

  // ─── Negotiation Agent ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> negotiatePrice({
    required double originalQuote,
    required double userOffer,
    required String serviceType,
    required int providerDnaScore,
    required double surgeMultiplier,
    required bool isRepeatCustomer,
    required String providerName,
  }) async {
    if (!_hasApiKey) return _mockNegotiation(originalQuote, userOffer, isRepeatCustomer, surgeMultiplier, providerName);

    final prompt = '''
A user is negotiating price for a $serviceType booking.
- Original quote: Rs. ${originalQuote.toStringAsFixed(0)}
- User's offer: Rs. ${userOffer.toStringAsFixed(0)}
- Provider DNA Score: $providerDnaScore/1000
- Current surge multiplier: ${surgeMultiplier}x
- Repeat customer: $isRepeatCustomer
- Provider: $providerName

Decide the fair counter-offer considering surge, loyalty, and DNA score. Never go below 85% of original quote.

Return JSON:
{
  "counter_offer_pkr": number,
  "accepted": true or false,
  "reasoning": "short explanation asking the provider to accommodate",
  "discount_applied_pkr": number,
  "discount_reason": "loyalty | surge_offset | off_peak | none",
  "is_final_offer": true or false
}
''';

    final result = await _callCohere(prompt, preamble: "You are the Negotiation Agent for KaamYaab.");
    if (result != null) return result;

    return _mockNegotiation(originalQuote, userOffer, isRepeatCustomer, surgeMultiplier, providerName);
  }

  // ─── Dispute Analysis Agent ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeDispute({
    required String disputeType,
    required String description,
    required double quotedPrice,
    required double chargedPrice,
    required int providerDnaScore,
    required int providerDisputeCount,
  }) async {
    if (!_hasApiKey) return _mockDisputeAnalysis(disputeType, quotedPrice, chargedPrice, providerDnaScore);

    final prompt = '''
Dispute type: $disputeType
User description: "$description"
Quoted price: Rs. $quotedPrice
Charged price: Rs. $chargedPrice
Provider DNA Score: $providerDnaScore/1000
Provider's past disputes: $providerDisputeCount

Analyze and return JSON:
{
  "verdict": "user_favor | provider_favor | mediated | escalate_human",
  "action": "full_refund | partial_refund | no_refund | rebook | warning | blacklist",
  "refund_amount_pkr": number or 0,
  "penalty_to_provider": "none | warning | dna_penalty | soft_ban | blacklist",
  "reasoning": "2-3 sentence explanation",
  "escalate_to_human": true or false
}
''';

    final result = await _callCohere(prompt, preamble: "You are the Dispute Agent for KaamYaab.");
    if (result != null) return result;

    return _mockDisputeAnalysis(disputeType, quotedPrice, chargedPrice, providerDnaScore);
  }

  // ── Worker Service Agent ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> extractWorkerService(String input) async {
    if (!_hasApiKey) return {'category': 'General Helper', 'skills': [input.split(' ').first]};

    final prompt = '''
A new worker just told you what they do: "$input"

Determine their main Service Category and list their Skills.
Service Category must be ONE of: Plumbing | AC Repair | Electrical | Cleaning | Carpentry | Painting | Tutoring | Gardening | Security Guard | Driver | Cook | General Helper

Return ONLY a JSON object:
{
  "category": "The selected category",
  "skills": ["Skill 1", "Skill 2"]
}
''';

    final result = await _callCohere(prompt, preamble: "You are the KaamYaab Worker Onboarding Agent.");
    if (result != null) return result;

    return {'category': 'General Helper', 'skills': [input.split(' ').first]};
  }

  // ── Worker Settings Agent ──────────────────────────────────────────────────
  static Future<List<String>> processWorkerSettings(String input, List<String> currentRules) async {
    if (!_hasApiKey) {
      final updated = List<String>.from(currentRules);
      updated.add(input);
      return updated;
    }

    final prompt = '''
Input: "$input"
Current Rules: ${currentRules.join(', ')}

Please extract the new availability rules, and update the current rules list.
Return the updated list as a JSON array of strings representing the distinct rules in simple, concise English.
Only return the JSON array.
''';

    final result = await _callCohere(prompt, preamble: "You are the KaamYaab Worker Agent.");
    if (result != null && result is List) {
      return result.map((e) => e.toString()).toList();
    }
    // Note: A Map-with-'rules' branch was previously here but was unreachable
    // because the model returns a JSON array, not a Map.

    final updated = List<String>.from(currentRules);
    updated.add(input);
    return updated;
  }

  // ─── API Helper ─────────────────────────────────────────────────────────────
  static Future<dynamic> _callCohere(String prompt, {String? preamble}) async {
    try {
      final response = await _postWithRetry({
        'message': prompt,
        'model': 'command-r',
        'preamble': preamble ?? '',
        'temperature': 0.1,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned);
      }
    } catch (e) {
      debugPrint('Cohere API Error: $e');
    }
    return null;
  }

  static Future<http.Response> _postWithRetry(Map<String, dynamic> payload) async {
    http.Response? lastResponse;
    for (var retry = 0; retry <= _maxRetries; retry++) {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(payload),
      );
      lastResponse = response;
      if (response.statusCode < 400) return response;

      final isRetryable = response.statusCode == 429 || response.statusCode >= 500;
      if (retry == _maxRetries || !isRetryable) return response;

      final delaySeconds = min(_maxBackoffSeconds, pow(2, retry).toInt());
      await Future.delayed(Duration(seconds: max(1, delaySeconds)));
    }
    return lastResponse!;
  }

  // ── Mock Fallbacks ───────────────────────────────
  static Map<String, dynamic> _mockIntentParse(String rawInput) {
    final lower = rawInput.toLowerCase();
    String service = 'Unknown';
    if (lower.contains('plumber') || lower.contains('pani') || lower.contains('leak')) service = 'Plumbing';
    else if (lower.contains('ac') || lower.contains('thanda')) service = 'AC Repair';
    else if (lower.contains('bijli') || lower.contains('light')) service = 'Electrical';
    
    return {
      'service_type': service,
      'location': 'Islamabad',
      'area': 'G-13',
      'urgency': lower.contains('jaldi') ? 'high' : 'medium',
      'preferred_time': 'morning',
      'preferred_date': 'today',
      'budget_sensitivity': 0.5,
      'confidence': 0.8,
      'language': 'mixed',
      'reasoning_steps': 'Matched keywords in input.',
      'clarification_needed': false,
      'clarification_question': '',
      'job_complexity': 'basic',
    };
  }

  static Map<String, dynamic> _mockNegotiation(double original, double offer, bool repeat, double surge, String providerName) {
    final accepted = offer >= original * 0.9;
    return {
      'counter_offer_pkr': accepted ? offer : original * 0.95,
      'accepted': accepted,
      'reasoning': 'Asking $providerName for the best possible rate.',
      'discount_applied_pkr': (original - (accepted ? offer : original * 0.95)).clamp(0.0, double.maxFinite),
      'discount_reason': 'negotiated',
      'is_final_offer': true,
    };
  }

  static Map<String, dynamic> _mockDisputeAnalysis(String type, double quoted, double charged, int dna) {
    return {
      'verdict': 'mediated',
      'action': 'partial_refund',
      'refund_amount_pkr': (charged - quoted) * 0.5,
      'penalty_to_provider': 'warning',
      'reasoning': 'Automatic mediation applied.',
      'escalate_to_human': false,
    };
  }
}
