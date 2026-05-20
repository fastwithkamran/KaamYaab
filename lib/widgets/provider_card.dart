import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import 'dna_score_chart.dart';
import '../services/ai_service.dart';

class ProviderCard extends StatefulWidget {
  final ProviderMatch match;
  final int rank;
  final bool isExpanded;
  final String serviceType;
  final double surgeMultiplier;
  final VoidCallback onTap;
  final void Function(double finalPrice, String? note) onBook;

  const ProviderCard({
    super.key,
    required this.match,
    required this.rank,
    required this.isExpanded,
    required this.serviceType,
    required this.surgeMultiplier,
    required this.onTap,
    required this.onBook,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  bool _negotiating = false;
  bool _negotiated = false;
  double? _negotiatedPrice;
  String? _negotiationNote;

  @override
  void initState() {
    super.initState();
    if (widget.rank == 1) {
      _shimmerCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat();
    } else {
      _shimmerCtrl = AnimationController(vsync: this, duration: Duration.zero);
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _availabilityLabel(ServiceProvider p) {
    final today = _dayAbbr(DateTime.now().weekday);
    if (p.availability.contains(today)) return 'Available Today';
    final tomorrow = _dayAbbr(
        DateTime.now().add(const Duration(days: 1)).weekday);
    if (p.availability.contains(tomorrow)) return 'Available Tomorrow';
    return 'Limited Availability';
  }

  Color _availabilityColor(ServiceProvider p) {
    final label = _availabilityLabel(p);
    if (label == 'Available Today') return AppTheme.greenSuccess;
    if (label == 'Available Tomorrow') return AppTheme.tealPrimary;
    return AppTheme.goldAccent;
  }

  String _dayAbbr(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }

  Future<void> _negotiatePrice() async {
    setState(() => _negotiating = true);
    
    final result = await AiService.negotiatePrice(
      providerName: widget.match.provider.name,
      originalQuote: widget.match.quotePkr,
      userOffer: widget.match.quotePkr * 0.88,
      serviceType: widget.serviceType,
      providerDnaScore: widget.match.provider.dnascore,
      surgeMultiplier: widget.surgeMultiplier,
      isRepeatCustomer: false,
    );

    final counterOffer = (result['counter_offer_pkr'] as num).toDouble();
    setState(() {
      _negotiating = false;
      _negotiated = true;
      _negotiatedPrice = counterOffer;
      _negotiationNote = result['reasoning'] as String?;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.match.provider;
    final isTop = widget.rank == 1;
    final availLabel = _availabilityLabel(p);
    final availColor = _availabilityColor(p);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: isTop
                ? AppTheme.tealPrimary.withValues(alpha: 0.5)
                : AppTheme.textMuted.withValues(alpha: 0.15),
            width: isTop ? 1.5 : 1,
          ),
          boxShadow: isTop ? AppTheme.tealGlow : AppTheme.cardShadow,
        ),
        child: Stack(
          children: [
            if (isTop)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: AppTheme.radiusLg,
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-2 + _shimmerCtrl.value * 4, -0.5),
                          end: Alignment(-1 + _shimmerCtrl.value * 4, 0.5),
                          colors: [
                            Colors.transparent,
                            AppTheme.tealPrimary.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: isTop ? AppTheme.goldGradient : null,
                          color: isTop ? null : AppTheme.surfaceDark,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#${widget.rank}',
                            style: TextStyle(
                              color: isTop ? Colors.black : AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
                        child: Text(
                          p.name.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.tealPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded,
                                      color: AppTheme.blueInfo, size: 15),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.area} · ${widget.match.distanceKm.toStringAsFixed(1)}km · ETA ${widget.match.etaMinutes}min',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: availColor.withValues(alpha: 0.1),
                                borderRadius: AppTheme.radiusSm,
                                border: Border.all(color: availColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: availColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    availLabel,
                                    style: TextStyle(
                                      color: availColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.dnaScoreColor(p.dnascore).withValues(alpha: 0.15),
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: AppTheme.dnaScoreColor(p.dnascore).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${p.dnascore}',
                              style: TextStyle(
                                color: AppTheme.dnaScoreColor(p.dnascore),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DNA',
                            style: TextStyle(
                              color: AppTheme.dnaScoreColor(p.dnascore).withValues(alpha: 0.6),
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _StatChip(
                        icon: Icons.star_rounded,
                        value: p.rating.toStringAsFixed(1),
                        color: AppTheme.goldAccent,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.check_circle_outline_rounded,
                        value: '${p.completedJobs} jobs',
                        color: AppTheme.greenSuccess,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.currency_rupee,
                        value: 'Rs. ${(_negotiatedPrice ?? widget.match.quotePkr).toStringAsFixed(0)}',
                        color: AppTheme.tealPrimary,
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.match.matchScore.toStringAsFixed(0)}% match',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 70,
                            child: LinearProgressIndicator(
                              value: widget.match.matchScore / 100,
                              backgroundColor: AppTheme.surfaceDark,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.dnaScoreColor(p.dnascore),
                              ),
                              minHeight: 4,
                              borderRadius: AppTheme.radiusSm,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.purpleAgent.withValues(alpha: 0.08),
                    borderRadius: AppTheme.radiusSm,
                    border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, size: 14, color: AppTheme.textPrimary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.match.rankRationale,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: widget.isExpanded
                      ? Column(
                          children: [
                            const Divider(color: Color(0xFF1E293B), height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: DnaScoreChart(provider: p, size: 200),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: p.skills.map((s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                                    borderRadius: AppTheme.radiusSm,
                                    border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(s,
                                      style: const TextStyle(
                                        color: AppTheme.tealLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      )),
                                )).toList(),
                              ),
                            ),
                            if (p.certifications.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded,
                                        color: AppTheme.goldAccent, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.certifications.join(' · '),
                                        style: const TextStyle(
                                          color: AppTheme.goldAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_negotiated && _negotiationNote != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.greenSuccess.withValues(alpha: 0.08),
                                    borderRadius: AppTheme.radiusSm,
                                    border: Border.all(color: AppTheme.greenSuccess.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.handshake_rounded, color: AppTheme.greenSuccess, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(_negotiationNote!,
                                        style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 11))),
                                  ]),
                                ),
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _negotiating ? null : _negotiatePrice,
                                    icon: _negotiating
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary))
                                        : const Icon(Icons.handshake_rounded, size: 16, color: AppTheme.tealPrimary),
                                    label: Text(_negotiating ? 'Negotiating...' : 'Negotiate Better Price',
                                        style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppTheme.tealPrimary),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onBook(_negotiatedPrice ?? widget.match.quotePkr, _negotiationNote);
                                  },
                                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                                  label: Text(
                                    'Book ${p.name.split(' ').first} · Rs. ${(_negotiatedPrice ?? widget.match.quotePkr).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isTop
                                        ? AppTheme.tealPrimary
                                        : AppTheme.cardDark,
                                    foregroundColor:
                                        isTop ? Colors.white : AppTheme.tealPrimary,
                                    side: isTop
                                        ? null
                                        : const BorderSide(color: AppTheme.tealPrimary),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.textMuted, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Tap to see DNA chart & book',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ).animate()
          .fadeIn(delay: Duration(milliseconds: widget.rank * 100))
          .slideY(begin: 0.05),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
