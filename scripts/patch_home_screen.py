import sys

path = r'd:\GitHub_Repository\KaamYaab\lib\screens\home_screen.dart'

# Read and normalize line endings
content = open(path, 'r', encoding='utf-8').read()
content = content.replace('\r\n', '\n').replace('\r', '\n')

# ── Change 1: Replace AI Loading Indicator ─────────────────────────────────
old1 = '''                    // AI Loading Indicator
                    if (_isAILoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: Row(children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary)),
                            SizedBox(width: 12),
                            Text('Agent is thinking...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ]),
                        ),
                      ),'''

new1 = '''                    // AI Agentic Loading Phase Widget
                    if (_isAILoading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: _AgentSearchingWidget(),
                        ),
                      ),'''

if old1 not in content:
    print("ERROR: Change 1 target not found!")
    sys.exit(1)
content = content.replace(old1, new1, 1)
print("✅ Change 1 applied: AI Loading Indicator replaced")

# ── Change 2: Replace Best matches label ──────────────────────────────────
old2 = '''                    // Search Results
                    if (_matches.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
                          child: Text('Best matches for you:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),'''

new2 = '''                    // Search Results — AI-found reveal banner + cards
                    if (_matches.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: _WorkersFoundBanner(
                            count: _matches.length,
                            serviceType: _currentRequest?.serviceType ?? 'Service',
                          ),
                        ),
                      ),'''

if old2 not in content:
    print("ERROR: Change 2 target not found!")
    sys.exit(1)
content = content.replace(old2, new2, 1)
print("✅ Change 2 applied: Best matches label replaced with _WorkersFoundBanner")

# ── Change 3: Add two new widget classes before _ChatBubble ───────────────
old3 = '''class _ChatBubble extends StatelessWidget {'''

new3 = '''// ── Agent Searching Widget — animated phases ────────────────────────────────
class _AgentSearchingWidget extends StatefulWidget {
  const _AgentSearchingWidget();
  @override
  State<_AgentSearchingWidget> createState() => _AgentSearchingWidgetState();
}

class _AgentSearchingWidgetState extends State<_AgentSearchingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phaseIndex = 0;
  final _phases = [
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
            width: 38,
            height: 38,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
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
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'KaamYaab Agent is working...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.tealPrimary.withValues(alpha: 0.6 + 0.4 * _ctrl.value),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Workers Found Banner — animated reveal ──────────────────────────────────
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
          ),
          child: const Text('🎯', style: TextStyle(fontSize: 20)),
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
                    style: TextStyle(color: AppTheme.tealPrimary),
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
            Text('AI', style: TextStyle(color: AppTheme.tealPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }
}

class _ChatBubble extends StatelessWidget {'''

if old3 not in content:
    print("ERROR: Change 3 target not found!")
    sys.exit(1)
content = content.replace(old3, new3, 1)
print("✅ Change 3 applied: _AgentSearchingWidget and _WorkersFoundBanner added")

# ── Change 4: Check dart:async import (should already exist) ──────────────
if "import 'dart:async';" in content:
    print("✅ Change 4: dart:async import already present — no action needed")
else:
    # Insert after the first line
    content = "import 'dart:async';\n" + content
    print("✅ Change 4 applied: dart:async import added at top")

# Write back (keep LF endings — Flutter handles both)
open(path, 'w', encoding='utf-8').write(content)
print("\n🎉 All changes written to home_screen.dart successfully!")
