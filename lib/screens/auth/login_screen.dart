import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/auth_widgets.dart';
import 'customer_signup_screen.dart';
import 'worker_signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  bool get _isWorker => widget.role == UserRole.worker;
  String get _roleLabel => _isWorker ? 'Worker' : 'Customer';
  Color get _accentColor =>
      _isWorker ? AppTheme.purpleAgent : AppTheme.tealPrimary;
  String get _emoji => _isWorker ? '🔧' : '🏠';

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final result = await AuthService().login(
      _phoneCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      if (result.user!.role != widget.role) {
        setState(() => _error =
            'This account is registered as a ${result.user!.roleLabel}. '
            'Please go back and select the correct role.');
        return;
      }
      HapticFeedback.heavyImpact();
      // Admin check
      if (AuthService().isAdmin) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/admin', (r) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          _isWorker ? '/dashboard' : '/home',
          (r) => false,
        );
      }
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                            '$_emoji  $_roleLabel Sign In',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ).animate().fadeIn(duration: 400.ms),

                          const SizedBox(height: 8),
                          const Text(
                            'Welcome back! Enter your details below.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                          const SizedBox(height: 36),

                          AuthGlassInput(
                            controller: _phoneCtrl,
                            label: 'Phone Number',
                            hint: '03XX XXXXXXX',
                            prefixIcon: Icons.phone_outlined,
                            accentColor: _accentColor,
                            keyboardType: TextInputType.phone,
                            inputFormatters: pakistanPhoneInputFormatters,
                            maxLength: 11,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Phone is required';
                              if (!pakistanPhoneRegex.hasMatch(v)) {
                                return 'Enter a valid 11-digit number starting with 03';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                          const SizedBox(height: 16),

                          AuthGlassInput(
                            controller: _passCtrl,
                            label: 'Password',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            accentColor: _accentColor,
                            obscureText: _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Password is required';
                              if (v.length < 6)
                                return 'Password must be at least 6 characters';
                              return null;
                            },
                          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

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
                              onPressed: _loading ? null : _login,
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
                                      'Sign In as $_roleLabel',
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
                              child: Text('New to KaamYaab?',
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
                                'Create $_roleLabel Account',
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
