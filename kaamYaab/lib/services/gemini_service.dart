import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Bridges Flutter app to the Gemini 1.5 Flash API for all AI agent operations.
class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static String get _apiKey => EnvConfig.geminiApiKey;
  static bool get _hasApiKey => _apiKey.trim().isNotEmpty;

  // â”€â”€â”€ Intent Agent â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>> extractIntent(String rawInput) async {
    if (!_hasApiKey) {
      return _mockIntentParse(rawInput);
    }

    final prompt = '''
You are the Intent Agent for KaamYaab, an AI service orchestrator for Pakistan's informal economy.

Extract structured information from this user input (may be Urdu, Roman Urdu, English, or mixed):
"$rawInput"

Return a JSON object with these exact fields:
{
  "service_type": "AC Repair | Plumbing | Electrical | Tutoring | Cleaning | Unknown",
  "location": "extracted location string",
  "area": "area code like G-13, F-10 etc",
  "urgency": "low | medium | high | emergency",
  "preferred_time": "morning | afternoon | evening | flexible | specific time",
  "preferred_date": "today | tomorrow | day after | specific date | flexible",
  "budget_sensitivity": 0.0 to 1.0 (0=flexible, 1=very tight),
  "confidence": 0.0 to 1.0,
  "language": "urdu | roman_urdu | english | mixed",
  "clarification_needed": true or false,
  "clarification_question": "question to ask user if confidence < 0.7",
  "job_complexity": "basic | intermediate | complex"
}

Only return the JSON. No explanation.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (e) {
      // Fallback: return mock parsed intent for demo
    }

    return _mockIntentParse(rawInput);
  }

  // â”€â”€â”€ Negotiation Agent â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>> negotiatePrice({
    required double originalQuote,
    required double userOffer,
    required String serviceType,
    required int providerDnaScore,
    required double surgeMultiplier,
    required bool isRepeatCustomer,
    required String providerName,
  }) async {
    if (!_hasApiKey) {
      return _mockNegotiation(originalQuote, userOffer, isRepeatCustomer, surgeMultiplier);
    }

    final prompt = '''
You are the Negotiation Agent for KaamYaab.

A user is negotiating price for a $serviceType booking.
- Original quote: Rs. ${originalQuote.toStringAsFixed(0)}
- User's offer: Rs. ${userOffer.toStringAsFixed(0)}
- Provider DNA Score: $providerDnaScore/1000 (higher = more trusted)
- Current surge multiplier: ${surgeMultiplier}x
- Repeat customer: $isRepeatCustomer
- Provider: $providerName

Decide the fair counter-offer considering:
1. If surge > 1.3x, provider has leverage
2. If user is repeat, give 5-10% loyalty discount
3. DNA score > 800 means provider can hold price
4. Never go below provider's cost (85% of original quote)

Return JSON:
{
  "counter_offer_pkr": number,
  "accepted": true or false,
  "reasoning": "short explanation in 1-2 sentences",
  "discount_applied_pkr": number,
  "discount_reason": "loyalty | surge_offset | off_peak | none",
  "is_final_offer": true or false
}
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 256}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (_) {}

    return _mockNegotiation(originalQuote, userOffer, isRepeatCustomer, surgeMultiplier);
  }

  // â”€â”€â”€ Dispute Analysis Agent â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>> analyzeDispute({
    required String disputeType,
    required String description,
    required double quotedPrice,
    required double chargedPrice,
    required int providerDnaScore,
    required int providerDisputeCount,
  }) async {
    if (!_hasApiKey) {
      return _mockDisputeAnalysis(disputeType, quotedPrice, chargedPrice, providerDnaScore);
    }

    final prompt = '''
You are the Dispute Agent for KaamYaab.

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

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (_) {}

    return _mockDisputeAnalysis(disputeType, quotedPrice, chargedPrice, providerDnaScore);
  }

  // â”€â”€â”€ Mock Fallbacks (for demo without API key) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Map<String, dynamic> _mockIntentParse(String rawInput) {
    final lower = rawInput.toLowerCase();
    String service = 'Unknown';
    if (lower.contains('ac') || lower.contains('cooling') || lower.contains('Ù¹Ú¾Ù†ÚˆØ§')) service = 'AC Repair';
    else if (lower.contains('pipe') || lower.contains('leak') || lower.contains('plumb') || lower.contains('Ù¾Ø§Ù†ÛŒ')) service = 'Plumbing';
    else if (lower.contains('electric') || lower.contains('bijli') || lower.contains('Ø¨Ø¬Ù„ÛŒ')) service = 'Electrical';
    else if (lower.contains('tutor') || lower.contains('teacher') || lower.contains('parhai')) service = 'Tutoring';
    else if (lower.contains('clean') || lower.contains('safai') || lower.contains('ØµÙØ§Ø¦ÛŒ')) service = 'Cleaning';

    String urgency = 'medium';
    if (lower.contains('urgent') || lower.contains('emergency') || lower.contains('jaldi') || lower.contains('Ø§Ø¨Ú¾ÛŒ')) urgency = 'high';
    else if (lower.contains('kal') || lower.contains('tomorrow')) urgency = 'medium';

    double budget = 0.5;
    if (lower.contains('budget') || lower.contains('sasta') || lower.contains('kam paise') || lower.contains('zyada nahi')) budget = 0.8;

    String area = 'G-13';
    if (lower.contains('g-11') || lower.contains('g 11')) area = 'G-11';
    else if (lower.contains('f-10') || lower.contains('f 10')) area = 'F-10';
    else if (lower.contains('g-14') || lower.contains('g 14')) area = 'G-14';

    String complexity = 'basic';
    if (lower.contains('bilkul kaam nahi') || lower.contains('kharab') || lower.contains('broken') || lower.contains('install')) complexity = 'complex';
    else if (lower.contains('service') || lower.contains('check')) complexity = 'intermediate';

    return {
      'service_type': service,
      'location': 'Pakistan',
      'area': area,
      'urgency': urgency,
      'preferred_time': lower.contains('subah') || lower.contains('morning') ? 'morning' : 'flexible',
      'preferred_date': lower.contains('kal') || lower.contains('tomorrow') ? 'tomorrow' : 'flexible',
      'budget_sensitivity': budget,
      'confidence': service == 'Unknown' ? 0.55 : 0.87,
      'language': _detectLanguage(rawInput),
      'clarification_needed': service == 'Unknown',
      'clarification_question': service == 'Unknown' ? 'Ap kis service ki zaroorat hai? (AC, Plumbing, Electrical, Tutoring, Cleaning)' : '',
      'job_complexity': complexity,
    };
  }

  static String _detectLanguage(String text) {
    final hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    final hasRoman = RegExp(r'[a-zA-Z]').hasMatch(text);
    if (hasUrdu && hasRoman) return 'mixed';
    if (hasUrdu) return 'urdu';
    if (text.contains('karo') || text.contains('chahiye') || text.contains('hai') || text.contains('kal')) return 'roman_urdu';
    return 'english';
  }

  static Map<String, dynamic> _mockNegotiation(
    double original, double offer, bool repeat, double surge) {
    final minAccept = original * 0.85;
    final loyaltyDiscount = repeat ? original * 0.07 : 0.0;
    final counter = (original - loyaltyDiscount).clamp(minAccept, original);
    final accepted = offer >= counter;
    return {
      'counter_offer_pkr': counter.roundToDouble(),
      'accepted': accepted,
      'reasoning': accepted
          ? 'Offer accepted. ${repeat ? "Loyalty discount applied for repeat customer." : ""}'
          : 'Provider can offer Rs. ${counter.toStringAsFixed(0)} considering current demand${surge > 1.3 ? " (surge active)" : ""}.',
      'discount_applied_pkr': loyaltyDiscount,
      'discount_reason': repeat ? 'loyalty' : 'none',
      'is_final_offer': true,
    };
  }

  static Map<String, dynamic> _mockDisputeAnalysis(
    String type, double quoted, double charged, int dna) {
    final overcharge = charged - quoted;
    if (overcharge > 200 && dna < 700) {
      return {
        'verdict': 'user_favor',
        'action': 'partial_refund',
        'refund_amount_pkr': overcharge * 0.8,
        'penalty_to_provider': 'dna_penalty',
        'reasoning': 'Provider charged Rs. ${overcharge.toStringAsFixed(0)} above quoted price without justification. Partial refund issued and DNA score penalized.',
        'escalate_to_human': false,
      };
    }
    return {
      'verdict': 'mediated',
      'action': 'partial_refund',
      'refund_amount_pkr': overcharge * 0.5,
      'penalty_to_provider': 'warning',
      'reasoning': 'Case reviewed. A partial refund of Rs. ${(overcharge * 0.5).toStringAsFixed(0)} is issued as a goodwill gesture. Provider has received a formal warning.',
      'escalate_to_human': false,
    };
  }
}
