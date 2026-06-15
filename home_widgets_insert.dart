
// ─────────────────────────────────────────────────────────────────────────────
// _AgentSearchingWidget — animated cycling phase display during AI search
// ─────────────────────────────────────────────────────────────────────────────
class _AgentSearchingWidget extends StatefulWidget {
  const _AgentSearchingWidget();
  @override
  State<_AgentSearchingWidget> createState() => _AgentSearchingWidgetState();
}

class _AgentSearchingWidgetState extends State<_AgentSearchingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phaseIndex = 0;
  static const _phases = [
    ('🔍', 'Scanning nearby workers...'),
    ('⚡', 'Matching by skill & rating...'),
    ('📊', 'Ranking by DNA Score...'),
    ('✅', 'Verifying availability...'),
  ];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _phaseIndex = (_phaseIndex + 1) % _phases.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phases[_phaseIndex];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: AppTheme.tealPrimary.withValues(alpha: 0.2 + 0.15 * _ctrl.value),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.tealPrimary.withValues(alpha: 0.06 * _ctrl.value),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.tealPrimary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.tealPrimary.withValues(alpha: 0.3 + 0.2 * _ctrl.value),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(phase.$1, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  phase.$2,
                  key: ValueKey(_phaseIndex),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 3),
              const Text('KaamYaab Agent is working...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.tealPrimary.withValues(alpha: 0.7),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkersFoundBanner — animated teal reveal card after AI finds workers
// ─────────────────────────────────────────────────────────────────────────────
class _WorkersFoundBanner extends StatelessWidget {
  final int count;
  final String serviceType;
  const _WorkersFoundBanner({required this.count, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.tealPrimary.withValues(alpha: 0.18),
            AppTheme.tealDark.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tealPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
          ),
          child: const Center(child: Text('🎯', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: '$count ',
                    style: const TextStyle(color: AppTheme.tealPrimary),
                  ),
                  const TextSpan(
                    text: 'verified workers found',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'AI ranked best $serviceType specialists near you',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.tealPrimary.withValues(alpha: 0.2),
            borderRadius: AppTheme.radiusSm,
            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.tealPrimary, size: 12),
            SizedBox(width: 4),
            Text('AI', style: TextStyle(
                color: AppTheme.tealPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }
}

