import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../config/runtime_config.dart';

/// OTP (One-Time Password) service for phone verification.
///
/// Uses Firebase Phone Auth when available. Falls back to in-app simulation
/// when Firebase OTP is unavailable (e.g. web builds / emulator).
///
/// Security note: [OtpSendResult.demoCode] is only populated in debug builds.
/// In release builds the field is always null so the raw OTP code never
/// travels through the app layer.
class OtpService {
  static final OtpService _instance = OtpService._();
  factory OtpService() => _instance;
  OtpService._();

  static const int _minE164Digits = 10;
  static const int _maxE164Digits = 15;
  static const int _localPhoneDigits = 11;

  final Map<String, _OtpRecord> _otpStore = {};
  final Map<String, _FirebaseOtpSession> _firebaseStore = {};
  final Set<String> _autoVerifiedPhones = {};
  bool _isSendingOtp = false;

  /// Sends an OTP to [phone].
  /// Returns immediately with an error if a send is already in progress.
  Future<OtpSendResult> sendOtp(String phone) async {
    if (_isSendingOtp) {
      return const OtpSendResult.error(
          'OTP already being sent. Please wait a moment.');
    }
    _isSendingOtp = true;
    try {
      return await _doSendOtp(phone);
    } finally {
      _isSendingOtp = false;
    }
  }

  Future<OtpSendResult> _doSendOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) {
      return const OtpSendResult.error(
        'Invalid phone number format. Please check and try again.',
      );
    }

    _autoVerifiedPhones.remove(normalized);

    if (!_canUseFirebaseOtp) {
      return await _sendMockOtpResult(normalized);
    }

    final completer = Completer<OtpSendResult>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: Duration(
            seconds: RuntimeConfig.otpAutoRetrievalTimeoutSeconds),
        verificationCompleted: (credential) async {
          _autoVerifiedPhones.add(normalized);
          if (!completer.isCompleted) {
            completer.complete(const OtpSendResult.successReal());
          }
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.complete(
              OtpSendResult.error(_firebaseErrorToMessage(e)),
            );
          }
        },
        codeSent: (verificationId, resendToken) {
          _firebaseStore[normalized] = _FirebaseOtpSession(
            verificationId: verificationId,
            expiry: DateTime.now()
                .add(Duration(seconds: RuntimeConfig.otpExpirySeconds)),
            resendToken: resendToken,
          );
          if (!completer.isCompleted) {
            completer.complete(const OtpSendResult.successReal());
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          final current = _firebaseStore[normalized];
          if (current != null) {
            _firebaseStore[normalized] =
                current.copyWith(verificationId: verificationId);
          }
        },
      );

      final sent = await completer.future.timeout(
        Duration(seconds: RuntimeConfig.otpSendTimeoutSeconds),
        onTimeout: () => const OtpSendResult.error(
          'Could not send OTP right now. Please try again.',
        ),
      );

      if (!sent.success) {
        return await _fallbackResult(
            sent.errorMessage ?? 'Could not send OTP.', normalized);
      }

      return sent;
    } catch (_) {
      return await _fallbackResult('Could not send OTP right now.', normalized);
    }
  }

  Future<OtpSendResult> _fallbackResult(
      String message, String normalized) async {
    final mockResult = await _sendMockOtpResult(normalized);
    // Carry the original error message but keep the mock code (debug-only).
    return OtpSendResult.error(message,
        fallbackCode: mockResult.demoCode);
  }

  /// Stores a mock OTP and returns a result.
  /// [demoCode] is only set in debug builds — never in release.
  Future<OtpSendResult> _sendMockOtpResult(String phone) async {
    final code = _generateCode();
    _otpStore[phone] = _OtpRecord(
      code: code,
      expiry: DateTime.now()
          .add(Duration(seconds: RuntimeConfig.otpExpirySeconds)),
    );
    await Future.delayed(const Duration(milliseconds: 800));
    // In release builds, never expose the raw code through the result object.
    return OtpSendResult.successMock(kDebugMode ? code : null);
  }

  /// Verifies [code] entered by the user against the stored OTP for [phone].
  Future<OtpResult> verify(String phone, String code) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) return OtpResult.noRecord;

    if (_autoVerifiedPhones.remove(normalized)) {
      _firebaseStore.remove(normalized);
      _otpStore.remove(normalized);
      return OtpResult.verified;
    }

    if (_canUseFirebaseOtp) {
      final session = _firebaseStore[normalized];
      if (session != null) {
        if (DateTime.now().isAfter(session.expiry)) {
          _firebaseStore.remove(normalized);
          return OtpResult.expired;
        }
        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: session.verificationId,
            smsCode: code,
          );
          // Intentional signIn → signOut pattern: signInWithCredential validates
          // the SMS code server-side. The immediate signOut removes the transient
          // Firebase session because app auth is managed entirely by AuthService
          // via SharedPreferences, not by FirebaseAuth.
          await FirebaseAuth.instance.signInWithCredential(credential);
          await FirebaseAuth.instance.signOut();
          _firebaseStore.remove(normalized);
          return OtpResult.verified;
        } on FirebaseAuthException catch (e) {
          return e.code == 'session-expired'
              ? OtpResult.expired
              : OtpResult.invalid;
        } catch (_) {
          return OtpResult.invalid;
        }
      }
    }

    final record = _otpStore[normalized];
    if (record == null) return OtpResult.noRecord;
    if (DateTime.now().isAfter(record.expiry)) {
      _otpStore.remove(normalized);
      return OtpResult.expired;
    }
    if (record.code != code) return OtpResult.invalid;
    _otpStore.remove(normalized);
    return OtpResult.verified;
  }

  /// Clears any stored OTP for [phone] (e.g. on cancel).
  void clear(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized == null) return;
    _otpStore.remove(normalized);
    _firebaseStore.remove(normalized);
    _autoVerifiedPhones.remove(normalized);
  }

  String _generateCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  bool get _canUseFirebaseOtp => !kIsWeb && Firebase.apps.isNotEmpty;

  String? _normalizePhone(String phone) {
    final raw = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return _isValidE164Digits(digits) ? '+$digits' : null;
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length == _localPhoneDigits) {
      return '+${RuntimeConfig.defaultCountryDialCode}${digits.substring(1)}';
    }
    if (digits.startsWith(RuntimeConfig.defaultCountryDialCode) &&
        _isValidE164Digits(digits)) {
      return '+$digits';
    }
    return null;
  }

  bool _isValidE164Digits(String digits) =>
      digits.length >= _minE164Digits && digits.length <= _maxE164Digits;

  String _firebaseErrorToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'too-many-requests':
        return 'Too many OTP attempts. Please wait and try again.';
      case 'quota-exceeded':
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return 'Could not send OTP right now. Please try again.';
    }
  }
}

// ── Internal models ────────────────────────────────────────────────────────

class _OtpRecord {
  final String code;
  final DateTime expiry;
  const _OtpRecord({required this.code, required this.expiry});
}

class _FirebaseOtpSession {
  final String verificationId;
  final DateTime expiry;
  final int? resendToken;

  const _FirebaseOtpSession({
    required this.verificationId,
    required this.expiry,
    required this.resendToken,
  });

  _FirebaseOtpSession copyWith({
    String? verificationId,
    DateTime? expiry,
    int? resendToken,
  }) =>
      _FirebaseOtpSession(
        verificationId: verificationId ?? this.verificationId,
        expiry: expiry ?? this.expiry,
        resendToken: resendToken ?? this.resendToken,
      );
}

// ── Result types ───────────────────────────────────────────────────────────

class OtpSendResult {
  final bool success;
  final bool isMock;

  /// Raw OTP code — only populated in debug builds. Always null in release.
  final String? demoCode;
  final String? errorMessage;

  const OtpSendResult._({
    required this.success,
    required this.isMock,
    this.demoCode,
    this.errorMessage,
  });

  const OtpSendResult.successReal()
      : this._(success: true, isMock: false);

  /// [code] is null in release builds (see [OtpService._sendMockOtpResult]).
  factory OtpSendResult.successMock(String? code) => OtpSendResult._(
        success: true,
        isMock: true,
        demoCode: code,
      );

  const OtpSendResult.error(String message, {String? fallbackCode})
      : this._(
          success: false,
          isMock: fallbackCode != null,
          demoCode: fallbackCode,
          errorMessage: message,
        );

  bool get hasFatalError => !success && demoCode == null;
}

enum OtpResult { verified, invalid, expired, noRecord }