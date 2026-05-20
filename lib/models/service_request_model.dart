class ServiceRequest {
  final String id;
  final String rawInput;
  final String serviceType;
  final String location;
  final String area;
  final String urgency; // low | medium | high | emergency
  final String preferredTime;
  final String preferredDate;
  final double budgetSensitivity; // 0.0=flexible, 1.0=very_tight
  final double confidence;
  final String language; // urdu | roman_urdu | english | mixed
  final DateTime createdAt;
  final String status;
  final String jobComplexity; // basic | intermediate | complex

  const ServiceRequest({
    required this.id,
    required this.rawInput,
    required this.serviceType,
    required this.location,
    required this.area,
    required this.urgency,
    required this.preferredTime,
    required this.preferredDate,
    required this.budgetSensitivity,
    required this.confidence,
    required this.language,
    required this.createdAt,
    required this.status,
    this.jobComplexity = 'basic',
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id:                json['id'] as String,
      rawInput:          json['raw_input'] as String,
      serviceType:       json['service_type'] as String,
      location:          json['location'] as String,
      area:              json['area'] as String,
      urgency:           json['urgency'] as String,
      preferredTime:     json['preferred_time'] as String,
      preferredDate:     json['preferred_date'] as String,
      budgetSensitivity: (json['budget_sensitivity'] as num).toDouble(),
      confidence:        (json['confidence'] as num).toDouble(),
      language:          json['language'] as String,
      createdAt:         DateTime.parse(json['created_at'] as String),
      status:            json['status'] as String,
      jobComplexity:     json['job_complexity'] as String? ?? 'basic',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                 id,
    'raw_input':          rawInput,
    'service_type':       serviceType,
    'location':           location,
    'area':               area,
    'urgency':            urgency,
    'preferred_time':     preferredTime,
    'preferred_date':     preferredDate,
    'budget_sensitivity': budgetSensitivity,
    'confidence':         confidence,
    'language':           language,
    'created_at':         createdAt.toIso8601String(),
    'status':             status,
    'job_complexity':     jobComplexity,
  };

  // BUG-13 FIX: added jobComplexity to copyWith
  ServiceRequest copyWith({
    String? status,
    double? confidence,
    String? serviceType,
    String? jobComplexity, // ← was missing
  }) {
    return ServiceRequest(
      id:                id,
      rawInput:          rawInput,
      serviceType:       serviceType ?? this.serviceType,
      location:          location,
      area:              area,
      urgency:           urgency,
      preferredTime:     preferredTime,
      preferredDate:     preferredDate,
      budgetSensitivity: budgetSensitivity,
      confidence:        confidence ?? this.confidence,
      language:          language,
      createdAt:         createdAt,
      status:            status ?? this.status,
      jobComplexity:     jobComplexity ?? this.jobComplexity,
    );
  }
}