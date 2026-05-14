enum UserRole { customer, worker }

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String city;
  final String area;
  final UserRole role;
  final DateTime createdAt;

  // Worker-specific fields
  final String? serviceCategory;  // e.g. "Plumber"
  final String? subRole;          // e.g. "Emergency Plumber"
  final List<String>? skills;
  final double? baseRatePkr;
  final int? experienceYears;
  final bool isAvailable;
  final double rating;
  final int totalJobs;
  final String? bio;
  final String? profileImageBase64; // Base64 encoded profile photo

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.area,
    required this.role,
    required this.createdAt,
    this.serviceCategory,
    this.subRole,
    this.skills,
    this.baseRatePkr,
    this.experienceYears,
    this.isAvailable = true,
    this.rating = 0.0,
    this.totalJobs = 0,
    this.bio,
    this.profileImageBase64,
  });

  bool get isWorker => role == UserRole.worker;
  bool get isCustomer => role == UserRole.customer;
  bool get hasProfileImage => profileImageBase64 != null && profileImageBase64!.isNotEmpty;

  String get roleLabel => role == UserRole.worker ? 'Worker' : 'Customer';
  String get skillsDisplay => skills?.join(', ') ?? '';
  String get rateDisplay =>
      baseRatePkr != null ? 'Rs. ${baseRatePkr!.toInt()}/hr' : '';
  String get displayRole => subRole ?? serviceCategory ?? '';
  String get starDisplay {
    if (totalJobs == 0) return 'New';
    final stars = (rating / 5.0 * 5).round();
    return '⭐' * stars.clamp(0, 5);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String? ?? '',
      city: json['city'] as String,
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
      experienceYears: json['experience_years'] as int?,
      isAvailable: json['is_available'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobs: json['total_jobs'] as int? ?? 0,
      bio: json['bio'] as String?,
      profileImageBase64: json['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': email,
        'city': city,
        'area': area,
        'role': role == UserRole.worker ? 'worker' : 'customer',
        'created_at': createdAt.toIso8601String(),
        'service_category': serviceCategory,
        'sub_role': subRole,
        'skills': skills,
        'base_rate_pkr': baseRatePkr,
        'experience_years': experienceYears,
        'is_available': isAvailable,
        'rating': rating,
        'total_jobs': totalJobs,
        'bio': bio,
        'profile_image': profileImageBase64,
      };

  AppUser copyWith({
    bool? isAvailable,
    double? rating,
    int? totalJobs,
    String? profileImageBase64,
  }) {
    return AppUser(
      uid: uid,
      name: name,
      phone: phone,
      email: email,
      city: city,
      area: area,
      role: role,
      createdAt: createdAt,
      serviceCategory: serviceCategory,
      subRole: subRole,
      skills: skills,
      baseRatePkr: baseRatePkr,
      experienceYears: experienceYears,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      totalJobs: totalJobs ?? this.totalJobs,
      bio: bio,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
    );
  }
}
