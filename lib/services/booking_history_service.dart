import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';

/// Persists customer booking history in Firestore for end-to-end visibility.
class BookingHistoryService {
  BookingHistoryService._();
  static final BookingHistoryService _instance = BookingHistoryService._();
  factory BookingHistoryService() => _instance;

  /// Lazy Firestore accessor — only available when Firebase is initialised.
  FirebaseFirestore? get _db =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  Future<void> saveCompletedBooking({
    required String requestId,
    required String providerId,
    required String providerName,
    required String serviceType,
    required String userArea,
    required String scheduledDate,
    required String scheduledTime,
    required double quotedPricePkr,
    required double finalPricePkr,
    required String status,
    required String receiptNumber,
    required double surgeMultiplier,
    String? negotiatedNote,
  }) async {
    if (!_isFirebaseReady) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    await _db!.collection('bookings').add({
      'customer_uid': user.uid,
      'customer_phone': user.phone,
      'request_id': requestId,
      'provider_id': providerId,
      'provider_name': providerName,
      'service_type': serviceType,
      'user_area': userArea,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'quoted_price_pkr': quotedPricePkr,
      'final_price_pkr': finalPricePkr,
      'status': status,
      'receipt_number': receiptNumber,
      'surge_multiplier': surgeMultiplier,
      'negotiated_note': negotiatedNote,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchCurrentUserBookings() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _db!
        .collection('bookings')
        .where('customer_uid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      items.sort((a, b) {
        final aDate = _toDateTime(a['created_at']);
        final bDate = _toDateTime(b['created_at']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  /// Updates booking with user rating and feedback text after service completion.
  Future<void> updateFeedback({
    required String requestId,
    required double rating,
    required String feedback,
  }) async {
    if (!_isFirebaseReady) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    final query = await _db!
        .collection('bookings')
        .where('customer_uid', isEqualTo: user.uid)
        .where('request_id', isEqualTo: requestId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'user_rating': rating,
        'user_feedback': feedback,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Stream of completed bookings where this worker was the provider.
  Stream<List<Map<String, dynamic>>> watchWorkerBookings() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) return Stream.value(const []);
    return _db!
        .collection('bookings')
        .where('provider_id', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList()
        ..sort((a, b) {
          final aD = _toDateTime(a['created_at']);
          final bD = _toDateTime(b['created_at']);
          if (aD == null && bD == null) return 0;
          if (aD == null) return 1;
          if (bD == null) return -1;
          return bD.compareTo(aD);
        });
      return items;
    });
  }

  /// Stream of reviews (bookings with user_rating set) left for this worker.
  Stream<List<Map<String, dynamic>>> watchWorkerReviews() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) return Stream.value(const []);
    return _db!
        .collection('bookings')
        .where('provider_id', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .where((d) => d.data()['user_rating'] != null)
          .map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          })
          .toList()
        ..sort((a, b) {
          final aD = _toDateTime(a['updated_at'] ?? a['created_at']);
          final bD = _toDateTime(b['updated_at'] ?? b['created_at']);
          if (aD == null && bD == null) return 0;
          if (aD == null) return 1;
          if (bD == null) return -1;
          return bD.compareTo(aD);
        });
      return items;
    });
  }
}
