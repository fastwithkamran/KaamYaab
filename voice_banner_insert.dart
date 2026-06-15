
// ─────────────────────────────────────────────────────────────────────────────
// _VoiceWorkersFoundBanner — animated reveal banner for voice agent results
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceWorkersFoundBanner extends StatelessWidget {
  final int count;
  final String serviceType;
  const _VoiceWorkersFoundBanner({required this.count, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.tealPrimary.withValues(alpha: 0.20),
            AppTheme.tealDark.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tealPrimary.withValues(alpha: 0.1),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(children: [
        // Pulsing icon container
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
          ),
          child: const Center(child: Text('🎯', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2),
                children: [
                  TextSpan(
                    text: '$count ',
                    style: const TextStyle(color: AppTheme.tealPrimary),
                  ),
                  const TextSpan(
                    text: 'workers found!',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Best $serviceType specialists ranked by AI',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ]),
        ),
        // AI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.tealPrimary.withValues(alpha: 0.2),
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.tealPrimary, size: 13),
            SizedBox(width: 4),
            Text('AI\nMatched',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.tealPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.3)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15);
  }
}
