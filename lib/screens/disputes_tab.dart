import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/ai_service.dart';

class DisputesTab extends StatefulWidget {
  final LanguageService lang;
  const DisputesTab({super.key, required this.lang});

  @override
  State<DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends State<DisputesTab> with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────
  bool _isFiling = false;
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

  // ── Past Cases List ───────────────────────────────────────────────────
  final List<Map<String, dynamic>> _pastCases = [
    {
      'id': 'CR-2026-0091',
      'provider': 'Rashid Khan',
      'type': 'Price Overcharge',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 300.0,
      'date': 'May 10, 2026',
    },
    {
      'id': 'CR-2026-0088',
      'provider': 'Khalid Javed',
      'type': 'No-Show',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 0.0,
      'date': 'Apr 28, 2026',
    },
  ];

  static const _conflictTypes = [
    {'id': 'price_disagreement', 'label': 'Price Dispute', 'urLabel': 'قیمت کا تنازع', 'icon': Icons.attach_money_rounded, 'desc': 'Provider charged more than quoted', 'urDesc': 'کارکن نے طے شدہ قیمت سے زیادہ چارج کیا'},
    {'id': 'quality_complaint', 'label': 'Quality Issue', 'urLabel': 'کام کا معیار', 'icon': Icons.build_circle_rounded, 'desc': 'Work was not up to standard', 'urDesc': 'کام معیار کے مطابق نہیں تھا'},
    {'id': 'no_show', 'label': 'No-Show', 'urLabel': 'غیر حاضری', 'icon': Icons.person_off_rounded, 'desc': 'Provider never arrived', 'urDesc': 'کارکن کام پر نہیں آیا'},
    {'id': 'overrun', 'label': 'Time Overrun', 'urLabel': 'وقت سے زیادہ', 'icon': Icons.timer_off_rounded, 'desc': 'Job took much longer than estimated', 'urDesc': 'کام میں اندازے سے زیادہ وقت لگا'},
    {'id': 'cancellation', 'label': 'Late Cancel', 'urLabel': 'دیر سے منسوخی', 'icon': Icons.cancel_rounded, 'desc': 'Provider cancelled last minute', 'urDesc': 'کارکن نے آخری وقت پر بکنگ منسوخ کی'},
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

  String _t(String en, String ur) => widget.lang.t(en, ur);

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
      _t('📋 Case Intake', '📋 کیس کا اندراج'),
      _t(
        'Filing conflict under "${_conflictTypes.firstWhere((t) => t['id'] == _selectedType)['label']}" category.',
        'تنازع کا اندراج انڈر "${_conflictTypes.firstWhere((t) => t['id'] == _selectedType)['urLabel']}" کیٹیگری۔',
      ),
      _t('Reviewing submitted evidence and description...', 'جمع کرائے گئے شواہد اور تفصیل کا جائزہ لیا جا رہا ہے...'),
    );
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 2: Evidence Analysis
    _addReasoning(
      _t('🔍 Evidence Analysis', '🔍 شواہد کا تجزیہ'),
      _quotedPrice > 0 && _chargedPrice > 0
          ? _t(
              'Quoted: Rs. ${_quotedPrice.toInt()} vs Charged: Rs. ${_chargedPrice.toInt()} — difference of Rs. ${(_chargedPrice - _quotedPrice).abs().toInt()}.',
              'طے شدہ: روپے ${_quotedPrice.toInt()} بمقابلہ چارج شدہ: روپے ${_chargedPrice.toInt()} — فرق روپے ${(_chargedPrice - _quotedPrice).abs().toInt()}۔',
            )
          : _t('No financial figures provided — evaluating based on description.', 'کوئی مالی اعداد و شمار فراہم نہیں کیے گئے — تفصیل کی بنیاد پر جائزہ لیا جا رہا ہے۔'),
      _t('Cross-referencing with booking records and provider history...', 'بکنگ ریکارڈ اور فراہم کنندہ کی ہسٹری کے ساتھ موازنہ کیا جا رہا ہے...'),
    );
    await Future.delayed(const Duration(milliseconds: 1000));

    // Step 3: Provider History Check
    _addReasoning(
      _t('📊 Provider History Check', '📊 فراہم کنندہ کی ہسٹری چیک'),
      _t('Checking provider\'s DNA Score, past dispute count, and cancellation rate.', 'فراہم کنندہ کا DNA اسکور، ماضی کے تنازعات کی تعداد اور منسوخی کی شرح چیک کی جا رہی ہے۔'),
      _t('A pattern of similar complaints weighs against the provider.', 'ملتی جلتی شکایات کا تسلسل فراہم کنندہ کے خلاف جاتا ہے۔'),
    );
    await Future.delayed(const Duration(milliseconds: 900));

    // Step 4: Policy Application
    _addReasoning(
      _t('⚖️ Applying Resolution Policy', '⚖️ تنازع کے حل کی پالیسی لاگو کرنا'),
      _t('Matching case against KaamYaab\'s conflict resolution framework.', 'کیس کو کام یاب کے تنازعات کے حل کے فریم ورک سے ملایا جا رہا ہے۔'),
      _t('Evaluating refund eligibility, penalty thresholds, and escalation criteria...', 'رقم کی واپسی کی اہلیت، جرمانے کی حدود اور انسانی مدد کے معیار کا جائزہ لیا جا رہا ہے...'),
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
      _t('🏛️ Judge\'s Verdict', '🏛️ جج کا فیصلہ'),
      result['reasoning'] as String? ?? _t('Based on evidence and policy, the AI Judge has reached a verdict.', 'شواہد اور پالیسی کی بنیاد پر، جج نے فیصلہ سنا دیا ہے۔'),
      _t('Verdict: ${_verdictLabel(result['verdict'] as String? ?? 'mediated')}', 'فیصلہ: ${_verdictLabel(result['verdict'] as String? ?? 'mediated')}'),
    );

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isJudging = false;
      _verdict = result;
      _step = 3;
    });
    _gavCtrl.forward();
    HapticFeedback.heavyImpact();
  }

  void _addReasoning(String title, String analysis, String conclusion) {
    if (!mounted) return;
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
      case 'user_favor': return _t('✅ Decided in Your Favour', '✅ آپ کے حق میں فیصلہ ہوا');
      case 'provider_favor': return _t('⚖️ Decided for Provider', '⚖️ کارکن کے حق میں فیصلہ ہوا');
      case 'mediated': return _t('🤝 Mediated Settlement', '🤝 ثالثی معاہدہ');
      default: return _t('🚨 Escalated for Review', '🚨 انسانی جائزہ کے لیے بھیجا گیا');
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
      _isFiling = false;
    });
    _descCtrl.clear();
    _quotedCtrl.clear();
    _chargedCtrl.clear();
  }

  void _finishAndSave() {
    if (_verdict != null) {
      final newCase = {
        'id': 'CR-2026-${(1000 + _pastCases.length).toString()}',
        'provider': _t('Assigned Worker', 'مقرر کارکن'),
        'type': _conflictTypes.firstWhere((t) => t['id'] == _selectedType, orElse: () => {'label': 'Dispute'})['label'],
        'status': 'resolved',
        'verdict': _verdict!['verdict'] ?? 'mediated',
        'refund': (_verdict!['refund_amount_pkr'] as num?)?.toDouble() ?? 0.0,
        'date': 'Today',
      };
      setState(() {
        _pastCases.insert(0, newCase);
      });
    }
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFiling) {
      return _buildHistoryView();
    }
    return _buildFilingView();
  }

  // ── History View ──────────────────────────────────────────────────────
  Widget _buildHistoryView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Disputes & Resolutions', 'تنازعات اور ان کا حل'),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('View history or file a new case', 'ماضی کے تنازعات یا نیا کیس فائل کریں'),
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _isFiling = true);
              },
              icon: const Icon(Icons.add, size: 14),
              label: Text(_t('File Case', 'کیس فائل کریں'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._pastCases.map((c) => _PastCaseTile(caseData: c, lang: widget.lang)),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  // ── Filing / Active Case View ─────────────────────────────────────────
  Widget _buildFilingView() {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('AI Dispute Judge', 'ڈیجیٹل جج'),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _t('Conflict Resolution Center', 'مسائل کے فوری حل کا مرکز'),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_verdict != null || _step > 0)
                  GestureDetector(
                    onTap: _resetForm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                        borderRadius: AppTheme.radiusSm,
                        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _t('Reset', 'ری سیٹ'),
                        style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Progress bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _JudgeProgressBar(currentStep: _step, lang: widget.lang),
          ),
        ),

        // Step 0 & 1: Form
        if (_step <= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildConflictForm(),
            ),
          ),

        // Step 2: Judging Steps Animation
        if (_step >= 2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildReasoningPanel(),
            ),
          ),

        // Step 3: Verdict Result
        if (_verdict != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildVerdictCard(),
            ),
          ),

        // Appeal escalation
        if (_verdict != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildEscalationCard(),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildConflictForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('File a Conflict', 'نئی شکایت درج کریں'),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            'Select the type and describe your issue. The AI Judge will analyze the evidence and deliver a fair verdict.',
            'درست زمرہ منتخب کریں اور اپنا مسئلہ بیان کریں۔ ڈیجیٹل جج شواہد کا تجزیہ کر کے منصفانہ فیصلہ کرے گا۔',
          ),
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),

        // Conflict types grid
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
                  Icon(t['icon'] as IconData, color: isSelected ? AppTheme.goldAccent : AppTheme.textMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(t['label'] as String, t['urLabel'] as String),
                          style: TextStyle(
                            color: isSelected ? AppTheme.goldAccent : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _t(t['desc'] as String, t['urDesc'] as String),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.goldAccent, size: 20),
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
            decoration: InputDecoration(
              hintText: _t('Describe what happened in detail...', 'تفصیل سے لکھیں کہ کیا مسئلہ ہوا...'),
              labelText: _t('Conflict Description', 'شکایت کی تفصیل'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quotedCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() => _quotedPrice = double.tryParse(v) ?? 0),
                  decoration: InputDecoration(labelText: _t('Quoted Price (Rs.)', 'طے شدہ رقم (روپے)'), prefixText: 'Rs. '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _chargedCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() => _chargedPrice = double.tryParse(v) ?? 0),
                  decoration: InputDecoration(labelText: _t('Charged Price (Rs.)', 'چارج شدہ رقم (روپے)'), prefixText: 'Rs. '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedType == null || _description.isEmpty || _isJudging) ? null : _startJudging,
              icon: const Text('⚖️', style: TextStyle(fontSize: 18)),
              label: Text(
                _t('Submit to AI Judge', 'ڈیجیٹل جج کو پیش کریں'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
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
                _isJudging ? _t('AI Judge is Deliberating...', 'ڈیجیٹل جج غور کر رہا ہے...') : _t('Judge\'s Reasoning', 'جج کے دلائل'),
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (_isJudging)
                const SizedBox(
                  width: 16,
                  height: 16,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('⚖️', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    _verdictLabel(verdict),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _verdict!['reasoning'] as String? ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 14),
            if (refund > 0) _VerdictRow(_t('Refund Amount', 'رقم کی واپسی'), 'Rs. ${refund.toStringAsFixed(0)}', AppTheme.greenSuccess),
            _VerdictRow(_t('Action Taken', 'کی گئی کارروائی'), action, AppTheme.blueInfo),
            _VerdictRow(_t('Provider Penalty', 'کارکن پر جرمانہ'), penalty, penalty == 'none' ? AppTheme.textMuted : AppTheme.redAlert),
            if (_verdict!['escalate_to_human'] == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.redAlert.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSm,
                  border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_rounded, color: AppTheme.redAlert, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('This case has been escalated to the human review team.', 'یہ کیس انسانی مدد کی ٹیم کو منتقل کر دیا گیا ہے۔'),
                        style: const TextStyle(color: AppTheme.redAlert, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                ),
                child: Text(_t('Finish & Return to History', 'کیس مکمل کریں اور واپس جائیں'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
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
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                _t('Not Satisfied?', 'مطمئن نہیں ہیں؟'),
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'If you disagree with the AI Judge\'s verdict, you can appeal to our human review team. We\'ll investigate your case within 24-48 hours.',
              'اگر آپ جج کے فیصلے سے متفق نہیں ہیں تو انسانی ٹیم سے اپیل کر سکتے ہیں۔ ہم 24-48 گھنٹے میں جائزہ لیں گے۔',
            ),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _launchEmail,
              icon: const Icon(Icons.email_rounded, size: 18),
              label: const Text('Email kaamyaab@gmail.com', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.redAlert,
                side: BorderSide(color: AppTheme.redAlert.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
              ),
            ),
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
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.goldAccent.withValues(alpha: 0.15),
                  border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text('${index + 1}', style: const TextStyle(color: AppTheme.goldAccent, fontSize: 11, fontWeight: FontWeight.w700)),
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
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(step.analysis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.08),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Text(step.conclusion, style: const TextStyle(color: AppTheme.goldAccent, fontSize: 11, fontWeight: FontWeight.w500)),
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
  final LanguageService lang;
  const _JudgeProgressBar({required this.currentStep, required this.lang});

  @override
  Widget build(BuildContext context) {
    final steps = [
      lang.t('Select Type', 'زمرہ منتخب کریں'),
      lang.t('Describe', 'تفصیل لکھیں'),
      lang.t('AI Judging', 'فیصلہ سازی'),
      lang.t('Verdict', 'فیصلہ')
    ];
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final label = e.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep;
        final color = isDone ? AppTheme.greenSuccess : isActive ? AppTheme.goldAccent : AppTheme.textMuted;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
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
                    Text(
                      label,
                      style: TextStyle(color: color, fontSize: 8, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Past Case Tile ────────────────────────────────────────────────────────────
class _PastCaseTile extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final LanguageService lang;
  const _PastCaseTile({required this.caseData, required this.lang});

  String _t(String en, String ur) => lang.t(en, ur);

  @override
  Widget build(BuildContext context) {
    final isWon = caseData['verdict'] == 'user_favor';
    final double refund = caseData['refund'] as double;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isWon ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.12),
            ),
            child: Center(
              child: Icon(Icons.gavel_rounded, color: isWon ? AppTheme.greenSuccess : AppTheme.goldAccent, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${caseData['type']} · ${caseData['provider']}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${caseData['id']} · ${caseData['date']}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isWon ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: Text(
                  isWon ? _t('Won', 'کامیاب') : _t('Mediated', 'ثالثی حل'),
                  style: TextStyle(
                    color: isWon ? AppTheme.greenSuccess : AppTheme.goldAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (refund > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _t('Rs. ${refund.toInt()} refunded', 'روپے ${refund.toInt()} واپس'),
                    style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Verdict Info Row Helper ───────────────────────────────────────────
class _VerdictRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valColor;
  const _VerdictRow(this.label, this.value, this.valColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          Text(value, style: TextStyle(color: valColor, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
