import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Types of notification a customer can receive.
enum CustomerNotifType { enRoute, arrived, completed, counterOffer }

extension CustomerNotifTypeX on CustomerNotifType {
  String get value {
    switch (this) {
      case CustomerNotifType.enRoute:
        return 'en_route';
      case CustomerNotifType.arrived:
        return 'arrived';
      case CustomerNotifType.completed:
        return 'completed';
      case CustomerNotifType.counterOffer:
        return 'counter_offer';
    }
  }

  static CustomerNotifType fromString(String s) {
    switch (s) {
      case 'arrived':
        return CustomerNotifType.arrived;
      case 'completed':
        return CustomerNotifType.completed;
      case 'counter_offer':
        return CustomerNotifType.counterOffer;
      default:
        return CustomerNotifType.enRoute;
    }
  }
}

/// A single notification for a customer.
class CustomerNotification {
  final String id;
  final CustomerNotifType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> meta; // extra context (bookingId, amount, etc.)

  const CustomerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.meta = const {},
  });

  factory CustomerNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CustomerNotification(
      id: doc.id,
      type: CustomerNotifTypeX.fromString(d['type'] as String? ?? ''),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      isRead: d['is_read'] as bool? ?? false,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meta: d['meta'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Manages customer notifications stored in
/// `customer_notifications/{customerUid}/items/{docId}`.
class CustomerNotificationService {
  CustomerNotificationService._();
  static final CustomerNotificationService _i = CustomerNotificationService._();
  factory CustomerNotificationService() => _i;

  FirebaseFirestore? get _db =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? _col(String customerUid) {
    if (customerUid.trim().isEmpty) return null;
    return _db?.collection('customer_notifications').doc(customerUid).collection('items');
  }

  // ── Write helpers ───────────────────────────────────────────────────────────

  /// Triggered when the worker marks status as en-route.
  Future<void> notifyWorkerEnRoute({
    required String customerUid,
    required String workerName,
    required String serviceType,
    required int etaMinutes,
  }) async {
    await _col(customerUid)?.add({
      'type': CustomerNotifType.enRoute.value,
      'title': '🚗 Worker is on the way!',
      'body': '$workerName is heading to your location for $serviceType. ETA: $etaMinutes minutes.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'worker_name': workerName,
        'service_type': serviceType,
        'eta_minutes': etaMinutes,
      },
    });
  }

  /// Triggered when the worker marks status as arrived.
  Future<void> notifyWorkerArrived({
    required String customerUid,
    required String workerName,
    required String serviceType,
  }) async {
    await _col(customerUid)?.add({
      'type': CustomerNotifType.arrived.value,
      'title': '🔔 Worker Arrived!',
      'body': '$workerName has arrived at your location for $serviceType.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'worker_name': workerName,
        'service_type': serviceType,
      },
    });
  }

  /// Triggered when the worker completes a job.
  Future<void> notifyWorkerCompleted({
    required String customerUid,
    required String workerName,
    required String serviceType,
    required double finalPrice,
  }) async {
    await _col(customerUid)?.add({
      'type': CustomerNotifType.completed.value,
      'title': '🎉 Job Completed!',
      'body': '$workerName has completed $serviceType successfully. Final amount paid: Rs. ${finalPrice.toInt()}.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'worker_name': workerName,
        'service_type': serviceType,
        'final_price': finalPrice,
      },
    });
  }

  /// Triggered when worker sends counter offer.
  Future<void> notifyWorkerCounterOffer({
    required String customerUid,
    required String workerName,
    required String serviceType,
    required double counterOffer,
  }) async {
    await _col(customerUid)?.add({
      'type': CustomerNotifType.counterOffer.value,
      'title': '💬 New Price Counter-Offer',
      'body': '$workerName has counter-offered Rs. ${counterOffer.toInt()} for $serviceType.',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'meta': {
        'worker_name': workerName,
        'service_type': serviceType,
        'counter_offer': counterOffer,
      },
    });
  }

  // ── Read helpers ────────────────────────────────────────────────────────────

  /// Live stream of all notifications for a customer, newest first.
  Stream<List<CustomerNotification>> watchNotifications(String customerUid) {
    final col = _col(customerUid);
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CustomerNotification.fromDoc).toList());
  }

  /// Count of unread notifications.
  Stream<int> watchUnreadCount(String customerUid) {
    final col = _col(customerUid);
    if (col == null) return Stream.value(0);
    return col
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Mark a single notification as read.
  Future<void> markRead(String customerUid, String notifId) async {
    await _col(customerUid)?.doc(notifId).update({'is_read': true});
  }

  /// Mark all notifications as read.
  Future<void> markAllRead(String customerUid) async {
    final col = _col(customerUid);
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
