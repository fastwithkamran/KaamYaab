import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);

    _revealCtrl.forward();

    // Navigate to login/home based on auth state
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        final auth = AuthService();
        if (auth.isLoggedIn) {
          final route = auth.currentUser!.isWorker ? '/dashboard' : '/home';
          Navigator.of(context).pushReplacementNamed(route);
        } else {
          Navigator.of(context).pushReplacementNamed('/lang');
        }
      }
    });
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Background particle dots
            ...List.generate(12, (i) => _ParticleDot(index: i)),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Custom Logo
                  Image.asset(
                    'assets/images/logo.png',
                    width: 160,
                    height: 160,
                  ).animate().scale(
                        duration: 1000.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.3, 0.3),
                        end: const Offset(1.0, 1.0),
                      ).fadeIn(duration: 800.ms),

                  const SizedBox(height: 32),

                  // Brand name reveal
                  AnimatedBuilder(
                    animation: _revealAnim,
                    builder: (_, child) => Opacity(
                      opacity: _revealAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _revealAnim.value)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: const Text(
                            'KaamYaab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI Service Orchestrator',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.agentGradient,
                            borderRadius: AppTheme.radiusXl,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.purpleAgent.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⚡', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Text(
                                'AI SEEKHO HACKATHON',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading dots
                  AnimatedBuilder(
                    animation: _revealAnim,
                    builder: (_, a) => Opacity(
                      opacity: _revealAnim.value,
                      child: const _LoadingDots(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Particle Background Dot ────────────────────────────────────────────────────
class _ParticleDot extends StatelessWidget {
  final int index;
  const _ParticleDot({required this.index});

  @override
  Widget build(BuildContext context) {
    final rng = Random(index * 37);
    final size = MediaQuery.of(context).size;
    final x = rng.nextDouble() * size.width;
    final y = rng.nextDouble() * size.height;
    final dotSize = 2.0 + rng.nextDouble() * 3.0;
    final delay = Duration(milliseconds: index * 150);
    final colors = [
      AppTheme.tealPrimary,
      AppTheme.purpleAgent,
      AppTheme.goldAccent,
      AppTheme.blueInfo,
    ];

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[index % colors.length].withValues(alpha: 0.3),
        ),
      ).animate(delay: delay).fadeIn(duration: 600.ms).then().animate(
        onPlay: (c) => c.repeat(reverse: true),
      ).scaleXY(end: 1.8, duration: 2000.ms),
    );
  }
}

// ── Loading Dots ───────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, a) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final pulse = sin(offset * pi).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tealPrimary.withValues(alpha: 0.3 + 0.7 * pulse),
              ),
            );
          }),
        );
      },
    );
  }
}
