import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../../models/user_model.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';

// ── Sub-roles per category (for AI matching) ─────────────────────────────────
const Map<String, List<String>> _subRoles = {
  'Plumber': ['Emergency Plumber', 'Bathroom Specialist', 'Water Tank Expert', 'Pipe Fitter', 'Drain Cleaning'],
  'Electrician': ['Solar Installer', 'Inverter/UPS Specialist', 'CCTV & Security Systems', 'Fan & Lighting', 'Wiring Specialist'],
  'Carpenter': ['Furniture Maker', 'Door & Window Expert', 'Kitchen Cabinet Specialist', 'Modular Office Fit-out', 'Wood Polishing'],
  'Painter': ['Interior Designer Painter', 'Exterior Painter', 'Waterproofing Expert', 'Texture Finish Specialist', 'Wood Polish Expert'],
  'AC Technician': ['Split AC Specialist', 'Window AC Technician', 'Central AC / HVAC', 'Gas Filling Expert', 'Compressor Repair'],
  'Cleaner': ['Deep Clean Specialist', 'Sofa & Carpet Wash', 'Post-Construction Clean', 'Industrial Cleaner', 'Kitchen & Bathroom Expert'],
  'Security Guard': ['Day Shift Guard', 'Night Shift Guard', 'Armed Security', 'Event Security', 'Bank / Office Security'],
  'Driver': ['Local Trips Driver', 'Long Route Driver', 'School Pick-Drop', 'Office Commute Driver', 'Wedding / Events Driver'],
  'Cook': ['Home Cook', 'Catering Chef', 'BBQ Specialist', 'Desi Food Expert', 'Continental Chef'],
  'Mason': ['Brick Layer', 'Tile Fixer', 'Plastering Expert', 'Roof / Slab Work', 'Renovation Specialist'],
};

const Map<String, List<String>> _categorySkills = {
  'Plumber': ['Pipe Fitting', 'Leak Repair', 'Water Tank', 'Bathroom Fitting', 'Drain Cleaning'],
  'Electrician': ['Wiring', 'Circuit Breakers', 'Fan Installation', 'Inverter/UPS', 'CCTV', 'Solar Panels'],
  'Carpenter': ['Furniture Repair', 'Door/Window', 'Kitchen Cabinets', 'Polishing', 'Custom Work'],
  'Painter': ['Interior', 'Exterior', 'Texture Paint', 'Waterproofing', 'Wood Polish'],
  'AC Technician': ['AC Installation', 'Gas Filling', 'AC Service', 'Compressor Repair', 'HVAC'],
  'Cleaner': ['Deep Cleaning', 'Sofa/Carpet', 'Window Cleaning', 'Kitchen', 'Bathroom'],
  'Security Guard': ['Day Shift', 'Night Shift', 'Armed Security', 'Event Security'],
  'Driver': ['Local Trips', 'Long Route', 'School Pick-Drop', 'Office Commute'],
  'Cook': ['Desi Food', 'BBQ', 'Continental', 'Catering', 'Baking'],
  'Mason': ['Brick Work', 'Tiling', 'Plastering', 'Renovation', 'Roof Work'],
};

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
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubRole;
  int _experience = 1;
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;
  List<String> _selectedSkills = [];

  // Profile image
  String? _profileImageBase64;
  bool _pickingImage = false;

  final List<String> _cities = [
    'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
    'Multan', 'Hyderabad', 'Peshawar', 'Quetta', 'Sialkot',
  ];

  List<String> get _categories => _subRoles.keys.toList();

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose();
    _cnicCtrl.dispose(); _confirmPassCtrl.dispose(); _rateCtrl.dispose(); _bioCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (file == null) return;

      late Uint8List bytes;
      if (kIsWeb) {
        bytes = await file.readAsBytes();
      } else {
        bytes = await File(file.path).readAsBytes();
      }
      setState(() => _profileImageBase64 = base64Encode(bytes));
    } catch (e) {
      _showError('Could not load image: $e');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _showImagePicker() {
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
          const Text('Upload Profile Photo',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('A clear face photo helps customers trust you',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _ImageSourceBtn(
              icon: Icons.photo_library_outlined, label: 'Gallery',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            )),
            const SizedBox(width: 12),
            Expanded(child: _ImageSourceBtn(
              icon: Icons.camera_alt_outlined, label: 'Camera',
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

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      _showError('Please select at least one skill.');
      return;
    }
    if (_profileImageBase64 == null) {
      _showError('A profile photo is required. Please upload your photo.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    final code = await OtpService().sendOtp(_phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OtpScreen(
        phone: _phoneCtrl.text.trim(),
        demoOtp: code ?? '',
        onVerified: _register,
      ),
    ));
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });

    final user = AppUser(
      uid: '', name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(), city: _selectedCity ?? '', area: '',
      role: UserRole.worker, createdAt: DateTime.now(),
      serviceCategory: _selectedCategory, subRole: _selectedSubRole,
      skills: _selectedSkills,
      baseRatePkr: double.tryParse(_rateCtrl.text.trim()),
      experienceYears: _experience, isAvailable: true,
      bio: _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : null,
      profileImageBase64: _profileImageBase64,
    );

    final result = await AuthService().register(user, _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
    } else {
      _showError(result.errorMessage ?? 'Registration failed.');
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
                  const SizedBox(height: 20),
                  const Text('🔧  Register as a Worker',
                      style: TextStyle(color: AppTheme.purpleAgent, fontSize: 26, fontWeight: FontWeight.w800),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 6),
                  const Text('Create your profile and start getting jobs.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── Profile photo ──────────────────────────────────────────
                  AuthSectionHeader(title: 'Profile Photo (Required)', color: AppTheme.purpleAgent),
                  const SizedBox(height: 14),
                  _buildPhotoUploader(),

                  const SizedBox(height: 24),
                  AuthSectionHeader(title: 'Personal Information', color: AppTheme.purpleAgent),
                  const SizedBox(height: 14),

                  AuthGlassInput(controller: _nameCtrl, label: 'Full Name', hint: 'Muhammad Usman',
                      prefixIcon: Icons.person_outline, accentColor: AppTheme.purpleAgent,
                      validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _phoneCtrl, label: 'Phone Number', hint: '03XX XXXXXXX',
                      prefixIcon: Icons.phone_outlined, accentColor: AppTheme.purpleAgent,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Phone is required';
                        if (v.length < 10) return 'Enter a valid phone number';
                        return null;
                      }),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _cnicCtrl, label: 'CNIC Number', hint: '13 digits without dashes',
                      prefixIcon: Icons.badge_outlined, accentColor: AppTheme.purpleAgent,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'CNIC is required';
                        if (!RegExp(r'^\d{13}$').hasMatch(v)) {
                          return 'Enter 13 digits without dashes';
                        }
                        return null;
                      }),
                  const SizedBox(height: 16),

                  AuthDropdownField(label: 'City', hint: 'Select your city', value: _selectedCity,
                      items: _cities, accentColor: AppTheme.purpleAgent,
                      prefixIcon: Icons.location_city_outlined,
                      onChanged: (v) => setState(() => _selectedCity = v),
                      validator: (v) => v == null ? 'Please select your city' : null),

                  const SizedBox(height: 28),
                  AuthSectionHeader(title: 'Your Service & Role', color: AppTheme.purpleAgent),
                  const SizedBox(height: 14),

                  // Category
                  AuthDropdownField(label: 'Service Category', hint: 'What service do you offer?',
                      value: _selectedCategory, items: _categories,
                      accentColor: AppTheme.purpleAgent, prefixIcon: Icons.build_outlined,
                      onChanged: (v) => setState(() {
                        _selectedCategory = v;
                        _selectedSubRole = null;
                        _selectedSkills = [];
                      }),
                      validator: (v) => v == null ? 'Please select a category' : null),
                  const SizedBox(height: 16),

                  // Sub-role
                  if (_selectedCategory != null) ...[
                    AuthDropdownField(
                      label: 'Your Specialty (Sub-role)',
                      hint: 'Select your specific specialty',
                      value: _selectedSubRole,
                      items: _subRoles[_selectedCategory!] ?? [],
                      accentColor: AppTheme.purpleAgent,
                      prefixIcon: Icons.star_outline,
                      onChanged: (v) => setState(() => _selectedSubRole = v),
                      validator: (v) => v == null ? 'Please select your specialty' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Skills chips
                  if (_selectedCategory != null) ...[
                    const Text('Skills (select all that apply)',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: (_categorySkills[_selectedCategory!] ?? []).map((skill) {
                        final sel = _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill), selected: sel,
                          onSelected: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => sel ? _selectedSkills.remove(skill) : _selectedSkills.add(skill));
                          },
                          selectedColor: AppTheme.purpleAgent.withValues(alpha: 0.25),
                          checkmarkColor: AppTheme.purpleAgent,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          labelStyle: TextStyle(
                            color: sel ? AppTheme.purpleAgent : AppTheme.textSecondary,
                            fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400),
                          side: BorderSide(color: sel ? AppTheme.purpleAgent : Colors.white.withValues(alpha: 0.15)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Experience stepper
                  const Text('Years of Experience',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06), borderRadius: AppTheme.radiusMd,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: Row(children: [
                      const Icon(Icons.work_outline, color: AppTheme.purpleAgent, size: 20),
                      const SizedBox(width: 12),
                      Text('$_experience year${_experience == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      _StepBtn(icon: Icons.remove, color: AppTheme.purpleAgent,
                          onTap: () => setState(() { if (_experience > 1) _experience--; })),
                      const SizedBox(width: 12),
                      _StepBtn(icon: Icons.add, color: AppTheme.purpleAgent,
                          onTap: () => setState(() => _experience++)),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _rateCtrl, label: 'Hourly Rate (PKR)', hint: 'e.g. 500',
                      prefixIcon: Icons.payments_outlined, accentColor: AppTheme.purpleAgent,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Hourly rate is required';
                        if (double.tryParse(v) == null) return 'Enter a valid number';
                        return null;
                      }),
                  const SizedBox(height: 16),

                  AuthGlassInput(controller: _bioCtrl, label: 'About You (optional)',
                      hint: 'Tell customers about yourself and your work quality...',
                      prefixIcon: Icons.info_outline, accentColor: AppTheme.purpleAgent, maxLines: 3),

                  const SizedBox(height: 28),
                  AuthSectionHeader(title: 'Account Security', color: AppTheme.purpleAgent),
                  const SizedBox(height: 14),

                  AuthGlassInput(controller: _passCtrl, label: 'Password', hint: '••••••••',
                      prefixIcon: Icons.lock_outline, accentColor: AppTheme.purpleAgent,
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
                      prefixIcon: Icons.lock_outline, accentColor: AppTheme.purpleAgent,
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
                        backgroundColor: AppTheme.purpleAgent, foregroundColor: Colors.white,
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
                      child: const Text('Already registered? Sign In',
                          style: TextStyle(color: AppTheme.purpleLight, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile photo uploader ───────────────────────────────────────────────
  Widget _buildPhotoUploader() {
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
                          Text('Add Photo', style: TextStyle(color: AppTheme.purpleAgent.withValues(alpha: 0.8), fontSize: 11)),
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

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
