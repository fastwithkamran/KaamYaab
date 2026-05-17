import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../utils/distance_utils.dart';
import '../services/auth_service.dart';
import '../config/runtime_config.dart';
import 'ai_service.dart';

/// Core matching engine - computes README-aligned 10-factor provider ranking.
class MatchingService {
  static const double _maxReviewCountForScore = 200.0;
  static const double _maxModeledBaseRatePkr = 2000.0;
  static const double _maxDemandSurgeRate = 0.35; // README cap: 35%
  static const double _priceFitBalanceBase = 0.6;
  static const double _priceFitCenterRate = 0.5;
  static const double _priceFitBalanceScale = 62.5;

  static List<ServiceProvider>? _allProviders;

  /// Load providers from local static JSON dataset.
  static Future<List<ServiceProvider>> loadProviders() async {
    if (_allProviders != null) return _allProviders!;
    try {
      final raw = await rootBundle.loadString('assets/data/providers_mock.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = (decoded['providers'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      _allProviders = list.map(ServiceProvider.fromJson).toList();

      // Merge live workers
      final liveWorkers = await AuthService().getAllWorkers();
      for (var worker in liveWorkers) {
        if (worker.latitude != null && worker.longitude != null) {
          _allProviders!.add(ServiceProvider(
            id: worker.uid,
            name: worker.name,
            phone: worker.phone,
            serviceCategory: worker.serviceCategory ?? 'General',
            skills: worker.skills ?? [],
            lat: worker.latitude!,
            lng: worker.longitude!,
            area: worker.area,
            city: worker.city,
            dnascore: 800,
            rating: worker.rating,
            totalJobs: worker.totalJobs,
            completedJobs: worker.totalJobs,
            onTimeRate: 0.9,
            cancellationRate: 0.05,
            priceFairnessScore: 0.8,
            disputeCount: 0,
            surgeAcceptor: true,
            baseRatePkr: worker.baseRatePkr ?? 500.0,
            experienceLevel: 'intermediate',
            certifications: [],
            availability: worker.availabilityRules ?? [],
            availableSlots: ['09:00', '10:00', '14:00', '16:00'],
            reviewCount: 0,
            profileImage: worker.profileImageBase64 ?? '',
            isVerified: true,
            lastActiveDate: DateTime.now().toIso8601String(),
          ));
        }
      }
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
    bool isUrdu = false,
  }) async {
    final providers = await loadProviders();

    // Step 1: Filter by service category and policy overrides.
    final filtered = providers.where((p) {
      if (!_serviceMatches(p.serviceCategory, request.serviceType)) return false;
      if (p.disputeCount >= 3) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // ─── Agentic Path: If API key exists, let AI rank them ──────────────
    if (RuntimeConfig.cohereApiKey.isNotEmpty) {
      final providerMaps = filtered.map((p) => {
        'id': p.id,
        'name': p.name,
        'rating': p.rating,
        'total_jobs': p.totalJobs,
        'price': p.baseRatePkr,
        'skills': p.skills,
        'on_time': p.onTimeRate,
        'area': p.area,
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
          final match = _computeMatch(p, request, dist, surgeMult, isUrdu: isUrdu);
          
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
      final match = _computeMatch(p, request, dist, surgeMult, isUrdu: isUrdu);
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
    double surge, {
    bool isUrdu = false,
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
      ServiceProvider p, ServiceRequest req, double dist, double surge) {
    final base = p.baseRatePkr;
    final distanceCharge = dist > 5 ? (dist - 5) * 15 : 0.0;
    final complexitySurcharge = _complexityRate(req.jobComplexity) * base;
    final urgencyPremium = _urgencyPremiumRate(req) * base;
    final demandSurgeRate = (surge - 1.0).clamp(0.0, _maxDemandSurgeRate);
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

  static String _buildRationale(ServiceProvider p, double score, double dist, double surge, {bool isUrdu = false}) {
    final parts = <String>[];
    if (isUrdu) {
      if (p.onTimeRate >= 0.95) parts.add('${(p.onTimeRate * 100).toInt()}% وقت پر آمد');
      if (p.cancellationRate <= 0.03) parts.add('بہت کم منسوخی کا خطرہ');
      if (p.disputeCount == 0) parts.add('کوئی شکایت نہیں');
      if (p.isVerified) parts.add('تصدیق شدہ');
      if (p.skills.length >= 4) parts.add('انتہائی ماہر');
      if (surge > 1.2 && p.surgeAcceptor) parts.add('سرج ریڈی');
      if (dist < 2) parts.add('${dist.toStringAsFixed(1)} کلومیٹر دور');
      if (p.cancellationRate > 0.1) parts.add('منسوخی کا زیادہ خطرہ');
      if (p.disputeCount > 5) parts.add('کئی پرانی شکایات');
      return parts.isEmpty ? 'بہترین انتخاب۔' : parts.join(' · ');
    } else {
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
  }

  static bool _serviceMatches(String providerCategory, String serviceType) {
    final provider = providerCategory.toLowerCase();
    final service = serviceType.toLowerCase();
    if (provider == service) return true;
    // AC / cooling
    if ((service.contains('ac') || service.contains('air con') || service.contains('cooling')) &&
        (provider.contains('ac') || provider.contains('air con') || provider.contains('technician'))) return true;
    // Plumbing
    if ((service.contains('plumb') || service.contains('pipe') || service.contains('water')) &&
        (provider.contains('plumb') || provider.contains('pipe'))) return true;
    // Electrical
    if ((service.contains('electric') || service.contains('wiring')) &&
        (provider.contains('electric'))) return true;
    // Cleaning
    if ((service.contains('clean') || service.contains('safai')) &&
        (provider.contains('clean'))) return true;
    // Tutoring / teaching
    if ((service.contains('tutor') || service.contains('teach') || service.contains('parhai')) &&
        (provider.contains('tutor') || provider.contains('teach'))) return true;
    // Carpentry
    if ((service.contains('carpent') || service.contains('wood') || service.contains('furniture') || service.contains('darwaza')) &&
        (provider.contains('carpent') || provider.contains('wood') || provider.contains('furniture'))) return true;
    // Painting
    if ((service.contains('paint') || service.contains('rang') || service.contains('colour')) &&
        (provider.contains('paint'))) return true;
    // Gardening
    if ((service.contains('garden') || service.contains('plant') || service.contains('lawn')) &&
        (provider.contains('garden') || provider.contains('plant'))) return true;
    // Cook / food
    if ((service.contains('cook') || service.contains('khana') || service.contains('bawarchi')) &&
        (provider.contains('cook') || provider.contains('chef') || provider.contains('bawarchi'))) return true;
    // Driver
    if ((service.contains('driver') || service.contains('cab') || service.contains('gari')) &&
        (provider.contains('driver') || provider.contains('cab'))) return true;
    // Security
    if ((service.contains('security') || service.contains('guard')) &&
        (provider.contains('security') || provider.contains('guard'))) return true;
    return false;
  }

  static double _distanceScore(double distKm) {
    if (distKm <= 5) return 100;
    if (distKm >= 30) return 0;
    return (100 - ((distKm - 5) / 25.0) * 100).clamp(0.0, 100.0);
  }

  static double _availabilityScore(ServiceProvider p, String preferredTime) {
    if (preferredTime == 'flexible') return 95;
    
    // Simple availability rules check for live workers
    if (p.availability.isNotEmpty) {
      final rulesStr = p.availability.join(' ').toLowerCase();
      if (rulesStr.contains('off') || rulesStr.contains('not available') || rulesStr.contains('busy')) {
        return 0; // Filter out if agent memory says they are off
      }
    }

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
      case 'advanced': // accepted alias for external/legacy datasets
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
    if (budgetSensitivity >= 0.75) return (1 - normalizedRate) * 100;
    return (_priceFitBalanceBase +
            (1 - (normalizedRate - _priceFitCenterRate).abs())) *
        _priceFitBalanceScale;
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

}
