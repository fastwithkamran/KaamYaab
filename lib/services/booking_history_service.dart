import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';

/// Persists customer booking history in Firestore.
class BookingHistoryService {
  BookingHistoryService._();
  static final BookingHistoryService _instance = BookingHistoryService._();
  factory BookingHistoryService() => _instance;

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
      // user_rating intentionally omitted at booking creation — set via updateFeedback.
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> createPendingBooking({
    required String requestId,
    required String providerId,
    required String providerName,
    required String serviceType,
    required String userArea,
    required String scheduledDate,
    required String scheduledTime,
    required double quotedPricePkr,
    required double finalPricePkr,
    required double surgeMultiplier,
  }) async {
    if (!_isFirebaseReady) return null;
    final user = AuthService().currentUser;
    if (user == null) return null;

    final docRef = await _db!.collection('bookings').add({
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
      'status': 'awaiting_approval',
      'receipt_number': 'KY-PENDING',
      'surge_multiplier': surgeMultiplier,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus, {String? receiptNumber, double? finalPrice}) async {
    if (!_isFirebaseReady) return;
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (receiptNumber != null) updates['receipt_number'] = receiptNumber;
    if (finalPrice != null) updates['final_price_pkr'] = finalPrice;

    await _db!.collection('bookings').doc(bookingId).update(updates);
  }

  Future<void> updateBookingTime(String bookingId, String newTime, String newStatus) async {
    if (!_isFirebaseReady) return;
    await _db!.collection('bookings').doc(bookingId).update({
      'scheduled_time': newTime,
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of the current customer's bookings, newest first.
  Stream<List<Map<String, dynamic>>> watchCurrentUserBookings() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) return Stream.value(const []);

    return _db!
        .collection('bookings')
        .where('customer_uid', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

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

    if (query.docs.isEmpty) return;

    final bookingDoc = query.docs.first;
    await bookingDoc.reference.update({
      'user_rating': rating,
      'user_feedback': feedback,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // ── Propagate rating to the worker's local AppUser profile ─────────────────
    // Read provider_id from the booking we just updated, then aggregate all
    // rated bookings for that provider to compute an accurate new average.
    final providerId =
        bookingDoc.data()['provider_id'] as String?;
    if (providerId != null && providerId.isNotEmpty) {
      try {
        final ratedSnap = await _db!
            .collection('bookings')
            .where('provider_id', isEqualTo: providerId)
            .where('user_rating', isGreaterThan: 0)
            .get();

        if (ratedSnap.docs.isNotEmpty) {
          final ratings = ratedSnap.docs
              .map((d) =>
                  (d.data()['user_rating'] as num?)?.toDouble() ?? 0.0)
              .toList();
          final avgRating =
              ratings.fold(0.0, (a, b) => a + b) / ratings.length;
          await AuthService().updateWorkerRating(
            workerUid: providerId,
            newRating: double.parse(avgRating.toStringAsFixed(2)),
            newTotalJobs: ratedSnap.docs.length,
          );
        }
      } catch (_) {
        // Non-fatal — local profile update is best-effort.
      }
    }
  }

  /// Live stream of all bookings where this worker was the provider, newest first.
  Stream<List<Map<String, dynamic>>> watchWorkerBookings() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) return Stream.value(const []);

    return _db!
        .collection('bookings')
        .where('provider_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Live stream of reviews (bookings with a user_rating) left for this worker.
  ///
  /// Uses a server-side [isGreaterThan] filter instead of client-side filtering
  /// so Firestore only transmits documents that actually have a rating set.
  /// Requires a composite index on (provider_id ASC, user_rating ASC, updated_at DESC)
  /// — add it via the Firebase Console or firestore.indexes.json.
  Stream<List<Map<String, dynamic>>> watchWorkerReviews() {
    if (!_isFirebaseReady) return Stream.value(const []);
    final user = AuthService().currentUser;
    if (user == null) return Stream.value(const []);

    return _db!
        .collection('bookings')
        .where('provider_id', isEqualTo: user.uid)
        .where('user_rating', isGreaterThan: 0)
        .orderBy('user_rating') // required by Firestore when using isGreaterThan
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}