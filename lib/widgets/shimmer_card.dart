import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable shimmer loading placeholder that matches ProviderCard dimensions.
class ShimmerCard extends StatefulWidget {
  const ShimmerCard({super.key});

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: The outer AnimatedBuilder previously rebuilt a Container whose own
    // decoration never read the animation value — the animation was only used
    // deep inside each _ShimmerBox. That outer rebuild was wasted work.
    // Now the static Container shell is built once; only _ShimmerBox instances
    // internally subscribe to _anim via their own AnimatedBuilder.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            _ShimmerBox(width: 36, height: 36, radius: 18, anim: _anim),
            const SizedBox(width: 10),
            _ShimmerBox(width: 36, height: 36, radius: 18, anim: _anim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 140, height: 13, radius: 6, anim: _anim),
                  const SizedBox(height: 6),
                  _ShimmerBox(width: 90, height: 10, radius: 5, anim: _anim),
                ],
              ),
            ),
            _ShimmerBox(width: 44, height: 30, radius: 8, anim: _anim),
          ]),
          const SizedBox(height: 14),
          // Stats row
          Row(children: [
            _ShimmerBox(width: 55, height: 22, radius: 6, anim: _anim),
            const SizedBox(width: 8),
            _ShimmerBox(width: 70, height: 22, radius: 6, anim: _anim),
            const SizedBox(width: 8),
            _ShimmerBox(width: 80, height: 22, radius: 6, anim: _anim),
            const Spacer(),
            _ShimmerBox(width: 70, height: 16, radius: 5, anim: _anim),
          ]),
          const SizedBox(height: 12),
          // Rationale bar
          _ShimmerBox(width: double.infinity, height: 38, radius: 8, anim: _anim),
        ],
      ),
    );
  }
}

/// A single shimmer block. Uses its own AnimatedBuilder so only the gradient
/// is rebuilt on each tick — the parent layout is left untouched.
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Animation<double> anim;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + anim.value * 3, 0),
            end: Alignment(-0.5 + anim.value * 3, 0),
            colors: [AppTheme.surfaceDark, AppTheme.cardDark.withValues(alpha: 0.8), AppTheme.surfaceDark],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Full-screen shimmer state used during AI search.
class ShimmerSearchState extends StatelessWidget {
  const ShimmerSearchState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => const ShimmerCard()),
    );
  }
}