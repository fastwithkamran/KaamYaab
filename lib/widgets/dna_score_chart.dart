import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';

/// Hexagonal radar chart visualising the 8 DNA score factors.
class DnaScoreChart extends StatefulWidget {
  final ServiceProvider provider;
  final double size;

  const DnaScoreChart({super.key, required this.provider, this.size = 180});

  @override
  State<DnaScoreChart> createState() => _DnaScoreChartState();
}

class _DnaScoreChartState extends State<DnaScoreChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final factors = [
      _Factor('On-Time',    p.onTimeRate,                            AppTheme.tealPrimary),
      _Factor('Recency',    (p.reviewCount / 500.0).clamp(0, 1),    AppTheme.blueInfo),
      _Factor('Completion', p.completionRate,                        AppTheme.greenSuccess),
      _Factor('Skill',      (p.skills.length / 5.0).clamp(0, 1),   AppTheme.goldAccent),
      _Factor('No Cancel',  1 - p.cancellationRate,                 AppTheme.purpleAgent),
      _Factor('Fairness',   p.priceFairnessScore,                   AppTheme.tealLight),
    ];

    final tierColor = AppTheme.dnaScoreColor(p.dnascore);

    return Column(
      children: [
        // Radar chart with outer tier ring
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer tier ring
            AnimatedBuilder(
              animation: _anim,
              builder: (_, _) => CustomPaint(
                size: Size(widget.size + 16, widget.size + 16),
                painter: _TierRingPainter(tierColor, _anim.value),
              ),
            ),
            // Main radar chart
            AnimatedBuilder(
              animation: _anim,
              builder: (_, _) => CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _HexRadarPainter(factors, _anim.value, p.dnascore),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Score + label badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tierColor.withValues(alpha: 0.2), tierColor.withValues(alpha: 0.05)],
            ),
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: tierColor.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🦠 DNA: ${p.dnascore}',
                style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusSm,
              ),
              child: Text(
                p.dnaLabel,
                style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Factor grid (2-column)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: factors.map((f) => _FactorChip(factor: f)).toList(),
        ),
      ],
    );
  }
}

class _Factor {
  final String label;
  final double value; // 0.0–1.0
  final Color color;
  const _Factor(this.label, this.value, this.color);
}

// ── Tier ring (thin outer circle colored by DNA tier) ─────────────────────────
class _TierRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  _TierRingPainter(this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;
    final sweepAngle = 2 * pi * progress;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_TierRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _HexRadarPainter extends CustomPainter {
  final List<_Factor> factors;
  final double progress;
  final int dnaScore;

  _HexRadarPainter(this.factors, this.progress, this.dnaScore);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2 - 22;
    final n = factors.length;

    // Grid rings
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double ring = 0.25; ring <= 1.0; ring += 0.25) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = (2 * pi / n) * i - pi / 2;
        final x = cx + maxR * ring * cos(angle);
        final y = cy + maxR * ring * sin(angle);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      final angle = (2 * pi / n) * i - pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxR * cos(angle), cy + maxR * sin(angle)),
        axisPaint,
      );
    }

    // Data polygon
    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final angle = (2 * pi / n) * i - pi / 2;
      final r = maxR * factors[i].value * progress;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? dataPath.moveTo(x, y) : dataPath.lineTo(x, y);
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.tealPrimary.withValues(alpha: 0.4 * progress),
            AppTheme.purpleAgent.withValues(alpha: 0.15 * progress),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppTheme.tealPrimary.withValues(alpha: 0.8 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Data point dots + labels
    final textPainterFactory = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < n; i++) {
      final angle = (2 * pi / n) * i - pi / 2;
      final r = maxR * factors[i].value * progress;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);

      canvas.drawCircle(Offset(x, y), 4, Paint()..color = factors[i].color);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);

      // Factor label at axis tip
      if (progress > 0.5) {
        final labelR = maxR + 14;
        final lx = cx + labelR * cos(angle);
        final ly = cy + labelR * sin(angle);
        textPainterFactory
          ..text = TextSpan(
            text: factors[i].label,
            style: TextStyle(
              color: factors[i].color.withValues(alpha: progress),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          )
          ..layout();
        textPainterFactory.paint(
          canvas,
          Offset(lx - textPainterFactory.width / 2,
              ly - textPainterFactory.height / 2),
        );
      }
    }

    // Center DNA score
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${(dnaScore * progress).toInt()}\n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(
            text: 'DNA',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_HexRadarPainter old) =>
      old.progress != progress || old.dnaScore != dnaScore;
}

class _FactorChip extends StatelessWidget {
  final _Factor factor;
  const _FactorChip({required this.factor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: factor.color.withValues(alpha: 0.08),
        borderRadius: AppTheme.radiusSm,
        border: Border.all(color: factor.color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: factor.color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${factor.label} ${(factor.value * 100).toInt()}%',
            style: TextStyle(color: factor.color, fontSize: 8, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
