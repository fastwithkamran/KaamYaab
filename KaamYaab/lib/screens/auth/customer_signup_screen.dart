import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../../models/user_model.dart';
import '../../utils/cnic_utils.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';
import 'login_screen.dart';
import '../map_picker_screen.dart';

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

  double? _latitude;
  double? _longitude;
  bool _loading = false;
  String? _error;



  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_latitude == null || _longitude == null) {
      setState(() => _error = LanguageService().isUrdu 
          ? 'براہ کرم نقشے پر اپنی لوکیشن منتخب کریں۔' 
          : 'Please select your location on the map.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final phone = _phoneCtrl.text.trim();
    final isRegistered = await AuthService().isPhoneRegistered(phone);
    if (isRegistered) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = LanguageService().isUrdu 
            ? 'یہ فون نمبر پہلے سے رجسٹرڈ ہے۔' 
            : 'This phone number is already registered.';
      });
      return;
    }

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
          onVerified: _register,
        ),
      ),
    );
  }

  Future<String?> _register() async {
    setState(() { _loading = true; _error = null; });

    final user = AppUser(
      uid: '', name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(), city: '', area: '',
      role: UserRole.customer, createdAt: DateTime.now(),
      latitude: _latitude, longitude: _longitude,
    );

    final result = await AuthService().register(user);
    if (!mounted) return null;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      return null;
    } else {
      setState(() => _error = result.errorMessage);
      return result.errorMessage;
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



                          // Map Picker Button
                          InkWell(
                            onTap: _pickLocation,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: AppTheme.radiusMd,
                                border: Border.all(
                                  color: _latitude != null ? AppTheme.tealPrimary : Colors.white.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _latitude != null ? Icons.location_on : Icons.map_outlined,
                                    color: _latitude != null ? AppTheme.tealPrimary : Colors.white54,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu ? 'نقشے پر لوکیشن سیٹ کریں' : 'Set Location on Map',
                                          style: TextStyle(
                                            color: _latitude != null ? Colors.white : Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (_latitude != null)
                                          Text(
                                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_latitude != null)
                                    const Icon(Icons.check_circle, color: AppTheme.tealPrimary, size: 20),
                                ],
                              ),
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
