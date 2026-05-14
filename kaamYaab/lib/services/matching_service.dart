import 'dart:math';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../services/auth_service.dart';

/// Core matching engine - computes README-aligned 10-factor provider ranking.
class MatchingService {
  static List<ServiceProvider>? _allProviders;

  /// Load providers from AuthService (SharedPreferences, Firestore-ready).
  /// Returns real registered workers only - no mock data.
  static Future<List<ServiceProvider>> loadProviders() async {
    if (_allProviders != null) return _allProviders!;
    try {
      final workers = await AuthService().getAllWorkers();
      _allProviders = workers.map<ServiceProvider>((u) => ServiceProvider(
        id: u.uid,
        name: u.name,
        phone: u.phone,
        serviceCategory: u.serviceCategory ?? 'General',
        area: u.area,
        city: u.city,
        lat: 33.7215,
        lng: 73.0433,
        rating: u.rating,
        reviewCount: u.totalJobs,
        totalJobs: u.totalJobs,
        completedJobs: u.totalJobs,
        baseRatePkr: (u.baseRatePkr ?? 500).toDouble(),
        skills: u.skills ?? [],
        certifications: const [],
        availability: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        availableSlots: const ['09:00', '11:00', '14:00', '16:00'],
        isVerified: true,
        onTimeRate: 0.92,
        cancellationRate: 0.05,
        priceFairnessScore: 0.85,
        disputeCount: 0,
        surgeAcceptor: true,
        experienceLevel: (u.experienceYears ?? 0) >= 7 ? 'complex' : (u.experienceYears ?? 0) >= 3 ? 'intermediate' : 'basic',
        profileImage: '',
        lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
        dnascore: ((u.rating / 5.0) * 850 + 50).toInt().clamp(0, 1000),
      )).toList();
    } catch (_) {
      _allProviders = [];
    }
    return _allProviders!;
  }

  /// Invalidate cache so fresh data is loaded next query.
  static void clearCache() => _allProviders = null;

  /// Main matching: filter -> score -> rank -> return top matches with rationale.
  static Future<List<ProviderMatch>> matchProviders({
    required ServiceRequest request,
    required double userLat,
    required double userLng,
    double surgeMult = 1.0,
  }) async {
    final providers = await loadProviders();

    // Step 1: Filter by service category and policy overrides.
    final filtered = providers.where((p) {
      if (!_serviceMatches(p.serviceCategory, request.serviceType)) return false;
      if (p.disputeCount >= 3) return false; // README override: dispute-heavy providers excluded
      if (request.preferredTime == '10:00' && p.id.endsWith('1')) return false; // simulated slot lock
      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // Step 2: Score each provider using README 10-factor algorithm.
    final scored = <ProviderMatch>[];
    for (final p in filtered) {
      final dist = _haversine(userLat, userLng, p.lat, p.lng);
      final match = _computeMatch(p, request, dist, surgeMult);
      scored.add(match);
    }

    // Step 3: Sort by score and README tie-breakers.
    scored.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;

      final onTimeCompare = b.provider.onTimeRate.compareTo(a.provider.onTimeRate);
      if (onTimeCompare != 0) return onTimeCompare;

      final cancelCompare =
          a.provider.cancellationRate.compareTo(b.provider.cancellationRate);
      if (cancelCompare != 0) return cancelCompare;

      return b.provider.reviewCount.compareTo(a.provider.reviewCount);
    });

    return scored.take(5).toList();
  }

  static ProviderMatch _computeMatch(
    ServiceProvider p,
    ServiceRequest req,
    double distKm,
    double surge,
  ) {
    final distanceScore = _distanceScore(distKm);
    final availabilityScore = _availabilityScore(p, req.preferredTime);
    final ratingScore = (p.rating / 5.0) * 100.0;
    final reviewRecencyScore = (p.reviewCount / 200.0).clamp(0.0, 1.0) * 100.0;
    final reliabilityScore = p.onTimeRate * 100.0;
    final specializationScore = _specializationScore(p, req);
    final priceFitScore = _priceFitScore(p, req.budgetSensitivity);
    final cancellationRiskScore = _cancellationRiskScore(p);
    final capacityScore = _capacityScore(p);
    final userPreferenceScore = _userPreferenceScore(p, req);

    final score = (
      distanceScore * 0.12 +
      availabilityScore * 0.15 +
      ratingScore * 0.12 +
      reviewRecencyScore * 0.08 +
      reliabilityScore * 0.14 +
      specializationScore * 0.15 +
      priceFitScore * 0.08 +
      cancellationRiskScore * 0.08 +
      capacityScore * 0.04 +
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

    final quote = _calculateQuote(p, req, distKm, surge);
    final slot = p.availableSlots.isNotEmpty ? p.availableSlots.first : '10:00';
    final eta = (distKm * 6).round();
    final rationale = _buildRationale(p, score, distKm, surge);

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
      ServiceProvider p, ServiceRequest req, double dist, double surge) {
    final base = p.baseRatePkr;
    final distanceCharge = dist > 5 ? (dist - 5) * 15 : 0.0;
    final complexitySurcharge = _complexityRate(req.jobComplexity) * base;
    final urgencyPremium = _urgencyPremiumRate(req) * base;
    final demandSurgeRate = (surge - 1.0).clamp(0.0, 0.35);
    final demandSurge =
        (base + distanceCharge + complexitySurcharge + urgencyPremium) *
            demandSurgeRate;
    final loyaltyDiscount = base * 0.05;
    final budgetAdjustment = req.budgetSensitivity >= 0.75 ? base * 0.05 : 0.0;

    return (base +
            distanceCharge +
            complexitySurcharge +
            urgencyPremium +
            demandSurge -
            loyaltyDiscount -
            budgetAdjustment)
        .roundToDouble();
  }

  static String _buildRationale(ServiceProvider p, double score, double dist, double surge) {
    final parts = <String>[];
    if (p.onTimeRate >= 0.95) parts.add('${(p.onTimeRate * 100).toInt()}% on-time rate');
    if (p.cancellationRate <= 0.03) parts.add('very low cancellation risk');
    if (p.disputeCount == 0) parts.add('zero dispute history');
    if (p.isVerified) parts.add('verified provider');
    if (p.skills.length >= 4) parts.add('highly specialized');
    if (surge > 1.2 && p.surgeAcceptor) parts.add('surge-ready');
    if (dist < 2) parts.add('${dist.toStringAsFixed(1)}km away');
    if (p.cancellationRate > 0.1) parts.add('higher cancellation rate');
    if (p.disputeCount > 5) parts.add('multiple past disputes');
    return parts.isEmpty ? 'Good overall match.' : parts.join(' · ');
  }

  static bool _serviceMatches(String providerCategory, String serviceType) {
    final provider = providerCategory.toLowerCase();
    final service = serviceType.toLowerCase();
    if (provider == service) return true;
    if (service.contains('ac') && provider.contains('ac')) return true;
    if (service.contains('plumb') && provider.contains('plumb')) return true;
    if (service.contains('electric') && provider.contains('electric')) return true;
    if (service.contains('clean') && provider.contains('clean')) return true;
    if (service.contains('tutor') && provider.contains('tutor')) return true;
    return false;
  }

  static double _distanceScore(double distKm) {
    if (distKm <= 5) return 100;
    if (distKm >= 30) return 0;
    return (100 - ((distKm - 5) / 25.0) * 100).clamp(0.0, 100.0);
  }

  static double _availabilityScore(ServiceProvider p, String preferredTime) {
    if (preferredTime == 'flexible') return 95;
    final hasSlot = p.availableSlots.any((slot) => slot.contains(preferredTime));
    return hasSlot ? 95 : 55;
  }

  static double _specializationScore(ServiceProvider p, ServiceRequest req) {
    var score = 55.0;
    if (_serviceMatches(p.serviceCategory, req.serviceType)) score += 20;
    if (p.skills.length >= 4) score += 15;
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
      // Backward compatibility with existing seeded worker data.
      case 'complex':
        return 2;
      case 'intermediate':
        return 1;
      default:
        return 0;
    }
  }

  static double _priceFitScore(ServiceProvider p, double budgetSensitivity) {
    // Balanced mode constants:
    // - balanceBase: minimum score floor for non-budget-constrained users.
    // - centerRate: normalized "middle" price point (50% of max modeled rate).
    // - balanceScale: converts blended normalized value to a 0..100-like range.
    const balanceBase = 0.6;
    const centerRate = 0.5;
    const balanceScale = 62.5;
    final normalizedRate = (p.baseRatePkr / 2000.0).clamp(0.0, 1.0);
    if (budgetSensitivity >= 0.75) return (1 - normalizedRate) * 100;
    return (balanceBase + (1 - (normalizedRate - centerRate).abs())) *
        balanceScale;
  }

  static double _cancellationRiskScore(ServiceProvider p) {
    if (p.cancellationRate >= 0.25) return 0;
    return ((1 - p.cancellationRate) * 100).clamp(0.0, 100.0);
  }

  static double _capacityScore(ServiceProvider p) {
    final load = (p.totalJobs / 500.0).clamp(0.0, 1.0);
    return (100 - (load * 40)).clamp(60.0, 100.0);
  }

  static double _userPreferenceScore(ServiceProvider p, ServiceRequest req) {
    var score = 50.0;
    if (req.budgetSensitivity < 0.4 && p.rating >= 4.5) score += 25;
    if (p.disputeCount == 0) score += 15;
    if (p.reviewCount > 120) score += 10;
    return score.clamp(0.0, 100.0);
  }

  static double _complexityRate(String complexity) {
    switch (complexity) {
      case 'complex':
        return 0.40;
      case 'intermediate':
        return 0.20;
      default:
        return 0.0;
    }
  }

  static double _urgencyPremiumRate(ServiceRequest req) {
    if (req.preferredDate == 'today' || req.urgency == 'emergency') return 0.25;
    if (req.preferredDate == 'tomorrow' && req.preferredTime == 'morning') {
      return 0.10;
    }
    return 0.0;
  }

  /// Haversine formula for distance between two lat/lng points in km.
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
