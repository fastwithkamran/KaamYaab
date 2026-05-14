import 'dart:math';
import '../config/runtime_config.dart';

/// OTP (One-Time Password) service for phone verification.
///
/// In DEMO MODE (no SMS_API_KEY set): generates OTP locally and returns it
/// so the UI can display it to the user for testing.
///
/// In PRODUCTION: integrate Twilio/Vonage/Firebase Phone Auth by replacing
/// the [sendOtp] method body.
class OtpService {
  static final OtpService _instance = OtpService._();
  factory OtpService() => _instance;
  OtpService._();

  final Map<String, _OtpRecord> _otpStore = {};

  /// Sends (or simulates) an OTP to [phone].
  /// Returns the OTP code in demo mode, or null in production.
  Future<String?> sendOtp(String phone) async {
    final code = _generateCode();
    final expiry = DateTime.now()
        .add(Duration(seconds: RuntimeConfig.otpExpirySeconds));

    _otpStore[phone] = _OtpRecord(code: code, expiry: expiry);

    if (RuntimeConfig.smsEnabled) {
      // TODO: Replace with real SMS call
      // await _sendViaTwilio(phone, code);
      return null; // Production: don't reveal OTP
    }

    // DEMO MODE: return OTP so UI can display it
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network
    return code;
  }

  /// Verifies [code] entered by user against stored OTP for [phone].
  OtpResult verify(String phone, String code) {
    final record = _otpStore[phone];
    if (record == null) return OtpResult.noRecord;
    if (DateTime.now().isAfter(record.expiry)) {
      _otpStore.remove(phone);
      return OtpResult.expired;
    }
    if (record.code != code) return OtpResult.invalid;
    _otpStore.remove(phone);
    return OtpResult.verified;
  }

  /// Clears any stored OTP for [phone] (e.g., on cancel).
  void clear(String phone) => _otpStore.remove(phone);

  String _generateCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }
}

class _OtpRecord {
  final String code;
  final DateTime expiry;
  const _OtpRecord({required this.code, required this.expiry});
}

enum OtpResult { verified, invalid, expired, noRecord }
