import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/language_service.dart';
import 'role_select_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _selectLanguage(BuildContext context, bool urdu) async {
    HapticFeedback.mediumImpact();
    await LanguageService().setUrdu(urdu);
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                  child: const Text(
                    'KaamYaab',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8)),
                
                const SizedBox(height: 12),
                
                const Text(
                  "Pakistan's Smartest Home Services App",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 60),

                const Text(
                  "Choose your language",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ).animate().fadeIn(delay: 500.ms),
                
                const Text(
                  "اپنی زبان منتخب کریں",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LangCard(
                          label: 'English',
                          flag: '🇬🇧',
                          onTap: () => _selectLanguage(context, false),
                        ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _LangCard(
                          label: 'اردو',
                          flag: '🇵🇰',
                          onTap: () => _selectLanguage(context, true),
                        ).animate().fadeIn(delay: 1000.ms).slideX(begin: 0.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String label, flag;
  final VoidCallback onTap;
  const _LangCard({required this.label, required this.flag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: AppTheme.radiusLg,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
