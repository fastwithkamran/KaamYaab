import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Types of notification a worker can receive.
enum WorkerNotifType { booking, negotiation, dispute, request }

extension WorkerNotifTypeX on WorkerNotifType {
  String get value {
    switch (this) {
      case WorkerNotifType.booking:
        return 'booking';
      case WorkerNotifType.negotiation:
        return 'negotiation';
      case WorkerNotifType.dispute:
        return 'dispute';
      case WorkerNotifType.request:
        return 'request';
    }
  }

  static WorkerNotifType fromString(String s) {
    switch (s) {
      case 'negotiation':
        return WorkerNotifType.negotiation;
      case 'dispute':
        return WorkerNotifType.dispute;
      case 'request':
        return WorkerNotifType.request;
      default:
        return WorkerNotifType.booking;
    }
  }
}

/// A single notification for a worker.
class WorkerNotification {
  final String id;
  final WorkerNotifType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> meta; // extra context (bookingId, amount, etc.)

  const WorkerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.meta = const {},
  });

  factory WorkerNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WorkerNotification(
      id: doc.id,
      type: WorkerNotifTypeX.fromString(d['type'] as String? ?? ''),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      isRead: d['is_read'] as bool? ?? false,
      createdAt:
          (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meta: d['meta'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Manages worker notifications stored in
/// `worker_notifications/{workerUid}/items/{docId}`.
class WorkerNotificationService {
  WorkerNotificationService._();
  static final WorkerNotificationService _i = WorkerNotificationService._();
  factory WorkerNotificationService() => _i;

  FirebaseFirestore? get _db =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? _col(String workerUid) {
    if (workerUid.trim().isEmpty) return null;
    return _db?.collection('worker_notifications').doc(workerUid).collection('items');
  }

  // ── Write helpers ───────────────────────────────────────────────────────────

  /// Called by BookingFlowScreen right after a booking is persisted.
  Future<void> notifyBookingConfirmed({
    required String workerUid,
    required String customerName,
    required String serviceType,
    required String scheduledDate,
    required String scheduledTime,
    required double finalPricePkr,
    required String receiptNumber,
  }) async {
    await _col(workerUid)?.add({
      'type': WorkerNotifType.booking.value,
      'title': '🎉 New Booking Confirmed!',
      'body':
          '$customerName booked you for $serviceType on $scheduledDate at $scheduledTime — Rs.${finalPricePkr.toInt()}. Receipt: $receiptNumber',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'receipt_number': receiptNumber,
        'final_price_pkr': finalPricePkr,
        'service_type': serviceType,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
      },
    });
  }

  /// Called when a customer submits a price counter-offer.
  Future<String?> notifyNegotiationRequest({
    required String workerUid,
    required String customerUid,
    required String customerName,
    required String serviceType,
    required double originalPrice,
    required double offerPrice,
    required String requestId,
    String? receiptNumber,
  }) async {
    final doc = await _col(workerUid)?.add({
      'type': WorkerNotifType.negotiation.value,
      'title': '💬 Price Negotiation Request',
      'body':
          '$customerName wants to negotiate for $serviceType. '
          'Original: Rs.${originalPrice.toInt()} → Offer: Rs.${offerPrice.toInt()}',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'customer_uid': customerUid,
        'customer_name': customerName,
        'original_price_pkr': originalPrice,
        'offer_price_pkr': offerPrice,
        'service_type': serviceType,
        'request_id': requestId,
        'receipt_number': receiptNumber,
        'status': 'pending', // pending, accepted, rejected, countered
        'counter_offer_pkr': null,
      },
    });
    return doc?.id;
  }

  /// Mark a negotiation as accepted, rejected or countered.
  Future<void> updateNegotiationStatus(
    String workerUid, 
    String notifId, 
    String status, 
    {double? counterOffer}
  ) async {
    await _col(workerUid)?.doc(notifId).update({
      'meta.status': status,
      'meta.counter_offer_pkr': counterOffer,
      'is_read': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Called when a customer files a dispute referencing this worker.
  Future<void> notifyDisputeFiled({
    required String workerUid,
    required String customerName,
    required String serviceType,
    required String reason,
    String? receiptNumber,
  }) async {
    await _col(workerUid)?.add({
      'type': WorkerNotifType.dispute.value,
      'title': '⚠️ Dispute Filed Against You',
      'body':
          '$customerName filed a dispute for $serviceType. '
          'Reason: $reason. Our team will review within 24 hours.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'service_type': serviceType,
        'reason': reason,
        'receipt_number': receiptNumber,
      },
    });
  }

  /// Called by the agent when a customer selects a worker.
  /// The worker must confirm they can work with the given requirements.
  Future<String?> notifyBookingRequest({
    required String workerUid,
    required String customerUid,
    required String customerName,
    required String serviceType,
    required String scheduledDate,
    required String scheduledTime,
    required double offeredPricePkr,
    required String requestId,
    required String jobDescription,
    required String urgency,
  }) async {
    final doc = await _col(workerUid)?.add({
      'type': WorkerNotifType.request.value,
      'title': '📋 New Project Proposal',
      'body':
          '$customerName has a new project proposal for $serviceType. '
          'They are offering Rs.${offeredPricePkr.toInt()} for $scheduledDate at $scheduledTime. '
          'Urgency: ${urgency.toUpperCase()}. Please review the details below and approve to proceed.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'customer_uid': customerUid,
        'customer_name': customerName,
        'service_type': serviceType,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'offered_price_pkr': offeredPricePkr,
        'request_id': requestId,
        'job_description': jobDescription,
        'urgency': urgency,
        'status': 'pending', // pending, accepted, rejected
      },
    });
    return doc?.id;
  }

  /// Mark a request as accepted or rejected.
  Future<void> updateRequestStatus(String workerUid, String notifId, String status) async {
    await _col(workerUid)?.doc(notifId).update({
      'meta.status': status,
      'is_read': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Listen to a specific notification document for status changes.
  Stream<WorkerNotification?> watchNotification(String workerUid, String notifId) {
    final col = _col(workerUid);
    if (col == null) return Stream.value(null);
    return col.doc(notifId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return WorkerNotification.fromDoc(doc);
    });
  }

  // ── Read helpers ────────────────────────────────────────────────────────────

  /// Live stream of all notifications for a worker, newest first.
  Stream<List<WorkerNotification>> watchNotifications(String workerUid) {
    final col = _col(workerUid);
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WorkerNotification.fromDoc).toList());
  }

  /// Count of unread notifications.
  Stream<int> watchUnreadCount(String workerUid) {
    final col = _col(workerUid);
    if (col == null) return Stream.value(0);
    return col
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Mark a single notification as read.
  Future<void> markRead(String workerUid, String notifId) async {
    await _col(workerUid)?.doc(notifId).update({'is_read': true});
  }

  /// Mark all notifications as read.
  Future<void> markAllRead(String workerUid) async {
    final col = _col(workerUid);
    if (col == null) return;
    final db = _db;
    if (db == null) return;
    final unread = await col.where('is_read', isEqualTo: false).get();
    final batch = db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
