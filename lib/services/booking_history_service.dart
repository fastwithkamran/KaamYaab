import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Persists customer booking history in Firestore for end-to-end visibility.
class BookingHistoryService {
  BookingHistoryService._();
  static final BookingHistoryService _instance = BookingHistoryService._();
  factory BookingHistoryService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    final user = AuthService().currentUser;
    if (user == null) return;

    await _db.collection('bookings').add({
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
    final user = AuthService().currentUser;
    if (user == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _db
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

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
