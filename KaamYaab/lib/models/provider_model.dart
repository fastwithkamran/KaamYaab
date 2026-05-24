class ServiceProvider {
  final String id;
  final String name;
  final String phone;
  final String serviceCategory;
  final List<String> skills;
  final double lat;
  final double lng;
  final String area;
  final String city;
  final int dnascore;
  final double rating;
  final int totalJobs;
  final int completedJobs;
  final double onTimeRate;
  final double cancellationRate;
  final double priceFairnessScore;
  final int disputeCount;
  final bool surgeAcceptor;
  final double baseRatePkr;
  final String experienceLevel; // basic | intermediate | complex
  final List<String> certifications;
  final List<String> availability; // ["Mon","Tue",...]
  final List<String> availableSlots; // ["09:00","10:00",...]
  final int reviewCount;
  final String profileImage;
  final bool isVerified;
  final String lastActiveDate;
  final bool isAvailable;

  const ServiceProvider({
    required this.id,
    required this.name,
    required this.phone,
    required this.serviceCategory,
    required this.skills,
    required this.lat,
    required this.lng,
    required this.area,
    required this.city,
    required this.dnascore,
    required this.rating,
    required this.totalJobs,
    required this.completedJobs,
    required this.onTimeRate,
    required this.cancellationRate,
    required this.priceFairnessScore,
    required this.disputeCount,
    required this.surgeAcceptor,
    required this.baseRatePkr,
    required this.experienceLevel,
    required this.certifications,
    required this.availability,
    required this.availableSlots,
    required this.reviewCount,
    required this.profileImage,
    required this.isVerified,
    required this.lastActiveDate,
    this.isAvailable = true,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      serviceCategory: json['service_category'] as String,
      skills: List<String>.from(json['skills'] as List),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      area: json['area'] as String,
      city: json['city'] as String,
      dnascore: json['dna_score'] as int,
      rating: (json['rating'] as num).toDouble(),
      totalJobs: json['total_jobs'] as int,
      completedJobs: json['completed_jobs'] as int,
      onTimeRate: (json['on_time_rate'] as num).toDouble(),
      cancellationRate: (json['cancellation_rate'] as num).toDouble(),
      priceFairnessScore: (json['price_fairness_score'] as num).toDouble(),
      disputeCount: json['dispute_count'] as int,
      surgeAcceptor: json['surge_acceptor'] as bool,
      baseRatePkr: (json['base_rate_pkr'] as num).toDouble(),
      experienceLevel: json['experience_level'] as String,
      certifications: List<String>.from(json['certifications'] as List),
      availability: List<String>.from(json['availability'] as List),
      availableSlots: List<String>.from(json['available_slots'] as List),
      reviewCount: json['review_count'] as int,
      profileImage: json['profile_image'] as String,
      isVerified: json['is_verified'] as bool,
      lastActiveDate: json['last_active_date'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'service_category': serviceCategory,
    'skills': skills,
    'lat': lat,
    'lng': lng,
    'area': area,
    'city': city,
    'dna_score': dnascore,
    'rating': rating,
    'total_jobs': totalJobs,
    'completed_jobs': completedJobs,
    'on_time_rate': onTimeRate,
    'cancellation_rate': cancellationRate,
    'price_fairness_score': priceFairnessScore,
    'dispute_count': disputeCount,
    'surge_acceptor': surgeAcceptor,
    'base_rate_pkr': baseRatePkr,
    'experience_level': experienceLevel,
    'certifications': certifications,
    'availability': availability,
    'available_slots': availableSlots,
    'review_count': reviewCount,
    'profile_image': profileImage,
    'is_verified': isVerified,
    'last_active_date': lastActiveDate,
    'is_available': isAvailable,
  };

  double get completionRate =>
      totalJobs > 0 ? completedJobs / totalJobs : 0.0;

  String get dnaLabel {
    if (dnascore >= 800) return 'Excellent';
    if (dnascore >= 600) return 'Good';
    if (dnascore >= 400) return 'Average';
    return 'Poor';
  }
}

class ProviderMatch {
  final ServiceProvider provider;
  final double distanceKm;
  final int etaMinutes;
  final double matchScore;       // 0.0-100.0
  final double quotePkr;
  final String recommendedSlot;
  final String rankRationale;   // Human-readable reasoning
  final Map<String, double> scoreBreakdown;

  const ProviderMatch({
    required this.provider,
    required this.distanceKm,
    required this.etaMinutes,
    required this.matchScore,
    required this.quotePkr,
    required this.recommendedSlot,
    required this.rankRationale,
    required this.scoreBreakdown,
  });

  ProviderMatch copyWith({
    ServiceProvider? provider,
    double? distanceKm,
    int? etaMinutes,
    double? matchScore,
    double? quotePkr,
    String? recommendedSlot,
    String? rankRationale,
    Map<String, double>? scoreBreakdown,
  }) {
    return ProviderMatch(
      provider: provider ?? this.provider,
      distanceKm: distanceKm ?? this.distanceKm,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      matchScore: matchScore ?? this.matchScore,
      quotePkr: quotePkr ?? this.quotePkr,
      recommendedSlot: recommendedSlot ?? this.recommendedSlot,
      rankRationale: rankRationale ?? this.rankRationale,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
    );
  }
}
