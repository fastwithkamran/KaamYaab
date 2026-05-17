import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../../models/user_model.dart';
import '../../utils/cnic_utils.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';
import 'login_screen.dart';

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  String? _selectedCity;
  bool _loading = false;
  String? _error;

  final List<String> _cities = [
    'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
    'Multan', 'Hyderabad', 'Peshawar', 'Quetta', 'Sialkot',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _cnicCtrl.dispose(); _areaCtrl.dispose();
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
      cnic: _cnicCtrl.text.trim(), city: _selectedCity ?? '', area: _areaCtrl.text.trim(),
      role: UserRole.customer, createdAt: DateTime.now(),
    );

    final result = await AuthService().register(user);
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
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 24),
                          Text(isUrdu ? '🏠 گاہک اکاؤنٹ بنائیں' : '🏠  Create Customer Account',
                            style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 6),
                          Text(isUrdu ? 'اپنے قریب بھروسہ مند کارکن تلاش کریں اور بک کریں۔' : 'Find and book trusted workers near you.',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                          const SizedBox(height: 32),

                          AuthGlassInput(controller: _nameCtrl, label: isUrdu ? 'پورا نام' : 'Full Name', hint: isUrdu ? 'علی حسن' : 'Ali Hassan',
                            prefixIcon: Icons.person_outline, accentColor: AppTheme.tealPrimary,
                            validator: (v) => v == null || v.isEmpty ? (isUrdu ? 'نام درکار ہے' : 'Name is required') : null),
                          const SizedBox(height: 16),

                          AuthGlassInput(controller: _phoneCtrl, label: isUrdu ? 'فون نمبر' : 'Phone Number', hint: '03XX XXXXXXX',
                            prefixIcon: Icons.phone_outlined, accentColor: AppTheme.tealPrimary,
                            keyboardType: TextInputType.phone,
                            inputFormatters: pakistanPhoneInputFormatters,
                            maxLength: 11,
                            validator: (v) {
                              if (v == null || v.isEmpty) return isUrdu ? 'فون نمبر درکار ہے' : 'Phone is required';
                              if (!pakistanPhoneRegex.hasMatch(v)) {
                                return isUrdu ? 'درست فون نمبر درج کریں' : 'Enter a valid 11-digit number starting with 03';
                              }
                              return null;
                            }),
                          const SizedBox(height: 16),

                          AuthGlassInput(controller: _cnicCtrl, label: isUrdu ? 'شناختی کارڈ نمبر' : 'CNIC Number', hint: isUrdu ? 'بغیر ڈیش کے 13 ہندسے' : '13 digits without dashes',
                            prefixIcon: Icons.badge_outlined, accentColor: AppTheme.tealPrimary,
                            keyboardType: TextInputType.number,
                            inputFormatters: CnicUtils.inputFormatters,
                            validator: CnicUtils.validator),
                          const SizedBox(height: 16),

                          AuthDropdownField(label: isUrdu ? 'شہر' : 'City', hint: isUrdu ? 'اپنا شہر منتخب کریں' : 'Select your city', value: _selectedCity,
                            items: _cities, accentColor: AppTheme.tealPrimary,
                            prefixIcon: Icons.location_city_outlined,
                            onChanged: (v) => setState(() => _selectedCity = v),
                            validator: (v) => v == null ? (isUrdu ? 'براہ کرم اپنا شہر منتخب کریں' : 'Please select your city') : null),
                          const SizedBox(height: 16),

                          AuthGlassInput(controller: _areaCtrl, label: isUrdu ? 'علاقہ / محلہ' : 'Locality / Area',
                            hint: isUrdu ? 'مثلاً ڈی ایچ اے، گلشن، ماڈل ٹاؤن' : 'e.g. DHA, Gulshan, Model Town',
                            prefixIcon: Icons.location_on_outlined, accentColor: AppTheme.tealPrimary,
                            validator: (v) => v == null || v.isEmpty ? (isUrdu ? 'علاقہ درکار ہے' : 'Area is required') : null),
                          const SizedBox(height: 16),

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
                                  : Text(isUrdu ? 'تصدیقی کوڈ بھیجیں' : 'Send Verification Code',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen(role: UserRole.customer)),
                              ),
                              child: Text(isUrdu ? 'پہلے سے اکاؤنٹ ہے؟ سائن ان کریں' : 'Already have an account? Sign In',
                                  style: const TextStyle(color: AppTheme.tealLight, fontSize: 13)),
                            ),
                          ),

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
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen(role: UserRole.customer)),
                              ),
                              child: const Text('Already have an account? Sign In',
                                  style: TextStyle(color: AppTheme.tealLight, fontSize: 13)),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 32),
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
