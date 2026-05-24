import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
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

class WorkerSignupScreen extends StatefulWidget {
  const WorkerSignupScreen({super.key});

  @override
  State<WorkerSignupScreen> createState() => _WorkerSignupScreenState();
}

class _WorkerSignupScreenState extends State<WorkerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _loading = false;
  String? _error;

  // Profile image (now optional)
  String? _profileImageBase64;
  bool _pickingImage = false;



  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ────────────────────────────────────────────────────────────
Future<void> _pickImage(ImageSource source) async {
  setState(() => _pickingImage = true);
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source, maxWidth: 600, maxHeight: 600, imageQuality: 75,
    );
    if (file == null) return;

    late Uint8List bytes;
    if (kIsWeb) {
      bytes = await file.readAsBytes();
    } else {
      bytes = await File(file.path).readAsBytes();
    }
    if (!mounted) return;                                      // ← add this
    setState(() => _profileImageBase64 = base64Encode(bytes));
  } catch (e) {
    if (mounted) _showError('Could not load image: $e');      // ← add mounted check
  } finally {
    if (mounted) setState(() => _pickingImage = false);
  }
}

  void _showImagePicker() {
    final isUrdu = LanguageService().isUrdu;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(isUrdu ? 'پروفائل فوٹو اپ لوڈ کریں' : 'Upload Profile Photo',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(isUrdu ? 'واضح چہرے کی تصویر گاہکوں کو آپ پر بھروسہ کرنے میں مدد دیتی ہے' : 'A clear face photo helps customers trust you',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _ImageSourceBtn(
              icon: Icons.photo_library_outlined, label: isUrdu ? 'گیلری' : 'Gallery',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            )),
            const SizedBox(width: 12),
            Expanded(child: _ImageSourceBtn(
              icon: Icons.camera_alt_outlined, label: isUrdu ? 'کیمرہ' : 'Camera',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showError(String msg) {
    setState(() => _error = msg);
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
      _showError(LanguageService().isUrdu 
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
      setState(() => _loading = false);
      _showError(LanguageService().isUrdu 
          ? 'یہ فون نمبر پہلے سے رجسٹرڈ ہے۔' 
          : 'This phone number is already registered.');
      return;
    }

    final sendResult = await OtpService().sendOtp(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (sendResult.hasFatalError) {
      _showError(sendResult.errorMessage ?? 'Could not send OTP.');
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OtpScreen(
        phone: phone,
        demoOtp: sendResult.demoCode ?? '',
        onVerified: _register,
      ),
    ));
  }

  Future<String?> _register() async {
    setState(() { _loading = true; _error = null; });

    final user = AppUser(
      uid: '', name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(), city: '', area: '',
      role: UserRole.worker, createdAt: DateTime.now(),
      // Defaults that will be filled out by AI Agent later
      serviceCategory: 'Unassigned',
      subRole: null,
      skills: [],
      baseRatePkr: 0.0,
      experienceYears: 1,
      isAvailable: true,
      profileImageBase64: _profileImageBase64,
      latitude: _latitude,
      longitude: _longitude,
    );

    final result = await AuthService().register(user);
    if (!mounted) return null;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
      return null;
    } else {
      _showError(result.errorMessage ?? 'Registration failed.');
      return result.errorMessage ?? 'Registration failed.';
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
                          const SizedBox(height: 20),
                          Text(isUrdu ? '🔧 کارکن کے طور پر رجسٹر ہوں' : '🔧  Register as a Worker',
                              style: const TextStyle(color: AppTheme.purpleAgent, fontSize: 26, fontWeight: FontWeight.w800),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 6),
                          Text(isUrdu ? 'پروفائل بنائیں اور کام حاصل کرنا شروع کریں۔' : 'Create your profile and start getting jobs.',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                          const SizedBox(height: 28),

                          // ── Profile photo ──────────────────────────────────────────
                          AuthSectionHeader(title: isUrdu ? 'پروفائل فوٹو (اختیاری)' : 'Profile Photo (Optional)', color: AppTheme.purpleAgent),
                          const SizedBox(height: 14),
                          _buildPhotoUploader(),

                          const SizedBox(height: 24),
                          AuthSectionHeader(title: isUrdu ? 'ذاتی معلومات' : 'Personal Information', color: AppTheme.purpleAgent),
                          const SizedBox(height: 14),

                          AuthGlassInput(controller: _nameCtrl, label: isUrdu ? 'پورا نام' : 'Full Name', hint: isUrdu ? 'محمد عثمان' : 'Muhammad Usman',
                              prefixIcon: Icons.person_outline, accentColor: AppTheme.purpleAgent,
                              validator: (v) => v == null || v.isEmpty ? (isUrdu ? 'نام درکار ہے' : 'Name is required') : null),
                          const SizedBox(height: 16),

                          AuthGlassInput(controller: _phoneCtrl, label: isUrdu ? 'فون نمبر' : 'Phone Number', hint: '03XX XXXXXXX',
                              prefixIcon: Icons.phone_outlined, accentColor: AppTheme.purpleAgent,
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
                              prefixIcon: Icons.badge_outlined, accentColor: AppTheme.purpleAgent,
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
                                  color: _latitude != null ? AppTheme.purpleAgent : Colors.white.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _latitude != null ? Icons.location_on : Icons.map_outlined,
                                    color: _latitude != null ? AppTheme.purpleAgent : Colors.white54,
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
                                    const Icon(Icons.check_circle, color: AppTheme.purpleAgent, size: 20),
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
                                backgroundColor: AppTheme.purpleAgent, foregroundColor: Colors.white,
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
                                MaterialPageRoute(builder: (_) => const LoginScreen(role: UserRole.worker)),
                              ),
                              child: Text(isUrdu ? 'پہلے سے رجسٹرڈ ہیں؟ سائن ان کریں' : 'Already registered? Sign In',
                                  style: const TextStyle(color: AppTheme.purpleLight, fontSize: 13)),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 40),
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

  // ── Profile photo uploader ───────────────────────────────────────────────
  Widget _buildPhotoUploader() {
    final isUrdu = LanguageService().isUrdu;
    return Center(
      child: GestureDetector(
        onTap: _showImagePicker,
        child: Stack(
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAgent.withValues(alpha: 0.1),
                border: Border.all(
                  color: _profileImageBase64 != null
                      ? AppTheme.greenSuccess
                      : AppTheme.purpleAgent.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: _pickingImage
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.purpleAgent, strokeWidth: 2))
                  : _profileImageBase64 != null
                      ? ClipOval(child: Image.memory(
                            base64Decode(_profileImageBase64!),
                            fit: BoxFit.cover, width: 110, height: 110))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.person_add_alt_1, color: AppTheme.purpleAgent, size: 36),
                          const SizedBox(height: 6),
                          Text(isUrdu ? 'تصویر شامل کریں' : 'Add Photo', style: TextStyle(color: AppTheme.purpleAgent.withValues(alpha: 0.8), fontSize: 11)),
                        ]),
            ),
            Positioned(bottom: 4, right: 4,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _profileImageBase64 != null ? AppTheme.greenSuccess : AppTheme.purpleAgent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.backgroundDark, width: 2),
                ),
                child: Icon(
                  _profileImageBase64 != null ? Icons.check : Icons.camera_alt,
                  color: Colors.white, size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImageSourceBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.purpleAgent.withValues(alpha: 0.1),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.purpleAgent, size: 30),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.purpleAgent, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}