class Booking {
  final String id;
  final String requestId;
  final String providerId;
  final String providerName;
  final String serviceType;
  final String userArea;
  final String scheduledDate;
  final String scheduledTime;
  final double quotedPricePkr;
  final double finalPricePkr;
  final String status;
  // status options:
  // slot_locked | confirmed | reminder_sent | en_route | in_progress | completed | disputed | cancelled
  final List<BookingStep> steps;
  final DateTime createdAt;
  final String receiptNumber;
  final double surgeMultiplier;
  final String? negotiatedNote;
  final String? disputeReason;
  final double? userRating;
  final String? userFeedback;

  const Booking({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
    required this.userArea,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.quotedPricePkr,
    required this.finalPricePkr,
    required this.status,
    required this.steps,
    required this.createdAt,
    required this.receiptNumber,
    required this.surgeMultiplier,
    this.negotiatedNote,
    this.disputeReason,
    this.userRating,
    this.userFeedback,
  });

  Booking copyWith({
    String? status,
    List<BookingStep>? steps,
    double? userRating,
    String? userFeedback,
    String? disputeReason,
    double? finalPricePkr,
  }) {
    return Booking(
      id: id,
      requestId: requestId,
      providerId: providerId,
      providerName: providerName,
      serviceType: serviceType,
      userArea: userArea,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      quotedPricePkr: quotedPricePkr,
      finalPricePkr: finalPricePkr ?? this.finalPricePkr,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      receiptNumber: receiptNumber,
      surgeMultiplier: surgeMultiplier,
      negotiatedNote: negotiatedNote,
      disputeReason: disputeReason ?? this.disputeReason,
      userRating: userRating ?? this.userRating,
      userFeedback: userFeedback ?? this.userFeedback,
    );
  }
}

class BookingStep {
  final int stepNumber;
  final String title;
  final String description;
  final String status; // pending | active | completed | failed
  final String? timestamp;
  final String? agentNote;

  const BookingStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.status,
    this.timestamp,
    this.agentNote,
  });

  BookingStep copyWith({String? status, String? timestamp, String? agentNote}) {
    return BookingStep(
      stepNumber: stepNumber,
      title: title,
      description: description,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      agentNote: agentNote ?? this.agentNote,
    );
  }

  static List<BookingStep> initialSteps() => [
    const BookingStep(
      stepNumber: 1,
      title: 'Notifying Workers',
      description: 'Sending task details to nearby verified workers',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 2,
      title: 'Worker Acceptance',
      description: 'Waiting for worker to accept & confirm time slot',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 3,
      title: 'Deal Finalized',
      description: 'Contact details exchanged securely',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 4,
      title: 'Reminders Scheduled',
      description: 'T-24h, T-1h, T-15min alerts queued',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 5,
      title: 'En-Route Update',
      description: 'Provider en-route ping with live ETA',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 6,
      title: 'Service Completion',
      description: 'Job completion checklist & photo log',
      status: 'pending',
    ),
    const BookingStep(
      stepNumber: 7,
      title: 'Feedback & DNA Update',
      description: 'Rating collected → DNA Score updated',
      status: 'pending',
    ),
  ];
}

class PriceQuote {
  final double basePkr;
  final double urgencyAdjPkr;
  final double distanceCostPkr;
  final double surgeMultiplier;
  final double loyaltyDiscountPkr;
  final double totalPkr;
  final String breakdown;
  final bool isNegotiable;

  const PriceQuote({
    required this.basePkr,
    required this.urgencyAdjPkr,
    required this.distanceCostPkr,
    required this.surgeMultiplier,
    required this.loyaltyDiscountPkr,
    required this.totalPkr,
    required this.breakdown,
    required this.isNegotiable,
  });
}
