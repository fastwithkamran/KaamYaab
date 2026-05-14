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
  late AnimationController _helixCtrl;
  late AnimationController _revealCtrl;
  late Animation<double> _helixAnim;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();

    _helixCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _helixAnim = CurvedAnimation(parent: _helixCtrl, curve: Curves.easeOutCubic);

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);

    _helixCtrl.forward().then((_) => _revealCtrl.forward());

    // Navigate to login/home based on auth state
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        final auth = AuthService();
        if (auth.isLoggedIn) {
          final route = auth.currentUser!.isWorker ? '/dashboard' : '/home';
          Navigator.of(context).pushReplacementNamed(route);
        } else {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _helixCtrl.dispose();
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
                  // DNA Helix animation
                  AnimatedBuilder(
                    animation: _helixAnim,
                    builder: (_, __) => CustomPaint(
                      size: const Size(120, 160),
                      painter: _DnaHelixPainter(_helixAnim.value),
                    ),
                  ),

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
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AI Service Orchestrator',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.agentGradient,
                            borderRadius: AppTheme.radiusXl,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('âš¡', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 6),
                              Text(
                                'Powered by Antigravity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
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
                    builder: (_, __) => Opacity(
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

// â”€â”€ DNA Helix Painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DnaHelixPainter extends CustomPainter {
  final double progress;
  _DnaHelixPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final amplitude = size.width * 0.35;
    final wavelength = size.height / 2.5;
    final totalPoints = 60;
    final drawnPoints = (totalPoints * progress).round();

    final strand1Paint = Paint()
      ..color = AppTheme.tealPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final strand2Paint = Paint()
      ..color = AppTheme.purpleAgent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rungPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path1 = Path();
    final path2 = Path();

    for (int i = 0; i <= drawnPoints; i++) {
      final t = i / totalPoints;
      final y = t * size.height;
      final x1 = cx + amplitude * sin(2 * pi * y / wavelength);
      final x2 = cx - amplitude * sin(2 * pi * y / wavelength);

      if (i == 0) {
        path1.moveTo(x1, y);
        path2.moveTo(x2, y);
      } else {
        path1.lineTo(x1, y);
        path2.lineTo(x2, y);
      }

      // Draw rungs every ~8 points
      if (i % 8 == 0 && i > 0) {
        final rungProgress = (i / drawnPoints).clamp(0.0, 1.0);
        rungPaint.color = Color.lerp(
          AppTheme.tealPrimary,
          AppTheme.purpleAgent,
          sin(2 * pi * y / wavelength) * 0.5 + 0.5,
        )!.withValues(alpha: 0.6 * rungProgress);
        canvas.drawLine(Offset(x1, y), Offset(x2, y), rungPaint);

        // Dots at rung ends
        canvas.drawCircle(
          Offset(x1, y),
          3.5,
          Paint()..color = AppTheme.tealPrimary.withValues(alpha: rungProgress),
        );
        canvas.drawCircle(
          Offset(x2, y),
          3.5,
          Paint()..color = AppTheme.purpleAgent.withValues(alpha: rungProgress),
        );
      }
    }

    canvas.drawPath(path1, strand1Paint);
    canvas.drawPath(path2, strand2Paint);
  }

  @override
  bool shouldRepaint(_DnaHelixPainter old) => old.progress != progress;
}

// â”€â”€ Particle Background Dot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€ Loading Dots â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      builder: (_, __) {
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
