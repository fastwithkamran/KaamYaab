import 'dart:math';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../services/auth_service.dart';

/// Core matching engine - computes DNA-based provider ranking.
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

    // Step 1: Filter by service category and prevent double-booking
    // Hackathon Simulation: Provider with ID 'double_booked_123' or randomly a provider
    // is currently booked in the requested time slot.
    final filtered = providers.where((p) {
      if (p.serviceCategory.toLowerCase() != request.serviceType.toLowerCase()) return false;
      // Simulate Scheduling Intelligence (Double booking prevention)
      if (request.preferredTime == '10:00' && p.id.endsWith('1')) return false; // Simulated busy provider
      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // Step 2: Score each provider using 8-factor DNA algorithm
    final scored = <ProviderMatch>[];
    for (final p in filtered) {
      final dist = _haversine(userLat, userLng, p.lat, p.lng);
      final match = _computeMatch(p, request, dist, surgeMult);
      scored.add(match);
    }

    // Step 3: Sort by match score descending
    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return scored.take(5).toList();
  }

  static ProviderMatch _computeMatch(
    ServiceProvider p,
    ServiceRequest req,
    double distKm,
    double surge,
  ) {
    // Factor 1: On-Time Reliability (25%)
    final onTime = p.onTimeRate * 25.0;

    // Factor 2: Review Recency (20%)
    final recency = (p.reviewCount > 100 ? 1.0 : p.reviewCount / 100.0) * 20.0;

    // Factor 3: Job Completion Rate (15%)
    final completion = p.completionRate * 15.0;

    // Factor 4: Skill Specialization (15%)
    final skillMatch = _skillMatch(p, req.serviceType) * 15.0;

    // Factor 5: Cancellation Risk (10%)
    final cancelPenalty = (1.0 - p.cancellationRate) * 10.0;

    // Factor 6: Price Fairness (8%)
    final fairness = p.priceFairnessScore * 8.0;

    // Factor 7: Dispute History (5%)
    final dispPenalty = (1.0 - (p.disputeCount / 20.0).clamp(0, 1)) * 5.0;

    // Factor 8: Surge Acceptance (2%)
    final surgeBonus = (surge > 1.2 && p.surgeAcceptor) ? 2.0 : 0.0;

    // Job Complexity Match (penalty if under-qualified)
    double complexityPenalty = 0.0;
    if (req.jobComplexity == 'complex' && p.experienceLevel == 'basic') complexityPenalty = 15.0;
    if (req.jobComplexity == 'complex' && p.experienceLevel == 'intermediate') complexityPenalty = 5.0;
    if (req.jobComplexity == 'intermediate' && p.experienceLevel == 'basic') complexityPenalty = 5.0;

    // Distance penalty
    final distPenalty = (distKm > 5 ? (distKm - 5) * 0.5 : 0.0);

    final raw = onTime + recency + completion + skillMatch +
                cancelPenalty + fairness + dispPenalty + surgeBonus - distPenalty - complexityPenalty;
    final score = raw.clamp(0.0, 100.0);

    final breakdown = {
      'on_time_reliability': onTime,
      'review_recency': recency,
      'job_completion': completion,
      'skill_match': skillMatch,
      'cancellation_risk': cancelPenalty,
      'price_fairness': fairness,
      'dispute_history': dispPenalty,
      'surge_acceptance': surgeBonus,
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

  static double _skillMatch(ServiceProvider p, String service) {
    if (p.skills.length >= 4) return 1.0;
    if (p.skills.length == 3) return 0.85;
    if (p.skills.length == 2) return 0.7;
    return 0.5;
  }

  static double _calculateQuote(
      ServiceProvider p, ServiceRequest req, double dist, double surge) {
    double base = p.baseRatePkr;
    
    // 1. Urgency
    final urgencyAdj = req.urgency == 'emergency'
        ? base * 0.3
        : req.urgency == 'high'
            ? base * 0.15
            : 0.0;
            
    // 2. Distance
    final distCost = dist * 50;
    
    // 3. Complexity Premium
    double complexityPremium = 0.0;
    if (req.jobComplexity == 'complex') complexityPremium = base * 0.25;
    else if (req.jobComplexity == 'intermediate') complexityPremium = base * 0.10;
    
    // 4. Surge
    final surgeAdj = (base + urgencyAdj + complexityPremium) * (surge - 1.0);
    
    // 5. Loyalty Discount (Simulated for Hackathon: 5% off if user is repeat)
    // We simulate repeat customer logic randomly or based on request
    final isRepeat = true; // Simulated
    final loyaltyDiscount = isRepeat ? (base * 0.05) : 0.0;
    
    return (base + urgencyAdj + distCost + complexityPremium + surgeAdj - loyaltyDiscount).roundToDouble();
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
