import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../utils/distance_utils.dart';
import '../config/runtime_config.dart';
import 'ai_service.dart';
import 'auth_service.dart';

/// Core matching engine - computes README-aligned 10-factor provider ranking.
class MatchingService {
  static const double _maxReviewCountForScore = 200.0;
  static const double _maxModeledBaseRatePkr = 2000.0;
  static const double _maxDemandSurgeRate = 0.35; // README cap: 35%
  static const double _priceFitBalanceBase = 0.6;
  static const double _priceFitCenterRate = 0.5;
  static const double _priceFitBalanceScale = 62.5;

  // Only the static mock-JSON providers are cached. Live workers are always
  // re-merged on each call so new registrations and logouts are reflected.
  static List<ServiceProvider>? _mockProviders;

  // ── Double-Booking Prevention ─────────────────────────────────────────────
  // Tracks booked provider+slot combos to prevent race conditions.
  // Format: "providerId::slot" e.g. "PRV-0041::10:00"
  static final Set<String> _bookedSlots = {};

  /// Book a slot for a provider — prevents double-booking.
  static void bookSlot(String providerId, String slot) {
    _bookedSlots.add('$providerId::$slot');
  }

  /// Check if a provider's slot is already booked.
  static bool isSlotBooked(String providerId, String slot) {
    return _bookedSlots.contains('$providerId::$slot');
  }

  /// Clear all booked slots (on logout or reset).
  static void clearBookedSlots() => _bookedSlots.clear();

  /// Load providers: static JSON is cached; live workers are always re-merged fresh.
  static Future<List<ServiceProvider>> loadProviders() async {
    // Load (and cache) the static mock JSON only once.
    if (_mockProviders == null) {
      try {
        final raw = await rootBundle.loadString('assets/data/providers_mock.json');
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final list = (decoded['providers'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _mockProviders = list.map(ServiceProvider.fromJson).toList();
      } catch (_) {
        _mockProviders = [];
      }
    }

    // Always re-merge live workers so new registrations & logouts are reflected.
    final allProviders = List<ServiceProvider>.from(_mockProviders!);
    try {
      final liveWorkers = await AuthService().getAllWorkers();
      for (var worker in liveWorkers) {
        // Only include workers who have set their location
        if (worker.latitude != null && worker.longitude != null) {
          final expLevel = _deriveExperienceLevel(worker.experienceYears);
          final isNewWorker = worker.totalJobs < 5;
          final effectiveRating = worker.rating > 0 ? worker.rating : (isNewWorker ? 3.5 : 4.0);
          final computedDna = _computeNewWorkerDna(
            rating: effectiveRating,
            totalJobs: worker.totalJobs,
            experienceYears: worker.experienceYears,
          );
          final parsedSlots = _parseSlotsFromRules(worker.availabilityRules);

          allProviders.add(ServiceProvider(
            id: worker.uid,
            name: worker.name,
            phone: worker.phone,
            serviceCategory: worker.serviceCategory ?? 'General',
            skills: worker.skills ?? [],
            lat: worker.latitude!,
            lng: worker.longitude!,
            area: worker.area,
            city: worker.city,
            dnascore: computedDna,
            rating: effectiveRating,
            totalJobs: worker.totalJobs,
            completedJobs: worker.totalJobs,
            onTimeRate: isNewWorker ? 0.85 : 0.90,
            cancellationRate: isNewWorker ? 0.05 : 0.03,
            priceFairnessScore: isNewWorker ? 0.80 : 0.85,
            disputeCount: 0,
            surgeAcceptor: true,
            baseRatePkr: worker.baseRatePkr ?? 600.0,
            experienceLevel: expLevel,
            certifications: [],
            availability: worker.availabilityRules ?? [],
            availableSlots: parsedSlots,
            reviewCount: worker.totalJobs,
            profileImage: worker.profileImageBase64 ?? '',
            isVerified: true,
            lastActiveDate: DateTime.now().toIso8601String(),
          ));
        }
      }
    } catch (_) {
      // Live worker merge failed — continue with mock providers only.
    }
    return allProviders;
  }

  /// Invalidate the mock JSON cache (called on logout / major state changes).
  static void clearCache() {
    _mockProviders = null;
    _bookedSlots.clear();
  }

  /// Main matching: filter -> score -> rank -> return top matches with rationale.
  static Future<List<ProviderMatch>> matchProviders({
    required ServiceRequest request,
    required double userLat,
    required double userLng,
    double surgeMult = 1.0,
    bool isUrdu = false,
    bool isRepeatCustomer = false,
  }) async {
    final providers = await loadProviders();

    // Step 1: Filter by service category, health checks, and booked-slot conflicts.
    final requestedSlots = _inferRequestedSlots(request);
    final filtered = providers.where((p) {
      if (!_serviceMatches(p.serviceCategory, request.serviceType)) return false;
      if (p.disputeCount >= 3) return false;
      if (p.cancellationRate > 0.15) return false;
      // Double-booking prevention: skip providers whose relevant slots are all taken
      if (requestedSlots.isNotEmpty) {
        final allBooked = requestedSlots.every((slot) => isSlotBooked(p.id, slot));
        if (allBooked) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // ─── Agentic Path: If API key exists, let AI rank them ──────────────
    if (RuntimeConfig.cohereApiKey.isNotEmpty) {
      final providerMaps = filtered.map((p) {
        final dist = haversineDistanceKm((lat: userLat, lng: userLng), (lat: p.lat, lng: p.lng));
        return {
          'id': p.id,
          'name': p.name,
          'rating': p.rating,
          'total_jobs': p.totalJobs,
          'price': p.baseRatePkr,
          'skills': p.skills,
          'on_time': p.onTimeRate,
          'area': p.area,
          'distance_km': dist.toStringAsFixed(2),
        };
      }).toList();

      final intentMap = {
        'service': request.serviceType,
        'area': request.area,
        'urgency': request.urgency,
        'budget': request.budgetSensitivity,
      };

      final agentResult = await AiService.rankProviders(
        intent: intentMap,
        providers: providerMaps,
        surgeMultiplier: surgeMult,
      );

      final rankedIds = (agentResult['ranked_ids'] as List?)?.cast<String>() ?? [];
      final topReasoning = isUrdu 
          ? (agentResult['top_choice_reasoning_urdu'] as String? ?? agentResult['top_choice_reasoning'] as String? ?? 'بہترین انتخاب۔')
          : (agentResult['top_choice_reasoning'] as String? ?? 'Best overall match.');

      if (rankedIds.isNotEmpty) {
        final matches = <ProviderMatch>[];
        for (var id in rankedIds) {
          final pIdx = filtered.indexWhere((provider) => provider.id == id);
          if (pIdx < 0) continue;
          final p = filtered[pIdx];
          final dist = haversineDistanceKm((lat: userLat, lng: userLng), (lat: p.lat, lng: p.lng));
          final match = _computeMatch(p, request, dist, surgeMult,
              isUrdu: isUrdu, isRepeatCustomer: isRepeatCustomer);
          
          // Inject the agent's reasoning for the top one
          if (matches.isEmpty) {
            matches.add(match.copyWith(rankRationale: topReasoning));
          } else {
            matches.add(match);
          }
        }
        if (matches.isNotEmpty) return matches;
      }
    }

    // fallback to old scoring logic
    final scored = <ProviderMatch>[];
    for (final p in filtered) {
      final dist = haversineDistanceKm(
        (lat: userLat, lng: userLng),
        (lat: p.lat, lng: p.lng),
      );
      final match = _computeMatch(p, request, dist, surgeMult,
          isUrdu: isUrdu, isRepeatCustomer: isRepeatCustomer);
      scored.add(match);
    }

    // Step 3: Sort by score and README tie-breakers.
    scored.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;

      final distCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distCompare != 0) return distCompare;

      final onTimeCompare = b.provider.onTimeRate.compareTo(a.provider.onTimeRate);
      if (onTimeCompare != 0) return onTimeCompare;

      return b.provider.rating.compareTo(a.provider.rating);
    });

    return scored.take(5).toList();
  }

  static ProviderMatch _computeMatch(
    ServiceProvider p,
    ServiceRequest req,
    double distKm,
    double surge, {
    bool isUrdu = false,
    bool isRepeatCustomer = false,
  }) {
    final distanceScore = _distanceScore(distKm);
    final availabilityScore = _availabilityScore(p, req.preferredTime);
    final ratingScore = (p.rating / 5.0) * 100.0;
    final reviewRecencyScore =
        (p.reviewCount / _maxReviewCountForScore).clamp(0.0, 1.0) * 100.0;
    final reliabilityScore = p.onTimeRate * 100.0;
    final specializationScore = _specializationScore(p, req);
    final priceFitScore = _priceFitScore(p, req.budgetSensitivity);
    final cancellationRiskScore = _cancellationRiskScore(p);
    final capacityScore = _capacityScore(p);
    final userPreferenceScore = _userPreferenceScore(p, req);

    final score = (
      distanceScore * 0.15 + // Increased weight for distance
      availabilityScore * 0.15 +
      ratingScore * 0.12 +
      reviewRecencyScore * 0.05 +
      reliabilityScore * 0.15 + // Increased weight for reliability
      specializationScore * 0.15 +
      priceFitScore * 0.08 +
      cancellationRiskScore * 0.08 +
      capacityScore * 0.03 +
      userPreferenceScore * 0.04
    ).clamp(0.0, 100.0);

    final breakdown = {
      'distance_score': distanceScore,
      'availability_score': availabilityScore,
      'rating_score': ratingScore,
      'review_recency_score': reviewRecencyScore,
      'reliability_score': reliabilityScore,
      'specialization_score': specializationScore,
      'price_fit_score': priceFitScore,
      'cancellation_risk': cancellationRiskScore,
      'capacity_score': capacityScore,
      'user_preference_match': userPreferenceScore,
    };

    final quote = _calculateQuote(p, req, distKm, surge, isRepeatCustomer: isRepeatCustomer);
    final slot = p.availableSlots.isNotEmpty ? p.availableSlots.first : '10:00';
    final eta = (estimateTravelTimeHours(distKm) * 60).round();
    final rationale = _buildRationale(p, score, distKm, surge, isUrdu: isUrdu);

    return ProviderMatch(
      provider: p,
      distanceKm: distKm,
      etaMinutes: eta,
      matchScore: score,
      quotePkr: quote,
      recommendedSlot: slot,
      rankRationale: rationale,
      scoreBreakdown: breakdown,
    );
  }

  static double _calculateQuote(
    ServiceProvider p,
    ServiceRequest req,
    double dist,
    double surge, {
    bool isRepeatCustomer = false,
  }) {
    final base = p.baseRatePkr;
    // BUG-5 FIX: free zone — no distance charge for first 3 km
    final distanceCharge = dist > 3 ? (dist - 3) * 20 : 0.0;
    final complexitySurcharge = _complexityRate(req.jobComplexity) * base;
    final urgencyPremium = _urgencyPremiumRate(req) * base;
    final demandSurgeRate = (surge - 1.0).clamp(0.0, _maxDemandSurgeRate);
    final demandSurge =
        (base + distanceCharge + complexitySurcharge + urgencyPremium) *
            demandSurgeRate;
    // BUG-5 FIX: loyalty discount only applies to repeat customers
    final loyaltyDiscount = isRepeatCustomer ? base * 0.05 : 0.0;
    final budgetAdjustment = req.budgetSensitivity >= 0.75 ? base * 0.08 : 0.0;

    return (base +
            distanceCharge +
            complexitySurcharge +
            urgencyPremium +
            demandSurge -
            loyaltyDiscount -
            budgetAdjustment)
        .roundToDouble();
  }

  static String _buildRationale(ServiceProvider p, double score, double dist, double surge, {bool isUrdu = false}) {
    final parts = <String>[];
    if (isUrdu) {
      if (dist < 3) parts.add('قریب ترین (${dist.toStringAsFixed(1)} کلومیٹر)');
      if (p.onTimeRate >= 0.95) parts.add('${(p.onTimeRate * 100).toInt()}% وقت کی پابندی');
      if (p.rating >= 4.7) parts.add('اعلیٰ ریٹنگ');
      if (p.disputeCount == 0) parts.add('بہترین ریکارڈ');
      if (p.isVerified) parts.add('تصدیق شدہ');
      return parts.isEmpty ? 'بہترین میچ۔' : parts.take(3).join(' · ');
    } else {
      if (dist < 3) parts.add('Nearby (${dist.toStringAsFixed(1)}km)');
      if (p.onTimeRate >= 0.95) parts.add('${(p.onTimeRate * 100).toInt()}% on-time');
      if (p.rating >= 4.7) parts.add('top-rated');
      if (p.disputeCount == 0) parts.add('zero disputes');
      if (p.isVerified) parts.add('verified');
      return parts.isEmpty ? 'Good overall match.' : parts.take(3).join(' · ');
    }
  }

  static bool _serviceMatches(String providerCategory, String serviceType) {
    final provider = providerCategory.toLowerCase();
    final service = serviceType.toLowerCase();
    if (provider == service) return true;
    
    // Detailed mapping for better accuracy
    if (service.contains('ac') || service.contains('cooling') || service.contains('fridge') || service.contains('freezer')) {
      return provider.contains('ac') || provider.contains('technician') || provider.contains('cooling');
    }
    if (service.contains('plumb') || service.contains('pipe') || service.contains('water') || service.contains('tank') || service.contains('motor') || service.contains('nal')) {
      return provider.contains('plumb') || provider.contains('pipe');
    }
    if (service.contains('electric') || service.contains('wiring') || service.contains('light') || service.contains('fan') || service.contains('bijli') || service.contains('ups') || service.contains('solar')) {
      return provider.contains('electric') || provider.contains('solar');
    }
    if (service.contains('clean') || service.contains('safai') || service.contains('wash') || service.contains('dusting')) {
      return provider.contains('clean');
    }
    if (service.contains('carpent') || service.contains('wood') || service.contains('furniture') || service.contains('door') || service.contains('lakri')) {
      return provider.contains('carpent') || provider.contains('wood');
    }
    if (service.contains('paint') || service.contains('rang') || service.contains('polish') || service.contains('wall')) {
      return provider.contains('paint');
    }
    if (service.contains('tutor') || service.contains('teach') || service.contains('math') || service.contains('urdu') || service.contains('english') || service.contains('parhai')) {
      return provider.contains('tutor') || provider.contains('teach');
    }
    if (service.contains('garden') || service.contains('plant') || service.contains('grass') || service.contains('mali')) {
      return provider.contains('garden') || provider.contains('mali');
    }
    if (service.contains('cook') || service.contains('food') || service.contains('khana') || service.contains('bawarchi')) {
      return provider.contains('cook') || provider.contains('chef');
    }
    if (service.contains('driver') || service.contains('car') || service.contains('gari') || service.contains('chala')) {
      return provider.contains('driver');
    }
    if (service.contains('security') || service.contains('guard') || service.contains('chowkidar')) {
      return provider.contains('security') || provider.contains('guard');
    }
    
    return false;
  }

  static double _distanceScore(double distKm) {
    if (distKm <= 2) return 100;
    if (distKm <= 5) return 90;
    if (distKm >= 20) return 0;
    return (100 - ((distKm - 2) / 18.0) * 100).clamp(0.0, 100.0);
  }

  static double _availabilityScore(ServiceProvider p, String preferredTime) {
    if (preferredTime == 'flexible') return 95;
    
    if (p.availability.isNotEmpty) {
      final rulesStr = p.availability.join(' ').toLowerCase();
      if (RegExp(r'\boff\b').hasMatch(rulesStr) ||
          rulesStr.contains('not available') ||
          rulesStr.contains('unavailable') ||
          rulesStr.contains('busy')) {
        return 0;
      }
    }

    final hasSlot = p.availableSlots.any((slot) => slot.contains(preferredTime));
    return hasSlot ? 95 : 55;
  }

  static double _specializationScore(ServiceProvider p, ServiceRequest req) {
    var score = 55.0;
    if (_serviceMatches(p.serviceCategory, req.serviceType)) score += 25;
    if (p.skills.length >= 3) score += 10;
    if (_meetsComplexityRequirement(p, req.jobComplexity)) score += 10;
    return score.clamp(0.0, 100.0);
  }

  static bool _meetsComplexityRequirement(ServiceProvider p, String complexity) {
    final expRank = _experienceRank(p.experienceLevel);
    if (complexity == 'complex') {
      return expRank >= 2 || p.certifications.isNotEmpty;
    }
    if (complexity == 'intermediate') {
      return expRank >= 1;
    }
    return true;
  }

  static int _experienceRank(String experienceLevel) {
    switch (experienceLevel.toLowerCase()) {
      case 'expert':
      case 'advanced':
      case 'master':
        return 2;
      case 'intermediate':
        return 1;
      default:
        return 0;
    }
  }

  static double _priceFitScore(ServiceProvider p, double budgetSensitivity) {
    final normalizedRate =
        (p.baseRatePkr / _maxModeledBaseRatePkr).clamp(0.0, 1.0);
    if (budgetSensitivity >= 0.75) return ((1 - normalizedRate) * 100).clamp(0.0, 100.0);
    return ((_priceFitBalanceBase +
            (1 - (normalizedRate - _priceFitCenterRate).abs())) *
        _priceFitBalanceScale).clamp(0.0, 100.0);
  }

  static double _cancellationRiskScore(ServiceProvider p) {
    if (p.cancellationRate >= 0.15) return 0;
    return ((1 - p.cancellationRate) * 100).clamp(0.0, 100.0);
  }

  static double _capacityScore(ServiceProvider p) {
    if (p.totalJobs == 0) return 80.0;
    final completionRate = p.completionRate.clamp(0.0, 1.0);
    return (completionRate * 100).clamp(60.0, 100.0);
  }

  static double _userPreferenceScore(ServiceProvider p, ServiceRequest req) {
    var score = 50.0;
    if (req.budgetSensitivity < 0.3 && p.rating >= 4.6) score += 30;
    if (p.disputeCount == 0) score += 10;
    if (p.isVerified) score += 10;
    return score.clamp(0.0, 100.0);
  }

  static double _complexityRate(String complexity) {
    switch (complexity) {
      case 'complex':
        return 0.40;
      case 'intermediate':
        return 0.15;
      default:
        return 0.0;
    }
  }

  static double _urgencyPremiumRate(ServiceRequest req) {
    if (req.urgency == 'emergency') return 0.30;
    if (req.preferredDate == 'today') return 0.20;
    if (req.preferredDate == 'tomorrow' && req.preferredTime == 'morning') {
      return 0.05;
    }
    return 0.0;
  }

  /// Infer which time slots a request is targeting, for double-booking filtering.
  static List<String> _inferRequestedSlots(ServiceRequest request) {
    final time = request.preferredTime.toLowerCase();
    if (time.contains('morning') || time.contains('subah')) {
      return ['08:00', '09:00', '10:00', '11:00'];
    }
    if (time.contains('afternoon') || time.contains('dopahar')) {
      return ['12:00', '13:00', '14:00', '15:00'];
    }
    if (time.contains('evening') || time.contains('shaam')) {
      return ['16:00', '17:00', '18:00'];
    }
    // Try to extract a specific time like "10:00"
    final match = RegExp(r'(\d{1,2}):?(\d{2})?').firstMatch(time);
    if (match != null) {
      final h = int.tryParse(match.group(1) ?? '') ?? 0;
      if (h >= 6 && h <= 21) {
        return ['${h.toString().padLeft(2, '0')}:${match.group(2) ?? '00'}'];
      }
    }
    // "flexible" or unknown → don't filter by slot
    return [];
  }

  /// Derive experience level from years instead of always 'intermediate'.
  static String _deriveExperienceLevel(int? years) {
    if (years == null || years <= 0) return 'basic';
    if (years >= 8) return 'expert';
    if (years >= 4) return 'intermediate';
    return 'basic';
  }

  /// Compute a DNA score from actual worker data instead of flat 800.
  static int _computeNewWorkerDna({
    required double rating,
    required int totalJobs,
    int? experienceYears,
  }) {
    // Base: 500 for brand new workers
    double score = 500.0;
    // Rating contribution (max +200): rating/5 * 200
    score += (rating / 5.0) * 200;
    // Job volume contribution (max +150): capped at 300 jobs
    score += (totalJobs.clamp(0, 300) / 300.0) * 150;
    // Experience contribution (max +150): capped at 10 years
    final years = (experienceYears ?? 0).clamp(0, 10);
    score += (years / 10.0) * 150;
    return score.round().clamp(100, 1000);
  }

  /// Parse time slots from availability rules instead of hardcoding.
  /// If rules mention specific times, extract them. Otherwise generate
  /// reasonable defaults based on the rule patterns.
  static List<String> _parseSlotsFromRules(List<String>? rules) {
    if (rules == null || rules.isEmpty) {
      // No rules set: return standard business hours
      return ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
    }

    final slots = <String>{};
    final timePattern = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(?:am|pm|AM|PM)?');
    final rulesText = rules.join(' ').toLowerCase();

    // Extract explicit times from rules
    for (final match in timePattern.allMatches(rules.join(' '))) {
      final hour = int.tryParse(match.group(1) ?? '') ?? 0;
      final minute = match.group(2) ?? '00';
      final text = match.group(0)?.toLowerCase() ?? '';
      var h = hour;
      if (text.contains('pm') && h < 12) h += 12;
      if (text.contains('am') && h == 12) h = 0;
      if (h >= 6 && h <= 21) {
        slots.add('${h.toString().padLeft(2, '0')}:$minute');
      }
    }

    // If we found explicit times, return them sorted
    if (slots.isNotEmpty) {
      final sorted = slots.toList()..sort();
      return sorted;
    }

    // Infer from keywords in rules
    if (rulesText.contains('morning') || rulesText.contains('subah')) {
      slots.addAll(['08:00', '09:00', '10:00', '11:00']);
    }
    if (rulesText.contains('afternoon') || rulesText.contains('dopahar')) {
      slots.addAll(['12:00', '13:00', '14:00', '15:00']);
    }
    if (rulesText.contains('evening') || rulesText.contains('shaam')) {
      slots.addAll(['16:00', '17:00', '18:00', '19:00']);
    }
    if (rulesText.contains('24/7') || rulesText.contains('all day') || rulesText.contains('anytime')) {
      slots.addAll(['08:00', '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00']);
    }

    if (slots.isNotEmpty) {
      final sorted = slots.toList()..sort();
      return sorted;
    }

    // Fallback: standard business hours
    return ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
  }
}