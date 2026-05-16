import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/runtime_config.dart';

/// Bridges Flutter app to the Gemini 1.5 Flash API for all AI agent operations.
class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static final String _apiKey = RuntimeConfig.geminiApiKey.trim();
  static bool get _hasApiKey => _apiKey.isNotEmpty;
  static const int _maxRetries = 3;
  static const int _maxBackoffSeconds = 4;

  // ─── Intent Agent ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> extractIntent(String rawInput) async {
    if (!_hasApiKey) {
      return _mockIntentParse(rawInput);
    }

    final prompt = '''
You are the Intent Agent for KaamYaab, Pakistan's AI-powered service marketplace.

Analyze this user request (may be Urdu, Roman Urdu, English, or mixed language):
"$rawInput"

Return ONLY a JSON object with these exact fields (no markdown, no explanation):
{
  "service_type": "one of: Plumbing | AC Repair | Electrical | Cleaning | Carpentry | Painting | Tutoring | Gardening | Security Guard | Driver | Cook | Unknown",
  "location": "the full location/city string from the input",
  "area": "sector or neighborhood extracted (e.g. G-13, DHA Phase 5, Sadar, Blue Area). If unknown, use city name.",
  "urgency": "low | medium | high | emergency",
  "preferred_time": "morning | afternoon | evening | flexible",
  "preferred_date": "today | tomorrow | flexible",
  "budget_sensitivity": 0.0 to 1.0 (0.0=very flexible, 1.0=very tight budget),
  "confidence": 0.0 to 1.0,
  "language": "urdu | roman_urdu | english | mixed",
  "clarification_needed": true or false,
  "clarification_question": "question in same language if confidence < 0.75, else empty string",
  "job_complexity": "basic | intermediate | complex"
}

Rules:
- "plumber", "plumbr", "pipe leak", "pani", "nala" → service_type = Plumbing
- "electrician", "bijli", "wiring", "switch" → service_type = Electrical
- "AC", "air condition", "cooling", "thanda" → service_type = AC Repair
- "carpenter", "wood", "darwaza", "furniture" → service_type = Carpentry
- "safai", "clean", "jharoo" → service_type = Cleaning
- Budget words like "budget", "sasta", "1500", "2000" → higher budget_sensitivity
- "aaj", "today", "abhi", "urgent", "jaldi" → urgency = high
- Always extract the actual area/city from the text — do NOT default to G-13
''';

    try {
      final response = await _postWithRetry({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512}
      });

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
    if (!_hasApiKey) {
      return _mockNegotiation(originalQuote, userOffer, isRepeatCustomer, surgeMultiplier, providerName);
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
  "reasoning": "short explanation framing it as asking the provider to accommodate for the best price (e.g. 'I asked [Provider] to accommodate and they agreed to...')",
  "discount_applied_pkr": number,
  "discount_reason": "loyalty | surge_offset | off_peak | none",
  "is_final_offer": true or false
}
''';

    try {
      final response = await _postWithRetry({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 256}
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (_) {}

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
      final response = await _postWithRetry({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512}
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (_) {}

    return _mockDisputeAnalysis(disputeType, quotedPrice, chargedPrice, providerDnaScore);
  }

<<<<<<< HEAD
  // ── Worker Settings Agent ──────────────────────────────────────────────────
  static Future<List<String>> processWorkerSettings(String input, List<String> currentRules) async {
    if (!_hasApiKey) {
      // Mock logic for demo without API key
      final updated = List<String>.from(currentRules);
      updated.add(input);
      return updated;
    }

    final prompt = '''
You are the KaamYaab Worker Agent. A worker has told you their new availability setting.
Input: "$input"
Current Rules: ${currentRules.join(', ')}

Please extract the new availability rules, and update the current rules list.
Return the updated list as a JSON array of strings representing the distinct rules in simple, concise English. For example: ["Sundays off", "Available 10 AM to 5 PM"].
Only return the JSON array.
''';

    try {
      final response = await _postWithRetry({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 256}
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> parsed = jsonDecode(cleaned);
        return parsed.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    // Fallback: just add it
    final updated = List<String>.from(currentRules);
    updated.add(input);
    return updated;
  }

  // ── Mock Fallbacks (for demo without API key) ───────────────────────────
=======
  // ─── Mock Fallbacks (for demo without API key) ───────────────────────────────
>>>>>>> b4f0fa9c3e57262e70d950cf3742e48be789eb33
  static Map<String, dynamic> _mockIntentParse(String rawInput) {
    final lower = rawInput.toLowerCase();

    // ── Service Detection ───────────────────────────────────────────────────
    String service = 'Unknown';
    if (lower.contains('plumber') || lower.contains('plumbr') || lower.contains('plumb') ||
        lower.contains('pipe') || lower.contains('naala') || lower.contains('nala') ||
        lower.contains('water') || lower.contains('pani') || lower.contains('پانی') ||
        lower.contains('leak') || lower.contains('tap')) {
      service = 'Plumbing';
    } else if (lower.contains(' ac ') || lower.contains('ac repair') || lower.contains('air con') ||
        lower.contains('cooling') || lower.contains('thanda') || lower.contains('ٹھنڈا') ||
        lower.contains('hvac') || lower.contains('gas fill')) {
      service = 'AC Repair';
    } else if (lower.contains('electric') || lower.contains('electrician') ||
        lower.contains('bijli') || lower.contains('بجلی') || lower.contains('wiring') ||
        lower.contains('switch') || lower.contains('socket') || lower.contains('fan') ||
        lower.contains('light') || lower.contains('mcb')) {
      service = 'Electrical';
    } else if (lower.contains('carpenter') || lower.contains('wood') ||
        lower.contains('darwaza') || lower.contains('furniture') || lower.contains('almaari') ||
        lower.contains('khidki') || lower.contains('door')) {
      service = 'Carpentry';
    } else if (lower.contains('clean') || lower.contains('safai') || lower.contains('صفائی') ||
        lower.contains('jharoo') || lower.contains('sweep') || lower.contains('mop')) {
      service = 'Cleaning';
    } else if (lower.contains('paint') || lower.contains('rang') || lower.contains('colour') ||
        lower.contains('color') || lower.contains('wall')) {
      service = 'Painting';
    } else if (lower.contains('tutor') || lower.contains('teacher') || lower.contains('parhai') ||
        lower.contains('parhana') || lower.contains('math') || lower.contains('english class')) {
      service = 'Tutoring';
    } else if (lower.contains('garden') || lower.contains('plant') || lower.contains('lawn') ||
        lower.contains('grass') || lower.contains('tree')) {
      service = 'Gardening';
    } else if (lower.contains('cook') || lower.contains('khana') || lower.contains('bawarchi')) {
      service = 'Cook';
    } else if (lower.contains('driver') || lower.contains('gari chalao') || lower.contains('cab')) {
      service = 'Driver';
    }

    // ── Urgency Detection ────────────────────────────────────────────────────
    String urgency = 'medium';
    if (lower.contains('urgent') || lower.contains('emergency') || lower.contains('jaldi') ||
        lower.contains('abhi') || lower.contains('ابھی') || lower.contains('aaj') ||
        lower.contains('today') || lower.contains('asap') || lower.contains('turant')) {
      urgency = 'high';
    } else if (lower.contains('kal ') || lower.contains('tomorrow') || lower.contains('next week')) {
      urgency = 'low';
    }

    // ── Budget Detection ─────────────────────────────────────────────────────
    double budget = 0.5;
    if (lower.contains('budget') || lower.contains('sasta') || lower.contains('kam paise') ||
        lower.contains('zyada nahi') || lower.contains('cheap') || lower.contains('low cost') ||
        RegExp(r'\b\d{3,4}\s*(rs|rupee|rupay|pkr)?\b').hasMatch(lower)) {
      budget = 0.75;
    }

    // ── Area / Location Detection ─────────────────────────────────────────────
    // Islamabad sectors
    final isectorRegex = RegExp(r'\b([fge]-?\d{1,2})\b', caseSensitive: false);
    final sectorMatch = isectorRegex.firstMatch(rawInput);
    String area = 'G-13'; // default only if nothing found
    String location = 'Islamabad';

    if (sectorMatch != null) {
      area = sectorMatch.group(0)!.toUpperCase().replaceAll(' ', '-');
      location = 'Islamabad';
    } else if (lower.contains('dha') || lower.contains('defence')) {
      area = 'DHA'; location = _extractCity(lower) ?? 'Lahore';
    } else if (lower.contains('gulshan') || lower.contains('nazimabad') || lower.contains('clifton') ||
        lower.contains('karachi') || lower.contains('saddar') || lower.contains('sadar') ||
        lower.contains('korangi') || lower.contains('malir') || lower.contains('north nazimabad')) {
      area = _extractKarachiArea(lower);
      location = 'Karachi';
    } else if (lower.contains('lahore') || lower.contains('johar town') || lower.contains('gulberg') ||
        lower.contains('model town') || lower.contains('garden town') || lower.contains('bahria') ||
        lower.contains('township') || lower.contains('iqbal town')) {
      area = _extractLahoreArea(lower);
      location = 'Lahore';
    } else if (lower.contains('rawalpindi') || lower.contains('pindi') ||
        lower.contains('sadiqabad') || lower.contains('chaklala') || lower.contains('satellite town')) {
      area = _extractRawalpindiArea(lower);
      location = 'Rawalpindi';
    } else if (lower.contains('peshawar') || lower.contains('hayatabad') || lower.contains('ring road')) {
      area = 'Hayatabad'; location = 'Peshawar';
    } else if (lower.contains('islamabad') || lower.contains('blue area') || lower.contains('f-6') ||
        lower.contains('margalla') || lower.contains('bari imam')) {
      area = _extractIslamabadNamedArea(lower);
      location = 'Islamabad';
    }

    // ── Complexity ───────────────────────────────────────────────────────────
    String complexity = 'basic';
    if (lower.contains('bilkul kaam nahi') || lower.contains('kharab') || lower.contains('broken') ||
        lower.contains('install') || lower.contains('replace') || lower.contains('badal')) {
      complexity = 'complex';
    } else if (lower.contains('service') || lower.contains('check') || lower.contains('dekho') ||
        lower.contains('fix') || lower.contains('theak')) {
      complexity = 'intermediate';
    }

    // ── Time ────────────────────────────────────────────────────────────────
    String time = 'flexible';
    if (lower.contains('subah') || lower.contains('morning') || lower.contains('صبح')) time = 'morning';
    else if (lower.contains('dopahar') || lower.contains('afternoon') || lower.contains('2 baj') || lower.contains('3 baj')) time = 'afternoon';
    else if (lower.contains('sham') || lower.contains('evening') || lower.contains('شام')) time = 'evening';

    final confidence = service == 'Unknown' ? 0.55 : (area != 'G-13' || sectorMatch != null ? 0.92 : 0.85);
    final needsClarification = confidence < 0.75;

    return {
      'service_type': service,
      'location': location,
      'area': area,
      'urgency': urgency,
      'preferred_time': time,
      'preferred_date': (lower.contains('kal') || lower.contains('tomorrow')) ? 'tomorrow'
          : (lower.contains('aaj') || lower.contains('today') || lower.contains('abhi')) ? 'today'
          : 'flexible',
      'budget_sensitivity': budget,
      'confidence': confidence,
      'language': _detectLanguage(rawInput),
      'clarification_needed': needsClarification,
      'clarification_question': needsClarification
          ? 'Ap kis service ki zaroorat hai? (Plumbing, AC, Electrical, Carpentry, Cleaning)'
          : '',
      'job_complexity': complexity,
    };
  }

  static String _extractKarachiArea(String lower) {
    if (lower.contains('clifton')) return 'Clifton';
    if (lower.contains('gulshan')) return 'Gulshan-e-Iqbal';
    if (lower.contains('nazimabad')) return 'Nazimabad';
    if (lower.contains('saddar') || lower.contains('sadar')) return 'Saddar';
    if (lower.contains('korangi')) return 'Korangi';
    if (lower.contains('malir')) return 'Malir';
    if (lower.contains('north nazimabad')) return 'North Nazimabad';
    return 'Karachi';
  }

  static String _extractLahoreArea(String lower) {
    if (lower.contains('dha')) return 'DHA Lahore';
    if (lower.contains('gulberg')) return 'Gulberg';
    if (lower.contains('model town')) return 'Model Town';
    if (lower.contains('johar')) return 'Johar Town';
    if (lower.contains('bahria')) return 'Bahria Town';
    if (lower.contains('iqbal town')) return 'Iqbal Town';
    if (lower.contains('garden town')) return 'Garden Town';
    if (lower.contains('township')) return 'Township';
    return 'Lahore';
  }

  static String _extractRawalpindiArea(String lower) {
    if (lower.contains('satellite')) return 'Satellite Town';
    if (lower.contains('chaklala')) return 'Chaklala';
    if (lower.contains('sadiqabad')) return 'Sadiqabad';
    if (lower.contains('bahria')) return 'Bahria Town Rwp';
    return 'Rawalpindi';
  }

  static String _extractIslamabadNamedArea(String lower) {
    if (lower.contains('blue area')) return 'Blue Area';
    if (lower.contains('f-6') || lower.contains('f 6')) return 'F-6';
    if (lower.contains('margalla')) return 'Margalla Hills';
    if (lower.contains('bari imam')) return 'Bari Imam';
    if (lower.contains('i-8') || lower.contains('i 8')) return 'I-8';
    if (lower.contains('i-10') || lower.contains('i 10')) return 'I-10';
    return 'Islamabad';
  }

  static String? _extractCity(String lower) {
    if (lower.contains('lahore')) return 'Lahore';
    if (lower.contains('karachi')) return 'Karachi';
    if (lower.contains('islamabad')) return 'Islamabad';
    if (lower.contains('rawalpindi') || lower.contains('pindi')) return 'Rawalpindi';
    if (lower.contains('peshawar')) return 'Peshawar';
    if (lower.contains('multan')) return 'Multan';
    if (lower.contains('faisalabad')) return 'Faisalabad';
    return null;
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
    double original, double offer, bool repeat, double surge, String providerName) {
    final minAccept = original * 0.85;
    final loyaltyDiscount = repeat ? original * 0.07 : 0.0;
    
    // For demo purposes, add some flexibility to the mock negotiation
    final flexibility = surge > 1.3 ? 0.0 : 0.05; // 5% base flexibility if no surge
    final counter = (original - loyaltyDiscount - (original * flexibility)).clamp(minAccept, original);
    
    // Accept if offer is close enough (within 2%)
    final accepted = offer >= counter * 0.98;
    
    return {
      'counter_offer_pkr': accepted ? offer.roundToDouble() : counter.roundToDouble(),
      'accepted': accepted,
      'reasoning': accepted
          ? 'I asked $providerName to accommodate for the best price, and they agreed to lower it to Rs. ${offer.round()}.'
          : 'I asked $providerName to accommodate for the best price, but considering current demand${surge > 1.3 ? " (surge active)" : ""}, they can only offer Rs. ${counter.toStringAsFixed(0)}.',
      'discount_applied_pkr': accepted ? (original - offer) : (original - counter),
      'discount_reason': repeat ? 'loyalty' : 'negotiated',
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

  static Future<http.Response> _postWithRetry(Map<String, dynamic> payload) async {
    http.Response? lastResponse;
    for (var retry = 0; retry <= _maxRetries; retry++) {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      lastResponse = response;
      if (response.statusCode < 400) {
        return response;
      }

      final isRateLimited = response.statusCode == 429;
      final isRetryableServerError = response.statusCode >= 500;
      if (retry == _maxRetries || (!isRateLimited && !isRetryableServerError)) {
        return response;
      }

      final delaySeconds = min(_maxBackoffSeconds, pow(2, retry).toInt());
      await Future.delayed(Duration(seconds: max(1, delaySeconds)));
    }
    return lastResponse ??
        http.Response('{"error":"request_failed"}', 500);
  }
}
