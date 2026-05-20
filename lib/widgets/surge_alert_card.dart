import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SurgeAlertCard extends StatefulWidget {
  final String area;
  final String service;
  final double multiplier;
  final int activeRequests;
  final int availableProviders;
  final VoidCallback onBookNow;
  final VoidCallback onDismiss;

  const SurgeAlertCard({
    super.key,
    required this.area,
    required this.service,
    required this.multiplier,
    required this.activeRequests,
    required this.availableProviders,
    required this.onBookNow,
    required this.onDismiss,
  });

  @override
  State<SurgeAlertCard> createState() => _SurgeAlertCardState();
}

class _SurgeAlertCardState extends State<SurgeAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.surgeColor(widget.multiplier);
    final demandRatio = (widget.activeRequests / 15.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: widget.multiplier >= 1.5
            ? AppTheme.surgeGradient
            : LinearGradient(colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
              ]),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🌊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Surge Active in ${widget.area}',
                        style: TextStyle(
                          color: widget.multiplier >= 1.5 ? Colors.white : color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${widget.activeRequests} requests · ${widget.availableProviders} providers available',
                        style: TextStyle(
                          color: widget.multiplier >= 1.5
                              ? Colors.white70
                              : color.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pulsing multiplier badge
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Container(
                        width: 56 + 8 * _pulseAnim.value,
                        height: 56 + 8 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (widget.multiplier >= 1.5 ? Colors.white : color)
                                .withValues(alpha: 0.3 * (1 - _pulseAnim.value)),
                            width: 2,
                          ),
                        ),
                      ),
                      // Inner badge
                      child!,
                    ],
                  ),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.multiplier.toStringAsFixed(1)}x',
                        style: TextStyle(
                          color: widget.multiplier >= 1.5 ? Colors.white : color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Icon(Icons.close_rounded,
                      color: widget.multiplier >= 1.5 ? Colors.white54 : color.withValues(alpha: 0.5),
                      size: 18),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Demand pressure bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Demand Pressure',
                      style: TextStyle(
                        color: widget.multiplier >= 1.5 ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.activeRequests}/15 requests',
                      style: TextStyle(
                        color: widget.multiplier >= 1.5 ? Colors.white54 : AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: AppTheme.radiusSm,
                  child: LinearProgressIndicator(
                    value: demandRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      widget.multiplier >= 1.5 ? Colors.white.withValues(alpha: 0.8) : color,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Demand for ${widget.service} is ${widget.multiplier >= 2.0 ? "very high" : widget.multiplier >= 1.5 ? "high" : "elevated"} right now. Book now to lock current price.',
              style: TextStyle(
                color: widget.multiplier >= 1.5 ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.multiplier >= 1.5 ? Colors.white70 : color,
                      side: BorderSide(
                        color: widget.multiplier >= 1.5 ? Colors.white30 : color.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Wait', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.onBookNow,
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Book Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.multiplier >= 1.5 ? Colors.white : color,
                      foregroundColor: widget.multiplier >= 1.5 ? color : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}
