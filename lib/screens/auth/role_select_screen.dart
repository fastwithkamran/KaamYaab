import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/language_service.dart';
import 'worker_signup_screen.dart';
import 'customer_signup_screen.dart';

/// Role-selection landing screen with Urdu / English language toggle.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  UserRole? _selectedRole;
  bool _isUrdu = LanguageService().isUrdu;

  Future<void> _switchLanguage(bool urdu) async {
    HapticFeedback.selectionClick();
    await LanguageService().setUrdu(urdu);
    setState(() => _isUrdu = urdu);
  }

  void _select(UserRole role) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedRole = role);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => role == UserRole.worker ? const WorkerSignupScreen() : const CustomerSignupScreen(),
      ));
    });
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

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
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ── Language Toggle ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: AppTheme.radiusMd,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  _LangBtn(
                                    label: 'English', flag: '🇬🇧',
                                    selected: !_isUrdu,
                                    onTap: () => _switchLanguage(false),
                                  ),
                                  _LangBtn(
                                    label: 'اردو', flag: '🇵🇰',
                                    selected: _isUrdu,
                                    onTap: () => _switchLanguage(true),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: 32),

                        // ── Logo / Header ─────────────────────────────────────────────
                        Column(children: [
                          ShaderMask(
                            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                            child: Text(
                              _t('KaamYaab', 'کامیاب'),
                              style: const TextStyle(
                                color: Colors.white, fontSize: 46,
                                fontWeight: FontWeight.w800, letterSpacing: -1,
                              ),
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                          const SizedBox(height: 8),
                          Text(
                            _t("Pakistan's Smartest Home Services", "پاکستان کی سب سے ذہین گھریلو خدمت"),
                            style: TextStyle(
                              color: AppTheme.tealLight.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                        ]),

                        const SizedBox(height: 44),

                        // ── Who are you question ──────────────────────────────────────
                        Text(
                          _t("Who are you?", "آپ کون ہیں؟"),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                        const SizedBox(height: 8),
                        Text(
                          _t("Select your role to continue", "جاری رکھنے کے لیے اپنا کردار منتخب کریں"),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

                        const SizedBox(height: 32),

                        // ── Role Cards ─────────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(children: [
                            // Customer
                            _RoleCard(
                              emoji: '🏠',
                              title: _t("I need a service", "مجھے خدمت چاہیے"),
                              subtitle: _t(
                                "Find plumbers, electricians &\nmore near you",
                                "اپنے قریب پلمبر، بجلی کار\nاور مزید تلاش کریں",
                              ),
                              isSelected: _selectedRole == UserRole.customer,
                              gradient: LinearGradient(colors: [
                                AppTheme.tealPrimary.withValues(alpha: 0.15),
                                AppTheme.blueInfo.withValues(alpha: 0.08),
                              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderColor: _selectedRole == UserRole.customer
                                  ? AppTheme.tealPrimary
                                  : AppTheme.tealPrimary.withValues(alpha: 0.3),
                              onTap: () => _select(UserRole.customer),
                            ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideX(begin: -0.2),

                            const SizedBox(height: 16),

                            // Worker
                            _RoleCard(
                              emoji: '🔧',
                              title: _t("I offer a service", "میں خدمت دیتا ہوں"),
                              subtitle: _t(
                                "Register as a worker and\nget more customers",
                                "کارکن کے طور پر رجسٹر ہوں\nاور زیادہ گاہک پائیں",
                              ),
                              isSelected: _selectedRole == UserRole.worker,
                              gradient: LinearGradient(colors: [
                                AppTheme.purpleAgent.withValues(alpha: 0.15),
                                AppTheme.goldAccent.withValues(alpha: 0.08),
                              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderColor: _selectedRole == UserRole.worker
                                  ? AppTheme.purpleAgent
                                  : AppTheme.purpleAgent.withValues(alpha: 0.3),
                              onTap: () => _select(UserRole.worker),
                            ).animate().fadeIn(delay: 650.ms, duration: 500.ms).slideX(begin: 0.2),
                          ]),
                        ),

                        const Spacer(),

                        // ── Feature Pills ──────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10, runSpacing: 8,
                            children: [
                              _FeaturePill(_t('🤖 AI Matching', '🤖 ذہین تلاش')),
                              _FeaturePill(_t('✅ Verified Workers', '✅ تصدیق شدہ کارکن')),
                              _FeaturePill(_t('💬 Fair Pricing', '💬 منصفانہ قیمت')),
                              _FeaturePill(_t('⭐ Rated & Reviewed', '⭐ جائزہ شدہ')),
                            ],
                          ),
                        ).animate().fadeIn(delay: 800.ms, duration: 500.ms),

                        const SizedBox(height: 32),
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

// ── Language Toggle Button ────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  final String label, flag;
  final bool selected;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.flag, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.tealPrimary.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: AppTheme.radiusMd,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: selected ? AppTheme.tealPrimary : AppTheme.textMuted,
            fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool isSelected;
  final LinearGradient gradient;
  final Color borderColor;
  final VoidCallback onTap;
  const _RoleCard({required this.emoji, required this.title, required this.subtitle,
    required this.isSelected, required this.gradient, required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient, borderRadius: AppTheme.radiusLg,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 20)]
              : [],
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ])),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? borderColor : Colors.transparent,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }
}

// ── Feature Pill ──────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final String text;
  const _FeaturePill(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: AppTheme.radiusSm,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
