enum UserRole { customer, worker }

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String cnic;
  final String city;
  final String area;
  final UserRole role;
  final DateTime createdAt;

  // Worker-specific fields
  final String? serviceCategory;   // e.g. "Plumber"
  final String? subRole;           // e.g. "Emergency Plumber"
  final List<String>? skills;
  final double? baseRatePkr;       // Standard hourly/job rate
  final double? minRatePkr;        // Negotiation floor — will NOT go below this
  final double? maxRatePkr;        // Premium / complex-job rate ceiling
  final String? negotiationStyle;  // "flexible" | "moderate" | "firm"
  final int? experienceYears;
  final bool isAvailable;
  final double rating;
  final int totalJobs;
  final String? bio;
  final String? profileImageBase64; // Base64 encoded profile photo

  // Map locations & availability
  final double? latitude;
  final double? longitude;
  final List<String>? availabilityRules;

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.cnic,
    required this.city,
    required this.area,
    required this.role,
    required this.createdAt,
    this.serviceCategory,
    this.subRole,
    this.skills,
    this.baseRatePkr,
    this.minRatePkr,
    this.maxRatePkr,
    this.negotiationStyle = 'moderate',
    this.experienceYears,
    this.isAvailable = true,
    this.rating = 0.0,
    this.totalJobs = 0,
    this.bio,
    this.profileImageBase64,
    this.latitude,
    this.longitude,
    this.availabilityRules,
  });

  bool get isWorker => role == UserRole.worker;
  bool get isCustomer => role == UserRole.customer;
  bool get hasProfileImage =>
      profileImageBase64 != null && profileImageBase64!.isNotEmpty;

  /// True only when ALL mandatory worker profile fields are filled.
  bool get isProfileComplete =>
      isWorker &&
      serviceCategory != null &&
      serviceCategory!.isNotEmpty &&
      serviceCategory != 'Unassigned' &&
      skills != null &&
      skills!.isNotEmpty &&
      baseRatePkr != null &&
      minRatePkr != null &&
      availabilityRules != null &&
      availabilityRules!.isNotEmpty;

  /// The effective negotiation floor. Falls back to 80 % of base rate.
  double get effectiveMinRate {
    if (minRatePkr != null && minRatePkr! > 0) return minRatePkr!;
    if (baseRatePkr != null && baseRatePkr! > 0) return baseRatePkr! * 0.80;
    return 0;
  }

  String get roleLabel => role == UserRole.worker ? 'Worker' : 'Customer';
  String get skillsDisplay => skills?.join(', ') ?? '';
  String get rateDisplay =>
      baseRatePkr != null ? 'Rs. ${baseRatePkr!.toInt()}/hr' : '';
  String get displayRole => subRole ?? serviceCategory ?? '';
  String get starDisplay {
    if (totalJobs == 0) return 'New';
    final stars = rating.round(); // rating is already 0–5
    return '⭐' * stars.clamp(0, 5);
  }

  int get dnaScore {
    double score = 500.0;
    score += (rating / 5.0) * 200;
    score += (totalJobs.clamp(0, 300) / 300.0) * 150;
    final years = (experienceYears ?? 0).clamp(0, 10);
    score += (years / 10.0) * 150;
    return score.round().clamp(100, 1000);
  }

  String get dnaLabel {
    final score = dnaScore;
    if (score >= 800) return 'Excellent';
    if (score >= 600) return 'Good';
    if (score >= 400) return 'Average';
    return 'Poor';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      cnic: json['cnic'] as String? ?? '',
      city: json['city'] as String? ?? '',
      area: json['area'] as String? ?? '',
      role: json['role'] == 'worker' ? UserRole.worker : UserRole.customer,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      serviceCategory: json['service_category'] as String?,
      subRole: json['sub_role'] as String?,
      skills: json['skills'] != null
          ? List<String>.from(json['skills'] as List)
          : null,
      baseRatePkr: (json['base_rate_pkr'] as num?)?.toDouble(),
      minRatePkr: (json['min_rate_pkr'] as num?)?.toDouble(),
      maxRatePkr: (json['max_rate_pkr'] as num?)?.toDouble(),
      negotiationStyle:
          json['negotiation_style'] as String? ?? 'moderate',
      experienceYears: json['experience_years'] as int?,
      isAvailable: json['is_available'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobs: json['total_jobs'] as int? ?? 0,
      bio: json['bio'] as String?,
      profileImageBase64: json['profile_image'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      availabilityRules: json['availability_rules'] != null
          ? List<String>.from(json['availability_rules'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'cnic': cnic,
        'city': city,
        'area': area,
        'role': role == UserRole.worker ? 'worker' : 'customer',
        'created_at': createdAt.toIso8601String(),
        'service_category': serviceCategory,
        'sub_role': subRole,
        'skills': skills,
        'base_rate_pkr': baseRatePkr,
        'min_rate_pkr': minRatePkr,
        'max_rate_pkr': maxRatePkr,
        'negotiation_style': negotiationStyle,
        'experience_years': experienceYears,
        'is_available': isAvailable,
        'rating': rating,
        'total_jobs': totalJobs,
        'bio': bio,
        'profile_image': profileImageBase64,
        'latitude': latitude,
        'longitude': longitude,
        'availability_rules': availabilityRules,
      };

  AppUser copyWith({
    String? uid,
    String? name,
    String? phone,
    String? cnic,
    String? city,
    String? area,
    String? serviceCategory,
    String? subRole,
    List<String>? skills,
    double? baseRatePkr,
    double? minRatePkr,
    double? maxRatePkr,
    String? negotiationStyle,
    int? experienceYears,
    bool? isAvailable,
    double? rating,
    int? totalJobs,
    String? bio,
    String? profileImageBase64,
    List<String>? availabilityRules,
    double? latitude,
    double? longitude,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      cnic: cnic ?? this.cnic,
      city: city ?? this.city,
      area: area ?? this.area,
      role: role,
      createdAt: createdAt,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      subRole: subRole ?? this.subRole,
      skills: skills ?? this.skills,
      baseRatePkr: baseRatePkr ?? this.baseRatePkr,
      minRatePkr: minRatePkr ?? this.minRatePkr,
      maxRatePkr: maxRatePkr ?? this.maxRatePkr,
      negotiationStyle: negotiationStyle ?? this.negotiationStyle,
      experienceYears: experienceYears ?? this.experienceYears,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      totalJobs: totalJobs ?? this.totalJobs,
      bio: bio ?? this.bio,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      availabilityRules: availabilityRules ?? this.availabilityRules,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}