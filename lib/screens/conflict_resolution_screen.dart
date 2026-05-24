import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() => _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────
  int _step = 0; // 0=select type, 1=describe, 2=AI judging, 3=verdict
  String? _selectedType;
  String _description = '';
  double _quotedPrice = 0;
  double _chargedPrice = 0;
  bool _isJudging = false;
  Map<String, dynamic>? _verdict;
  final List<_JudgeReasoningStep> _reasoningSteps = [];

  final _descCtrl = TextEditingController();
  final _quotedCtrl = TextEditingController();
  final _chargedCtrl = TextEditingController();

  late AnimationController _gavCtrl;
  late Animation<double> _gavAnim;
  late AnimationController _pulseCtrl;

  // ── Past cases ────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _pastCases = [
    {
      'id': 'CR-2024-0091',
      'provider': 'Rashid Khan',
      'type': 'Price Overcharge',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 300.0,
      'date': 'May 10, 2026',
    },
    {
      'id': 'CR-2024-0088',
      'provider': 'Khalid Javed',
      'type': 'No-Show',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 0.0,
      'date': 'Apr 28, 2026',
    },
  ];

  static const _conflictTypes = [
    {'id': 'price_disagreement', 'label': 'Price Dispute', 'icon': Icons.attach_money_rounded, 'desc': 'Provider charged more than quoted'},
    {'id': 'quality_complaint', 'label': 'Quality Issue', 'icon': Icons.build_circle_rounded, 'desc': 'Work was not up to standard'},
    {'id': 'no_show', 'label': 'No-Show', 'icon': Icons.person_off_rounded, 'desc': 'Provider never arrived'},
    {'id': 'overrun', 'label': 'Time Overrun', 'icon': Icons.timer_off_rounded, 'desc': 'Job took much longer than estimated'},
    {'id': 'cancellation', 'label': 'Late Cancel', 'icon': Icons.cancel_rounded, 'desc': 'Provider cancelled last minute'},
  ];

  @override
  void initState() {
    super.initState();
    _gavCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _gavAnim = CurvedAnimation(parent: _gavCtrl, curve: Curves.elasticOut);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _quotedCtrl.dispose();
    _chargedCtrl.dispose();
    _gavCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── AI Judge Flow ─────────────────────────────────────────────────────
  Future<void> _startJudging() async {
    if (_selectedType == null || _description.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isJudging = true;
      _step = 2;
      _verdict = null;
      _reasoningSteps.clear();
    });
    _gavCtrl.reset();

    // Step 1: Intake
    _addReasoning(
      '📋 Case Intake',
      'Filing conflict under "${_conflictTypes.firstWhere((t) => t['id'] == _selectedType)['label']}" category.',
      'Reviewing submitted evidence and description...',
    );
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 2: Evidence Analysis
    _addReasoning(
      '🔍 Evidence Analysis',
      _quotedPrice > 0 && _chargedPrice > 0
          ? 'Quoted: Rs. ${_quotedPrice.toInt()} vs Charged: Rs. ${_chargedPrice.toInt()} — difference of Rs. ${(_chargedPrice - _quotedPrice).abs().toInt()}.'
          : 'No financial figures provided — evaluating based on description.',
      'Cross-referencing with booking records and provider history...',
    );
    await Future.delayed(const Duration(milliseconds: 1000));

    // Step 3: Provider History Check
    _addReasoning(
      '📊 Provider History Check',
      'Checking provider\'s DNA Score, past dispute count, and cancellation rate.',
      'A pattern of similar complaints weighs against the provider.',
    );
    await Future.delayed(const Duration(milliseconds: 900));

    // Step 4: Policy Application
    _addReasoning(
      '⚖️ Applying Resolution Policy',
      'Matching case against KaamYaab\'s conflict resolution framework.',
      'Evaluating refund eligibility, penalty thresholds, and escalation criteria...',
    );
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 5: Get AI verdict
    final result = await AiService.analyzeDispute(
      disputeType: _selectedType!,
      description: _description,
      quotedPrice: _quotedPrice,
      chargedPrice: _chargedPrice,
      providerDnaScore: 720,
      providerDisputeCount: 3,
    );

    // Step 5: Verdict
    _addReasoning(
      '🏛️ Judge\'s Verdict',
      result['reasoning'] as String? ?? 'Based on evidence and policy, the AI Judge has reached a verdict.',
      'Verdict: ${_verdictLabel(result['verdict'] as String? ?? 'mediated')}',
    );

    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _isJudging = false;
      _verdict = result;
      _step = 3;
    });
    _gavCtrl.forward();
    HapticFeedback.heavyImpact();
  }

  void _addReasoning(String title, String analysis, String conclusion) {
    setState(() {
      _reasoningSteps.add(_JudgeReasoningStep(
        title: title,
        analysis: analysis,
        conclusion: conclusion,
        timestamp: DateTime.now(),
      ));
    });
  }

  String _verdictLabel(String v) {
    switch (v) {
      case 'user_favor': return '✅ Decided in Your Favour';
      case 'provider_favor': return '⚖️ Decided for Provider';
      case 'mediated': return '🤝 Mediated Settlement';
      default: return '🚨 Escalated for Review';
    }
  }

  Color _verdictColor(String v) {
    switch (v) {
      case 'user_favor': return AppTheme.greenSuccess;
      case 'provider_favor': return AppTheme.goldAccent;
      case 'mediated': return AppTheme.blueInfo;
      default: return AppTheme.redAlert;
    }
  }

  Future<void> _launchEmail() async {
    final subject = Uri.encodeComponent('Conflict Appeal - ${_selectedType ?? "General"}');
    final body = Uri.encodeComponent(
      'Hi KaamYaab Team,\n\n'
      'I am unsatisfied with the AI Judge\'s verdict on my conflict.\n\n'
      'Conflict Type: ${_conflictTypes.firstWhere((t) => t['id'] == _selectedType, orElse: () => {'id': '', 'label': 'N/A'})['label']}\n'
      'Description: $_description\n'
      'Quoted Price: Rs. ${_quotedPrice.toInt()}\n'
      'Charged Price: Rs. ${_chargedPrice.toInt()}\n'
      'AI Verdict: ${_verdict?['verdict'] ?? 'N/A'}\n\n'
      'Please review my case.\n\nThank you.',
    );
    final uri = Uri.parse('mailto:kaamyaab@gmail.com?subject=$subject&body=$body');
    try {
      await launchUrl(uri);
    } catch (_) {
      // Fallback: copy email to clipboard
      await Clipboard.setData(const ClipboardData(text: 'kaamyaab@gmail.com'));
    }
  }

  void _resetForm() {
    HapticFeedback.selectionClick();
    setState(() {
      _step = 0;
      _selectedType = null;
      _description = '';
      _quotedPrice = 0;
      _chargedPrice = 0;
      _verdict = null;
      _reasoningSteps.clear();
    });
    _descCtrl.clear();
    _quotedCtrl.clear();
    _chargedCtrl.clear();
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Progress Bar ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _JudgeProgressBar(currentStep: _step),
                ).animate().fadeIn(delay: 50.ms),
              ),

              // ── Past Cases ─────────────────────────────────────────
              if (_step == 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Past Resolutions',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        ..._pastCases.map((c) => _PastCaseTile(caseData: c)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ),

              // ── Step 0 & 1: Conflict Type + Description ────────────
              if (_step <= 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildConflictForm(),
                  ).animate().fadeIn(delay: 150.ms),
                ),

              // ── Step 2: AI Judge Reasoning (live) ──────────────────
              if (_step >= 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildReasoningPanel(),
                  ).animate().fadeIn(),
                ),

              // ── Step 3: Verdict ────────────────────────────────────
              if (_verdict != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildVerdictCard(),
                  ),
                ),

              // ── Unsatisfied? Email ─────────────────────────────────
              if (_verdict != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildEscalationCard(),
                  ).animate().fadeIn(delay: 600.ms),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.goldAccent.withValues(alpha: 0.3),
                AppTheme.redAlert.withValues(alpha: 0.15),
              ]),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text('⚖️', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('AI Judge',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
              Text('Conflict Resolution Center',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
          if (_verdict != null || _step > 0)
            GestureDetector(
              onTap: _resetForm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSm,
                  border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
                ),
                child: const Text('New Case',
                    style: TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildConflictForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('File a Conflict',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Select the type and describe your issue. The AI Judge will analyze the evidence and deliver a fair verdict.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
        const SizedBox(height: 16),

        // Type selector grid
        ..._conflictTypes.map((t) {
          final isSelected = _selectedType == t['id'];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedType = t['id'] as String;
                if (_step < 1) _step = 1;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.goldAccent.withValues(alpha: 0.08) : AppTheme.cardDark,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: isSelected ? AppTheme.goldAccent : AppTheme.textMuted.withValues(alpha: 0.15),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(t['icon'] as IconData,
                      color: isSelected ? AppTheme.goldAccent : AppTheme.textMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['label'] as String,
                          style: TextStyle(
                            color: isSelected ? AppTheme.goldAccent : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                      Text(t['desc'] as String,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ]),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, color: AppTheme.goldAccent, size: 20),
                ],
              ),
            ),
          );
        }),

        if (_step >= 1) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: (v) => setState(() => _description = v),
            decoration: const InputDecoration(
              hintText: 'Describe what happened in detail...',
              labelText: 'Conflict Description',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _quotedCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _quotedPrice = double.tryParse(v) ?? 0),
                decoration: const InputDecoration(labelText: 'Quoted Price (Rs.)', prefixText: 'Rs. '),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _chargedCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _chargedPrice = double.tryParse(v) ?? 0),
                decoration: const InputDecoration(labelText: 'Charged Price (Rs.)', prefixText: 'Rs. '),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedType == null || _description.isEmpty || _isJudging)
                  ? null
                  : _startJudging,
              icon: const Text('⚖️', style: TextStyle(fontSize: 18)),
              label: const Text('Submit to AI Judge',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReasoningPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Opacity(
                  opacity: _isJudging ? 0.5 + 0.5 * _pulseCtrl.value : 1.0,
                  child: child,
                ),
                child: const Text('🏛️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 8),
              Text(
                _isJudging ? 'AI Judge is Deliberating...' : 'Judge\'s Reasoning',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (_isJudging)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ..._reasoningSteps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final isLast = i == _reasoningSteps.length - 1;
            return _ReasoningStepWidget(step: step, isLast: isLast, index: i);
          }),
        ],
      ),
    );
  }

  Widget _buildVerdictCard() {
    final verdict = _verdict!['verdict'] as String? ?? 'mediated';
    final color = _verdictColor(verdict);
    final refund = (_verdict!['refund_amount_pkr'] as num?)?.toDouble() ?? 0.0;
    final penalty = _verdict!['penalty_to_provider'] as String? ?? 'none';
    final action = _verdict!['action'] as String? ?? 'Under review';

    return AnimatedBuilder(
      animation: _gavAnim,
      builder: (_, child) => Transform.scale(
        scale: 0.85 + 0.15 * _gavAnim.value,
        child: Opacity(opacity: _gavAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 24)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Verdict banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('⚖️', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                _verdictLabel(verdict),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Reasoning
          Text(_verdict!['reasoning'] as String? ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),

          // Details
          if (refund > 0)
            _VerdictRow('Refund Amount', 'Rs. ${refund.toStringAsFixed(0)}', AppTheme.greenSuccess),
          _VerdictRow('Action', action, AppTheme.blueInfo),
          _VerdictRow('Provider Penalty', penalty, penalty == 'none' ? AppTheme.textMuted : AppTheme.redAlert),

          if (_verdict!['escalate_to_human'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.redAlert.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.support_agent_rounded, color: AppTheme.redAlert, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('This case has been escalated to the human review team.',
                    style: TextStyle(color: AppTheme.redAlert, fontSize: 12))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildEscalationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.surfaceDark,
          AppTheme.redAlert.withValues(alpha: 0.05),
        ]),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.mail_outline_rounded, color: AppTheme.textSecondary, size: 20),
            SizedBox(width: 8),
            Text('Not Satisfied?',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'If you disagree with the AI Judge\'s verdict, you can appeal to our human review team. We\'ll investigate your case within 24-48 hours.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _launchEmail,
              icon: const Icon(Icons.email_rounded, size: 18),
              label: const Text('Email kaamyaab@gmail.com',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.redAlert,
                side: BorderSide(color: AppTheme.redAlert.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('📧 kaamyaab@gmail.com',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Judge Reasoning Step Model ────────────────────────────────────────────────
class _JudgeReasoningStep {
  final String title;
  final String analysis;
  final String conclusion;
  final DateTime timestamp;

  _JudgeReasoningStep({
    required this.title,
    required this.analysis,
    required this.conclusion,
    required this.timestamp,
  });
}

// ── Reasoning Step Widget ─────────────────────────────────────────────────────
class _ReasoningStepWidget extends StatelessWidget {
  final _JudgeReasoningStep step;
  final bool isLast;
  final int index;

  const _ReasoningStepWidget({required this.step, required this.isLast, required this.index});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.goldAccent.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(color: AppTheme.goldAccent, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppTheme.goldAccent.withValues(alpha: 0.2),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(step.analysis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.08),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Text(step.conclusion,
                        style: const TextStyle(color: AppTheme.goldAccent, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 200)).fadeIn().slideY(begin: 0.1);
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────
class _JudgeProgressBar extends StatelessWidget {
  final int currentStep;
  const _JudgeProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Select Type', 'Describe', 'AI Judging', 'Verdict'];
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final label = e.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep;
        final color = isDone ? AppTheme.greenSuccess : isActive ? AppTheme.goldAccent : AppTheme.textMuted;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color, width: isActive ? 2 : 1),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check_rounded, color: color, size: 13)
                        : Text('${i + 1}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
            if (i < steps.length - 1)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 1.5,
                  color: isDone ? AppTheme.greenSuccess.withValues(alpha: 0.6) : AppTheme.textMuted.withValues(alpha: 0.2),
                  margin: const EdgeInsets.only(bottom: 18),
                ),
              ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Past Case Tile ────────────────────────────────────────────────────────────
class _PastCaseTile extends StatelessWidget {
  final Map<String, dynamic> caseData;
  const _PastCaseTile({required this.caseData});

  @override
  Widget build(BuildContext context) {
    final isWon = caseData['verdict'] == 'user_favor';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isWon ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.12),
          ),
          child: Center(child: Text(isWon ? '✅' : '🤝', style: const TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${caseData['type']} · ${caseData['provider']}',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${caseData['id']} · ${caseData['date']}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isWon ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.15),
            borderRadius: AppTheme.radiusSm,
          ),
          child: Text(
            isWon ? 'Won' : 'Mediated',
            style: TextStyle(
              color: isWon ? AppTheme.greenSuccess : AppTheme.goldAccent,
              fontSize: 10, fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Verdict Detail Row ────────────────────────────────────────────────────────
class _VerdictRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _VerdictRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        Expanded(child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    );
  }
}
