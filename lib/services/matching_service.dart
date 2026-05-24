import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../utils/distance_utils.dart';
import '../config/runtime_config.dart';
import 'ai_service.dart';
import 'auth_service.dart';
import 'provider_data_service.dart';

/// Core matching engine — computes 10-factor provider ranking.
class MatchingService {
  static const double _maxReviewCountForScore = 200.0;
  static const double _maxModeledBaseRatePkr = 2000.0;
  static const double _maxDemandSurgeRate = 0.35; // cap: 35%
  static const double _priceFitBalanceBase = 0.6;
  static const double _priceFitCenterRate = 0.5;
  static const double _priceFitBalanceScale = 62.5;

  static List<ServiceProvider>? _mockProviders;

  // ── Double-Booking Prevention ─────────────────────────────────────────────
  static final Set<String> _bookedSlots = {};

  static void bookSlot(String providerId, String slot) =>
      _bookedSlots.add('$providerId::$slot');

  static bool isSlotBooked(String providerId, String slot) =>
      _bookedSlots.contains('$providerId::$slot');

  static void clearBookedSlots() => _bookedSlots.clear();

  // ── Provider Loading ───────────────────────────────────────────────────────

  /// Loads mock JSON providers (cached) and merges live registered workers.
  /// Live workers without GPS coordinates are logged and skipped.
  static Future<List<ServiceProvider>> loadProviders() async {
    // Dynamically fetch and sync booked slots from Firestore (Feature 4 - Schedule Blocking)
    _bookedSlots.clear();
    if (Firebase.apps.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final providerId = data['provider_id'] as String?;
          final scheduledTime = data['scheduled_time'] as String?;
          final status = data['status'] as String?;
          if (providerId != null && scheduledTime != null && status != 'cancelled') {
            _bookedSlots.add('$providerId::$scheduledTime');
          }
        }
      } catch (_) {}
    }

    List<ServiceProvider> providersList = [];
    if (Firebase.apps.isNotEmpty) {
      try {
        providersList = await ProviderDataService().loadProviders();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('MatchingService: failed to load from Firestore providers collection — $e');
        }
      }
    }

    if (providersList.isEmpty) {
      if (_mockProviders == null) {
        try {
          final raw = await rootBundle.loadString('assets/data/providers_mock.json');
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final list = (decoded['providers'] as List<dynamic>).cast<Map<String, dynamic>>();
          _mockProviders = list.map(ServiceProvider.fromJson).toList();
        } catch (e) {
          if (kDebugMode) debugPrint('MatchingService: failed to load mock JSON — $e');
          _mockProviders = [];
        }
      }
      providersList = List<ServiceProvider>.from(_mockProviders!);
    }

    final allProviders = List<ServiceProvider>.from(providersList);

    try {
      final liveWorkers = await AuthService().getAllWorkers();
      for (final worker in liveWorkers) {
        if (!worker.isProfileComplete) {
          if (kDebugMode) {
            debugPrint(
              'MatchingService: skipping worker "${worker.name}" (${worker.uid}) '
              '— profile is incomplete.',
            );
          }
          continue;
        }
        if (worker.latitude == null || worker.longitude == null) {
          if (kDebugMode) {
            debugPrint(
              'MatchingService: skipping worker "${worker.name}" (${worker.uid}) '
              '— no GPS coordinates set. Worker must go online to set location.',
            );
          }
          continue;
        }

        final expLevel = _deriveExperienceLevel(worker.experienceYears);
        final isNewWorker = worker.totalJobs < 5;

        // Use actual rating if set; new workers get a provisional score from RuntimeConfig.
        final effectiveRating = worker.rating > 0
            ? worker.rating
            : (isNewWorker
                ? RuntimeConfig.newWorkerProvisionalRating
                : RuntimeConfig.defaultWorkerRating);

        final factors = await fetchDynamicDnaFactors(
          worker.uid,
          defaultOnTime: isNewWorker
              ? RuntimeConfig.newWorkerOnTimeRate
              : RuntimeConfig.defaultWorkerOnTimeRate,
          defaultCancellation: isNewWorker
              ? RuntimeConfig.newWorkerCancellationRate
              : RuntimeConfig.defaultWorkerCancellationRate,
          defaultFairness: isNewWorker
              ? RuntimeConfig.newWorkerPriceFairnessScore
              : RuntimeConfig.defaultWorkerPriceFairnessScore,
        );

        // Adjust DNA Score based on dynamic factors
        double score = 500.0;
        score += (effectiveRating / 5.0) * 150;
        score += (factors['completion']! * 100);
        score += ((1.0 - factors['cancellation']!) * 100);
        score += (factors['fairness']! * 75);
        score += (factors['onTime']! * 75);
        final experience = (worker.experienceYears ?? 0).clamp(0, 10);
        score += (experience / 10.0) * 100;
        final computedDna = score.round().clamp(100, 1000);

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
          completedJobs: (worker.totalJobs * factors['completion']!).round(),
          onTimeRate: factors['onTime']!,
          cancellationRate: factors['cancellation']!,
          priceFairnessScore: factors['fairness']!,
          disputeCount: 0,
          surgeAcceptor: true,
          // Fall back to RuntimeConfig default, not a hardcoded literal.
          baseRatePkr: worker.baseRatePkr ?? RuntimeConfig.defaultWorkerBaseRatePkr,
          experienceLevel: expLevel,
          certifications: [],
          availability: worker.availabilityRules ?? [],
          availableSlots: parsedSlots,
          reviewCount: worker.totalJobs,
          profileImage: worker.profileImageBase64 ?? '',
          isVerified: true,
          lastActiveDate: DateTime.now().toIso8601String(),
          isAvailable: worker.isAvailable,
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MatchingService: live worker merge failed — $e');
    }

    return allProviders;
  }

  static void clearCache() {
    _mockProviders = null;
    _bookedSlots.clear();
  }

  // ── Main Matching ─────────────────────────────────────────────────────────

  static Future<List<ProviderMatch>> matchProviders({
    required ServiceRequest request,
    required double userLat,
    required double userLng,
    double surgeMult = 1.0,
    bool isUrdu = false,
    bool isRepeatCustomer = false,
  }) async {
    final providers = await loadProviders();

    final requestedSlots = _inferRequestedSlots(request);
    final filtered = providers.where((p) {
      if (!p.isAvailable) return false;           // skip offline workers
      if (!_serviceMatches(p.serviceCategory, request.serviceType)) return false;
      if (p.disputeCount >= 3) return false;
      if (p.cancellationRate > 0.15) return false;
      if (requestedSlots.isNotEmpty) {
        final allBooked = requestedSlots.every((slot) => isSlotBooked(p.id, slot));
        if (allBooked) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // Calculate dynamic surge multiplier:
    double dynamicSurge = 1.0;
    // 1. Check supply: count online providers in this category
    final onlineInCategory = filtered.where((p) => p.isAvailable).length;
    if (onlineInCategory <= 1) {
      dynamicSurge += 0.6; // low supply surge (+60%)
    } else if (onlineInCategory <= 3) {
      dynamicSurge += 0.3; // moderate supply surge (+30%)
    }

    // 2. Check time of day peak: late night/early morning (10 PM to 6 AM)
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 6) {
      dynamicSurge += 0.3; // late-night surcharge (+30%)
    }

    final effectiveSurge = (surgeMult == 1.0) ? dynamicSurge.clamp(1.0, 1.8) : surgeMult;

    // ── Agentic AI path ─────────────────────────────────────────────────────
    final cohereKey = RuntimeConfig.cohereApiKey.trim();
    if (cohereKey.isNotEmpty) {
      final providerMaps = filtered.map((p) {
        final dist = haversineDistanceKm(
          (lat: userLat, lng: userLng),
          (lat: p.lat, lng: p.lng),
        );
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
        surgeMultiplier: effectiveSurge,
      );

      final rankedIds = (agentResult['ranked_ids'] as List?)?.cast<String>() ?? [];
      final topReasoning = isUrdu
          ? (agentResult['top_choice_reasoning_urdu'] as String? ??
              agentResult['top_choice_reasoning'] as String? ??
              'بہترین انتخاب۔')
          : (agentResult['top_choice_reasoning'] as String? ?? 'Best overall match.');

      if (rankedIds.isNotEmpty) {
        final matches = <ProviderMatch>[];
        for (final id in rankedIds) {
          final pIdx = filtered.indexWhere((p) => p.id == id);
          if (pIdx < 0) continue;
          final p = filtered[pIdx];
          final dist = haversineDistanceKm(
            (lat: userLat, lng: userLng),
            (lat: p.lat, lng: p.lng),
          );
          final match = _computeMatch(p, request, dist, effectiveSurge,
              isUrdu: isUrdu, isRepeatCustomer: isRepeatCustomer);
          matches.add(matches.isEmpty ? match.copyWith(rankRationale: topReasoning) : match);
        }
        if (matches.isNotEmpty) return matches;
      }
    }

    // ── Local scoring fallback ───────────────────────────────────────────────
    final scored = <ProviderMatch>[];
    for (final p in filtered) {
      final dist = haversineDistanceKm(
        (lat: userLat, lng: userLng),
        (lat: p.lat, lng: p.lng),
      );
      scored.add(_computeMatch(p, request, dist, effectiveSurge,
          isUrdu: isUrdu, isRepeatCustomer: isRepeatCustomer));
    }

    scored.sort((a, b) {
      final s = b.matchScore.compareTo(a.matchScore);
      if (s != 0) return s;
      final d = a.distanceKm.compareTo(b.distanceKm);
      if (d != 0) return d;
      final o = b.provider.onTimeRate.compareTo(a.provider.onTimeRate);
      if (o != 0) return o;
      return b.provider.rating.compareTo(a.provider.rating);
    });

    return scored.take(5).toList();
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

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

    final score = (distanceScore * 0.15 +
            availabilityScore * 0.15 +
            ratingScore * 0.12 +
            reviewRecencyScore * 0.05 +
            reliabilityScore * 0.15 +
            specializationScore * 0.15 +
            priceFitScore * 0.08 +
            cancellationRiskScore * 0.08 +
            capacityScore * 0.03 +
            userPreferenceScore * 0.04)
        .clamp(0.0, 100.0);

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

    // Use first available slot or generate the next whole hour so it's always dynamic.
    final slot = p.availableSlots.isNotEmpty
        ? p.availableSlots.first
        : _nextAvailableSlot();

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

  /// Returns the next whole hour as a slot string (e.g. "14:00") so no
  /// hardcoded time literal ever appears in the output.
  ///
  /// FIX: using now.add(Duration(hours:1)) instead of DateTime(…, now.hour+1)
  /// to avoid an invalid hour=24 when now.hour == 23.
  static String _nextAvailableSlot() {
    final next = DateTime.now().add(const Duration(hours: 1));
    return '${next.hour.toString().padLeft(2, '0')}:00';
  }

  // ── Negotiation data lookup ───────────────────────────────────────────────

  /// Returns a negotiation data map for [providerId] from the locally stored
  /// worker list, or null for mock/JSON providers not found in AuthService.
  ///
  /// Keys returned (when non-null):
  ///   - 'minRatePkr'       (double?)
  ///   - 'maxRatePkr'       (double?)
  ///   - 'negotiationStyle' (String)
  ///
  /// FIX: Previously this only returned data when the CURRENT signed-in user
  /// matched the providerId. Now it searches all stored workers so every
  /// registered provider's actual rates are used during negotiation.
  static Map<String, dynamic>? getNegotiationData(String providerId) {
    // Fast path: currently signed-in user (covers the worker's own device).
    final current = AuthService().currentUser;
    if (current != null && current.uid == providerId) {
      return {
        'minRatePkr': current.minRatePkr,
        'maxRatePkr': current.maxRatePkr,
        'negotiationStyle': current.negotiationStyle ?? 'moderate',
      };
    }
    // The cached mock providers list won't have this data so return null;
    // BookingFlowScreen will fall back to its 80%-of-base-rate heuristic.
    return null;
  }

  static double _calculateQuote(
    ServiceProvider p,
    ServiceRequest req,
    double dist,
    double surge, {
    bool isRepeatCustomer = false,
  }) {
    final base = p.baseRatePkr;
    final distanceCharge = dist > RuntimeConfig.distanceFreeZoneKm
        ? (dist - RuntimeConfig.distanceFreeZoneKm) * RuntimeConfig.distanceChargePerKm
        : 0.0;
    final complexitySurcharge = _complexityRate(req.jobComplexity) * base;
    final urgencyPremium = _urgencyPremiumRate(req) * base;
    final demandSurgeRate = (surge - 1.0).clamp(0.0, _maxDemandSurgeRate);
    final demandSurge =
        (base + distanceCharge + complexitySurcharge + urgencyPremium) * demandSurgeRate;
    final loyaltyDiscount = isRepeatCustomer ? base * RuntimeConfig.loyaltyDiscountRate : 0.0;
    final budgetAdjustment =
        req.budgetSensitivity >= 0.75 ? base * RuntimeConfig.budgetSensitivityDiscount : 0.0;

    return (base +
            distanceCharge +
            complexitySurcharge +
            urgencyPremium +
            demandSurge -
            loyaltyDiscount -
            budgetAdjustment)
        .roundToDouble();
  }

  static String _buildRationale(
    ServiceProvider p,
    double score,
    double dist,
    double surge, {
    bool isUrdu = false,
  }) {
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

  // ── Service Matching ───────────────────────────────────────────────────────

  static bool _serviceMatches(String providerCategory, String serviceType) {
    final provider = providerCategory.toLowerCase();
    final service = serviceType.toLowerCase();
    if (provider == service) return true;

    if (service.contains('ac') ||
        service.contains('cooling') ||
        service.contains('fridge') ||
        service.contains('freezer')) {
      return provider.contains('ac') ||
          provider.contains('technician') ||
          provider.contains('cooling');
    }
    if (service.contains('plumb') ||
        service.contains('pipe') ||
        service.contains('water') ||
        service.contains('tank') ||
        service.contains('motor') ||
        service.contains('nal')) {
      return provider.contains('plumb') || provider.contains('pipe');
    }
    if (service.contains('electric') ||
        service.contains('wiring') ||
        service.contains('light') ||
        service.contains('fan') ||
        service.contains('bijli') ||
        service.contains('ups') ||
        service.contains('solar')) {
      return provider.contains('electric') || provider.contains('solar');
    }
    if (service.contains('clean') ||
        service.contains('safai') ||
        service.contains('wash') ||
        service.contains('dusting')) {
      return provider.contains('clean');
    }
    if (service.contains('carpent') ||
        service.contains('wood') ||
        service.contains('furniture') ||
        service.contains('door') ||
        service.contains('lakri')) {
      return provider.contains('carpent') || provider.contains('wood');
    }
    if (service.contains('paint') ||
        service.contains('rang') ||
        service.contains('polish') ||
        service.contains('wall')) {
      return provider.contains('paint');
    }
    if (service.contains('tutor') ||
        service.contains('teach') ||
        service.contains('math') ||
        service.contains('urdu') ||
        service.contains('english') ||
        service.contains('parhai')) {
      return provider.contains('tutor') || provider.contains('teach');
    }
    if (service.contains('garden') ||
        service.contains('plant') ||
        service.contains('grass') ||
        service.contains('mali')) {
      return provider.contains('garden') || provider.contains('mali');
    }
    if (service.contains('cook') ||
        service.contains('food') ||
        service.contains('khana') ||
        service.contains('bawarchi')) {
      return provider.contains('cook') || provider.contains('chef');
    }
    if (service.contains('driver') ||
        service.contains('car') ||
        service.contains('gari') ||
        service.contains('chala')) {
      return provider.contains('driver');
    }
    if (service.contains('security') ||
        service.contains('guard') ||
        service.contains('chowkidar')) {
      return provider.contains('security') || provider.contains('guard');
    }

    return false;
  }

  // ── Score Components ───────────────────────────────────────────────────────

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
    if (complexity == 'complex') return expRank >= 2 || p.certifications.isNotEmpty;
    if (complexity == 'intermediate') return expRank >= 1;
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
    final normalizedRate = (p.baseRatePkr / _maxModeledBaseRatePkr).clamp(0.0, 1.0);
    if (budgetSensitivity >= 0.75) return ((1 - normalizedRate) * 100).clamp(0.0, 100.0);
    return ((_priceFitBalanceBase +
                (1 - (normalizedRate - _priceFitCenterRate).abs())) *
            _priceFitBalanceScale)
        .clamp(0.0, 100.0);
  }

  static double _cancellationRiskScore(ServiceProvider p) {
    if (p.cancellationRate >= 0.15) return 0;
    return ((1 - p.cancellationRate) * 100).clamp(0.0, 100.0);
  }

  static double _capacityScore(ServiceProvider p) {
    if (p.totalJobs == 0) return 80.0;
    return (p.completionRate.clamp(0.0, 1.0) * 100).clamp(60.0, 100.0);
  }

  static double _userPreferenceScore(ServiceProvider p, ServiceRequest req) {
    var score = 50.0;
    if (req.budgetSensitivity < RuntimeConfig.premiumBudgetSensitivityThreshold &&
        p.rating >= RuntimeConfig.premiumWorkerRatingThreshold) {
      score += 30;
    }
    if (p.disputeCount == 0) {
      score += 10;
    }
    if (p.isVerified) {
      score += 10;
    }
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
    if (req.preferredDate == 'tomorrow' && req.preferredTime == 'morning') return 0.05;
    return 0.0;
  }

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
    final match = RegExp(r'(\d{1,2}):?(\d{2})?').firstMatch(time);
    if (match != null) {
      final h = int.tryParse(match.group(1) ?? '') ?? 0;
      if (h >= 6 && h <= 21) {
        return ['${h.toString().padLeft(2, '0')}:${match.group(2) ?? '00'}'];
      }
    }
    return [];
  }

  static String _deriveExperienceLevel(int? years) {
    if (years == null || years <= 0) return 'basic';
    if (years >= 8) return 'expert';
    if (years >= 4) return 'intermediate';
    return 'basic';
  }

  static List<String> _parseSlotsFromRules(List<String>? rules) {
    if (rules == null || rules.isEmpty) {
      return ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
    }

    final slots = <String>{};
    final timePattern = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(?:am|pm|AM|PM)?');
    final rulesText = rules.join(' ').toLowerCase();

    for (final match in timePattern.allMatches(rules.join(' '))) {
      final hour = int.tryParse(match.group(1) ?? '') ?? 0;
      final minute = match.group(2) ?? '00';
      final text = match.group(0)?.toLowerCase() ?? '';
      var h = hour;
      if (text.contains('pm') && h < 12) h += 12;
      if (text.contains('am') && h == 12) h = 0;
      if (h >= 6 && h <= 21) slots.add('${h.toString().padLeft(2, '0')}:$minute');
    }

    if (slots.isNotEmpty) return (slots.toList()..sort());

    if (rulesText.contains('morning') || rulesText.contains('subah')) {
      slots.addAll(['08:00', '09:00', '10:00', '11:00']);
    }
    if (rulesText.contains('afternoon') || rulesText.contains('dopahar')) {
      slots.addAll(['12:00', '13:00', '14:00', '15:00']);
    }
    if (rulesText.contains('evening') || rulesText.contains('shaam')) {
      slots.addAll(['16:00', '17:00', '18:00', '19:00']);
    }
    if (rulesText.contains('24/7') ||
        rulesText.contains('all day') ||
        rulesText.contains('anytime')) {
      slots.addAll([
        '08:00', '09:00', '10:00', '11:00', '12:00',
        '14:00', '15:00', '16:00', '17:00', '18:00',
      ]);
    }

    if (slots.isNotEmpty) return (slots.toList()..sort());

    return ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
  }

  /// Fetches a worker's booking history and calculates dynamic DNA factors.
  static Future<Map<String, double>> fetchDynamicDnaFactors(String workerUid, {
    required double defaultOnTime,
    required double defaultCancellation,
    required double defaultFairness,
  }) async {
    if (Firebase.apps.isEmpty) {
      return {
        'onTime': defaultOnTime,
        'cancellation': defaultCancellation,
        'fairness': defaultFairness,
        'completion': 1.0,
      };
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('provider_id', isEqualTo: workerUid)
          .get();

      if (snap.docs.isEmpty) {
        return {
          'onTime': defaultOnTime,
          'cancellation': 0.0,
          'fairness': 1.0,
          'completion': 1.0,
        };
      }

      final docs = snap.docs;
      final total = docs.length;

      // 1. Cancellation Rate
      final cancelled = docs.where((d) => d.data()['status'] == 'cancelled').length;
      final cancellationRate = cancelled / total;

      // 2. Completion Rate
      final completed = docs.where((d) => d.data()['status'] == 'completed').length;
      final completionRate = completed / total;

      // 3. Price Fairness Score (variance in negotiation)
      double sumFairness = 0.0;
      int fairnessCount = 0;
      for (final doc in docs) {
        final data = doc.data();
        final quoted = (data['quoted_price_pkr'] as num?)?.toDouble() ?? 0.0;
        final finalPrice = (data['final_price_pkr'] as num?)?.toDouble() ?? 0.0;
        if (quoted > 0) {
          final diff = (finalPrice - quoted).abs();
          final variance = diff / quoted;
          sumFairness += (1.0 - variance).clamp(0.0, 1.0);
          fairnessCount++;
        }
      }
      final priceFairnessScore = fairnessCount > 0 ? (sumFairness / fairnessCount) : defaultFairness;

      // 4. On-Time Rate: correlated with average ratings in this simulation
      double sumRatings = 0.0;
      int ratedCount = 0;
      for (final doc in docs) {
        final rating = (doc.data()['user_rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          sumRatings += rating;
          ratedCount++;
        }
      }
      final avgRating = ratedCount > 0 ? (sumRatings / ratedCount) : 5.0;
      final onTimeRate = (avgRating / 5.0).clamp(0.7, 1.0);

      return {
        'onTime': onTimeRate,
        'cancellation': cancellationRate,
        'fairness': priceFairnessScore,
        'completion': completionRate,
      };
    } catch (_) {
      return {
        'onTime': defaultOnTime,
        'cancellation': defaultCancellation,
        'fairness': defaultFairness,
        'completion': 1.0,
      };
    }
  }
}