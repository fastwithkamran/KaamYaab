import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/auth_widgets.dart';
import 'customer_signup_screen.dart';
import 'worker_signup_screen.dart';
import 'otp_screen.dart';
import '../../services/otp_service.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _isWorker => widget.role == UserRole.worker;
  String get _roleLabel => _isWorker ? 'Worker' : 'Customer';
  String get _roleUrdu => _isWorker ? 'کارکن' : 'گاہک';
  Color get _accentColor =>
      _isWorker ? AppTheme.purpleAgent : AppTheme.tealPrimary;
  String get _emoji => _isWorker ? '🔧' : '🏠';

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final phone = _phoneCtrl.text.trim();

    // Check if the user is registered
    final user = await AuthService().getUserByPhone(phone);
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = LanguageService().isUrdu
            ? 'اس فون نمبر کے ساتھ کوئی اکاؤنٹ نہیں ملا۔'
            : 'No account found with this phone number.';
      });
      return;
    }
    
    // Check if user is banned
    final isBanned = await AuthService().isUserBanned(user.uid);
    if (isBanned) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = LanguageService().isUrdu
            ? 'آپ کا اکاؤنٹ معطل کر دیا گیا ہے۔'
            : 'Your account has been suspended.';
      });
      return;
    }

    // Check if user role matches
    if (user.role != widget.role) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = LanguageService().isUrdu 
            ? 'یہ اکاؤنٹ $_roleUrdu کے طور پر رجسٹرڈ نہیں ہے۔'
            : 'This account is registered as a ${user.roleLabel}. '
              'Please go back and select the correct role.';
      });
      return;
    }

    // Send OTP
    final sendResult = await OtpService().sendOtp(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (sendResult.hasFatalError) {
      setState(() => _error = sendResult.errorMessage ?? 'Could not send OTP.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: phone,
          demoOtp: sendResult.demoCode ?? '',
          onVerified: () => _doLogin(phone),
        ),
      ),
    );
  }

  Future<String?> _doLogin(String phone) async {
    setState(() { _loading = true; _error = null; });

    final result = await AuthService().login(phone);
    if (!mounted) return null;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushNamedAndRemoveUntil(
        _isWorker ? '/dashboard' : '/home',
        (r) => false,
      );
      return null;
    } else {
      setState(() => _error = result.errorMessage);
      return result.errorMessage;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = LanguageService().isUrdu;
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 24),

                          Text(
                            isUrdu ? '$_emoji $_roleUrdu سائن ان' : '$_emoji  $_roleLabel Sign In',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ).animate().fadeIn(duration: 400.ms),

                          const SizedBox(height: 8),
                          Text(
                            isUrdu ? 'واپس خوش آمدید! اپنی تفصیلات نیچے درج کریں۔' : 'Welcome back! Enter your details below.',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                          const SizedBox(height: 36),

                          AuthGlassInput(
                            controller: _phoneCtrl,
                            label: isUrdu ? 'فون نمبر' : 'Phone Number',
                            hint: '03XX XXXXXXX',
                            prefixIcon: Icons.phone_outlined,
                            accentColor: _accentColor,
                            keyboardType: TextInputType.phone,
                            inputFormatters: pakistanPhoneInputFormatters,
                            maxLength: 11,
                            validator: (v) {
                              if (v == null || v.isEmpty) return isUrdu ? 'فون نمبر درکار ہے' : 'Phone is required';
                              if (!pakistanPhoneRegex.hasMatch(v)) {
                                return isUrdu ? 'درست فون نمبر درج کریں' : 'Enter a valid 11-digit number starting with 03';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            AuthErrorBox(message: _error!)
                                .animate()
                                .shake(duration: 400.ms),
                          ],

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _sendOtpAndContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.radiusMd),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      isUrdu ? 'بطور $_roleUrdu سائن ان کریں' : 'Sign In as $_roleLabel',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                          const SizedBox(height: 24),

                          Row(children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withValues(alpha: 0.1))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(isUrdu ? 'کامیاب میں نئے ہیں؟' : 'New to KaamYaab?',
                                  style: TextStyle(
                                      color: AppTheme.textMuted, fontSize: 13)),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withValues(alpha: 0.1))),
                          ]),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _isWorker
                                        ? const WorkerSignupScreen()
                                        : const CustomerSignupScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accentColor,
                                side: BorderSide(color: _accentColor, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.radiusMd),
                              ),
                              child: Text(
                                isUrdu ? '$_roleUrdu اکاؤنٹ بنائیں' : 'Create $_roleLabel Account',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                          const Spacer(),
                          const SizedBox(height: 24),
                        ],
                      ),
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
