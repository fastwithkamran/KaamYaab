import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../services/otp_service.dart';
import '../../config/runtime_config.dart';

/// OTP verification screen shown after signup to confirm phone number.
class OtpScreen extends StatefulWidget {
  final String phone;
  final String demoOtp; // Only populated in demo mode
  final Future<String?> Function() onVerified;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.demoOtp,
    required this.onVerified,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _countdown = RuntimeConfig.otpExpirySeconds;
  Timer? _timer;
  String _demoCode = '';

  @override
  void initState() {
    super.initState();
    _demoCode = widget.demoOtp;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = RuntimeConfig.otpExpirySeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  String get _enteredCode =>
      _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final result = await OtpService().verify(widget.phone, _enteredCode);

    if (!mounted) return;

    switch (result) {
      case OtpResult.verified:
        HapticFeedback.heavyImpact();
        final registerError = await widget.onVerified();
        if (!mounted) return;
        setState(() => _loading = false);
        if (registerError != null) {
          setState(() => _error = registerError);
        }
        break;
      case OtpResult.expired:
        setState(() {
          _loading = false;
          _error = 'OTP expired. Please request a new one.';
        });
        break;
      case OtpResult.invalid:
        setState(() {
          _loading = false;
          _error = 'Incorrect code. Please try again.';
        });
        _shakeInputs();
        break;
      case OtpResult.noRecord:
        setState(() {
          _loading = false;
          _error = 'Something went wrong. Please resend OTP.';
        });
        break;
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; });
    for (final c in _ctrls) { c.clear(); }
    _nodes[0].requestFocus();

    final sendResult = await OtpService().sendOtp(widget.phone);
    if (!mounted) return;
    setState(() {
      _resending = false;
      _demoCode = sendResult.demoCode ?? '';
      if (!sendResult.success && sendResult.demoCode == null) {
        _error = sendResult.errorMessage ?? 'Could not resend OTP.';
      }
    });
    if (sendResult.success || sendResult.demoCode != null) {
      _startCountdown();
    }
  }

  void _shakeInputs() {
    for (final c in _ctrls) { c.clear(); }
    _nodes[0].requestFocus();
  }

  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    if (_enteredCode.length == 6 && !_loading) {
      _verify();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phone.length > 4
        ? '${widget.phone.substring(0, widget.phone.length - 4)}****'
        : widget.phone;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                        ),

                        const SizedBox(height: 40),

                        // Icon
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.tealGlow,
                            ),
                            child: const Icon(Icons.sms_outlined, color: Colors.white, size: 36),
                          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                        ),

                        const SizedBox(height: 28),

                        Center(
                          child: Column(children: [
                            const Text('Verify Your Number',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                              'We sent a 6-digit code to\n$maskedPhone',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ]),
                        ).animate().fadeIn(delay: 200.ms),

                        // Demo mode banner
                        if (_demoCode.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppTheme.goldAccent.withValues(alpha: 0.15),
                                AppTheme.goldAccent.withValues(alpha: 0.05),
                              ]),
                              borderRadius: AppTheme.radiusMd,
                              border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
                            ),
                            child: Row(children: [
                              const Text('⚡', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Demo Mode — Your OTP',
                                      style: TextStyle(color: AppTheme.goldAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(_demoCode,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 22,
                                          fontWeight: FontWeight.w800, letterSpacing: 6)),
                                   const Text('(In-app OTP simulation active)',
                                       style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ]),
                              ),
                            ]),
                          ).animate().fadeIn(delay: 300.ms),
                        ],

                        const SizedBox(height: 36),

                        // OTP digit inputs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (i) => _DigitBox(
                            controller: _ctrls[i],
                            focusNode: _nodes[i],
                            onChanged: (v) => _onDigitEntered(i, v),
                            hasError: _error != null,
                          )),
                        ).animate().fadeIn(delay: 400.ms),

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(_error!,
                                style: const TextStyle(color: AppTheme.redError, fontSize: 13),
                                textAlign: TextAlign.center),
                          ).animate().shake(duration: 400.ms),
                        ],

                        const SizedBox(height: 28),

                        // Verify button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.tealPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Verify & Continue',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Countdown + resend
                        Center(
                          child: _countdown > 0
                              ? Text('Resend code in ${_countdown}s',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))
                              : TextButton(
                                  onPressed: _resending ? null : _resend,
                                  child: _resending
                                      ? const SizedBox(width: 16, height: 16,
                                          child: CircularProgressIndicator(color: AppTheme.tealPrimary, strokeWidth: 2))
                                      : const Text('Resend Code',
                                          style: TextStyle(color: AppTheme.tealPrimary,
                                              fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                        ),

                        const Spacer(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError
              ? AppTheme.redError.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: AppTheme.radiusMd,
            borderSide: BorderSide(
                color: hasError
                    ? AppTheme.redError
                    : Colors.white.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.radiusMd,
            borderSide: BorderSide(
                color: hasError
                    ? AppTheme.redError
                    : Colors.white.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.radiusMd,
            borderSide: BorderSide(
                color: hasError ? AppTheme.redError : AppTheme.tealPrimary,
                width: 2),
          ),
        ),
      ),
    );
  }
}