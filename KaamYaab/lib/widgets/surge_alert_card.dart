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

  bool get _isHighSurge => widget.multiplier >= 1.5;

  Color get _color => AppTheme.surgeColor(widget.multiplier);

  // FIX: previously onDismiss was passed directly to two separate widgets.
  // A single named handler keeps intent clear and makes it easy to add
  // pre-dismiss logic (analytics, haptics, etc.) in one place.
  void _handleDismiss() => widget.onDismiss();

  @override
  Widget build(BuildContext context) {
    final demandRatio = (widget.activeRequests / 15.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: _isHighSurge
            ? AppTheme.surgeGradient
            : LinearGradient(colors: [
                _color.withValues(alpha: 0.2),
                _color.withValues(alpha: 0.05),
              ]),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: _color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.35),
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
                          color: _isHighSurge ? Colors.white : _color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${widget.activeRequests} requests · ${widget.availableProviders} providers available',
                        style: TextStyle(
                          color: _isHighSurge
                              ? Colors.white70
                              : _color.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPulsingBadge(),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _handleDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: _isHighSurge
                        ? Colors.white54
                        : _color.withValues(alpha: 0.5),
                    size: 18,
                  ),
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
                        color: _isHighSurge ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.activeRequests}/15 requests',
                      style: TextStyle(
                        color: _isHighSurge ? Colors.white54 : AppTheme.textMuted,
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
                      _isHighSurge ? Colors.white.withValues(alpha: 0.8) : _color,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Demand for ${widget.service} is '
              '${widget.multiplier >= 2.0 ? "very high" : _isHighSurge ? "high" : "elevated"}'
              ' right now. Book now to lock current price.',
              style: TextStyle(
                color: _isHighSurge ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isHighSurge ? Colors.white70 : _color,
                      side: BorderSide(
                        color: _isHighSurge
                            ? Colors.white30
                            : _color.withValues(alpha: 0.4),
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
                    label: const Text(
                      'Book Now',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isHighSurge ? Colors.white : _color,
                      foregroundColor: _isHighSurge ? _color : Colors.white,
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

  /// FIX: extracted the pulsing badge into its own method.
  /// The old code used `child!` (force-unwrap) on the AnimatedBuilder's child
  /// parameter. While child is guaranteed non-null when you supply a child:
  /// argument, the `!` is a code smell that trips up linters. Using a local
  /// variable is both safer and clearer.
  Widget _buildPulsingBadge() {
    final badge = Container(
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
            color: _isHighSurge ? Colors.white : _color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _pulseAnim,
      // Pass the static badge as `child` so Flutter doesn't rebuild it every
      // animation tick — only the pulsing ring is redrawn.
      child: badge,
      builder: (_, prebuiltBadge) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56 + 8 * _pulseAnim.value,
            height: 56 + 8 * _pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (_isHighSurge ? Colors.white : _color)
                    .withValues(alpha: 0.3 * (1 - _pulseAnim.value)),
                width: 2,
              ),
            ),
          ),
          // prebuiltBadge is never null — child: badge is always provided.
          prebuiltBadge!,
        ],
      ),
    );
  }
}