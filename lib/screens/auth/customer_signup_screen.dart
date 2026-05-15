import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../../models/user_model.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  String? _selectedCity;
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  final List<String> _cities = [
    'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
    'Multan', 'Hyderabad', 'Peshawar', 'Quetta', 'Sialkot',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _confirmPassCtrl.dispose(); _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final sendResult = await OtpService().sendOtp(_phoneCtrl.text.trim());
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
          phone: _phoneCtrl.text.trim(),
          demoOtp: sendResult.demoCode ?? '',
          onVerified: _register,
        ),
      ),
    );
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });

    final user = AppUser(
      uid: '', name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      email: '', city: _selectedCity ?? '', area: _areaCtrl.text.trim(),
      role: UserRole.customer, createdAt: DateTime.now(),
    );

    final result = await AuthService().register(user, _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  const Text('🏠  Create Customer Account',
                    style: TextStyle(color: AppTheme.tealPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 6),
                  const Text('Find and book trusted workers near you.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 32),

                  AuthGlassInput(controller: _nameCtrl, label: 'Full Name', hint: 'Ali Hassan',
                    prefixIcon: Icons.person_outline, accentColor: AppTheme.tealPrimary,
                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _phoneCtrl, label: 'Phone Number', hint: '03XX XXXXXXX',
                    prefixIcon: Icons.phone_outlined, accentColor: AppTheme.tealPrimary,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Phone is required';
                      if (v.length < 10) return 'Enter a valid phone number';
                      return null;
                    }),
                  const SizedBox(height: 16),

                  AuthDropdownField(label: 'City', hint: 'Select your city', value: _selectedCity,
                    items: _cities, accentColor: AppTheme.tealPrimary,
                    prefixIcon: Icons.location_city_outlined,
                    onChanged: (v) => setState(() => _selectedCity = v),
                    validator: (v) => v == null ? 'Please select your city' : null),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _areaCtrl, label: 'Locality / Area',
                    hint: 'e.g. DHA, Gulshan, Model Town',
                    prefixIcon: Icons.location_on_outlined, accentColor: AppTheme.tealPrimary,
                    validator: (v) => v == null || v.isEmpty ? 'Area is required' : null),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _passCtrl, label: 'Password', hint: '••••••••',
                    prefixIcon: Icons.lock_outline, accentColor: AppTheme.tealPrimary,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    }),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _confirmPassCtrl, label: 'Confirm Password', hint: '••••••••',
                    prefixIcon: Icons.lock_outline, accentColor: AppTheme.tealPrimary,
                    obscureText: _obscurePass,
                    validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AuthErrorBox(message: _error!),
                  ],
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendOtpAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tealPrimary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd), elevation: 0),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Verification Code',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Sign In',
                          style: TextStyle(color: AppTheme.tealLight, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
