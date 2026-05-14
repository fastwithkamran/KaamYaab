import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';

class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen>
    with SingleTickerProviderStateMixin {
  int _progressStep = 0; // 0=select, 1=describe, 2=verdict
  String? _selectedType;
  String _description = '';
  double _quotedPrice = 0;
  double _chargedPrice = 0;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;

  final _descCtrl = TextEditingController();
  final _quotedCtrl = TextEditingController();
  final _chargedCtrl = TextEditingController();

  late AnimationController _verdictCtrl;
  late Animation<double> _verdictScale;
  late Animation<double> _verdictFade;

  final List<Map<String, String>> _disputeTypes = [
    {'id': 'price_disagreement', 'label': 'Price Dispute',    'icon': 'ðŸ’°'},
    {'id': 'quality_complaint',  'label': 'Quality Issue',    'icon': 'âš ï¸'},
    {'id': 'no_show',            'label': 'Provider No-Show', 'icon': 'ðŸ‘»'},
    {'id': 'overrun',            'label': 'Time Overrun',     'icon': 'â°'},
    {'id': 'cancellation',       'label': 'Cancellation',     'icon': 'âŒ'},
  ];

  final List<Map<String, dynamic>> _pastDisputes = [
    {
      'id': 'D-2024',
      'provider': 'Rashid Khan',
      'type': 'Price Dispute',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 300.0,
      'date': 'May 10, 2026',
    },
    {
      'id': 'D-2023',
      'provider': 'Khalid Javed',
      'type': 'No-Show',
      'status': 'resolved',
      'verdict': 'user_favor',
      'refund': 0.0,
      'date': 'Apr 28, 2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    _verdictCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _verdictScale = CurvedAnimation(parent: _verdictCtrl, curve: Curves.elasticOut);
    _verdictFade  = CurvedAnimation(parent: _verdictCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _quotedCtrl.dispose();
    _chargedCtrl.dispose();
    _verdictCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeDispute() async {
    if (_selectedType == null || _description.isEmpty) return;
    setState(() { _isAnalyzing = true; _result = null; _progressStep = 2; });
    _verdictCtrl.reset();

    final result = await GeminiService.analyzeDispute(
      disputeType: _selectedType!,
      description: _description,
      quotedPrice: _quotedPrice,
      chargedPrice: _chargedPrice,
      providerDnaScore: 720,
      providerDisputeCount: 3,
    );

    setState(() { _isAnalyzing = false; _result = result; });
    _verdictCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.redAlert.withValues(alpha: 0.12),
                          borderRadius: AppTheme.radiusMd,
                          border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.3)),
                        ),
                        child: const Center(child: Text('âš–ï¸', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Dispute Center',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                        Text('AI-powered resolution engine',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ]),
                    ],
                  ),
                ).animate().fadeIn(),
              ),

              // â”€â”€ Progress Steps â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _ProgressStepper(currentStep: _progressStep),
                ).animate().fadeIn(delay: 50.ms),
              ),

              // â”€â”€ Past Cases â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Past Cases',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      ..._pastDisputes.map((d) => _PastDisputeTile(dispute: d)),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ),

              // â”€â”€ New Dispute Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('File New Dispute',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),

                      // Step 1: Type selector
                      _FormSection(
                        step: 1,
                        title: 'Select Dispute Type',
                        isActive: _progressStep == 0,
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _disputeTypes.map((t) {
                            final selected = _selectedType == t['id'];
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedType = t['id'];
                                if (_progressStep < 1) _progressStep = 1;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? AppTheme.redAlert.withValues(alpha: 0.15) : AppTheme.cardDark,
                                  borderRadius: AppTheme.radiusMd,
                                  border: Border.all(
                                    color: selected ? AppTheme.redAlert : AppTheme.textMuted.withValues(alpha: 0.2),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(t['icon']!, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(t['label']!,
                                      style: TextStyle(
                                        color: selected ? AppTheme.redAlert : AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      )),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Step 2: Description
                      _FormSection(
                        step: 2,
                        title: 'Describe the Issue',
                        isActive: _progressStep == 1,
                        child: Column(
                          children: [
                            TextField(
                              controller: _descCtrl,
                              maxLines: 3,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              onChanged: (v) => setState(() => _description = v),
                              decoration: const InputDecoration(hintText: 'Describe what happened...', labelText: 'Description'),
                            ),
                            const SizedBox(height: 10),
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
                              const SizedBox(width: 10),
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Analyze button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isAnalyzing || _selectedType == null || _description.isEmpty)
                              ? null
                              : _analyzeDispute,
                          icon: _isAnalyzing
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.gavel_rounded, size: 18),
                          label: Text(_isAnalyzing ? 'Dispute Agent Analyzing...' : 'Analyze with Dispute Agent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedType != null && _description.isNotEmpty
                                ? AppTheme.redAlert
                                : AppTheme.textMuted.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),

              // â”€â”€ Animated Verdict â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (_result != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: AnimatedBuilder(
                      animation: _verdictCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _verdictFade.value,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * _verdictScale.value,
                          child: child,
                        ),
                      ),
                      child: _DisputeResultCard(result: _result!),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Progress Stepper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProgressStepper extends StatelessWidget {
  final int currentStep;
  const _ProgressStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Select Type', 'Describe', 'AI Verdict'];
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final label = e.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep;
        final color = isDone ? AppTheme.greenSuccess
            : isActive ? AppTheme.redAlert
            : AppTheme.textMuted;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(color: color, width: isActive ? 2 : 1),
                      ),
                      child: Center(
                        child: isDone
                            ? Icon(Icons.check_rounded, color: AppTheme.greenSuccess, size: 14)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 1.5,
                    color: isDone
                        ? AppTheme.greenSuccess.withValues(alpha: 0.6)
                        : AppTheme.textMuted.withValues(alpha: 0.2),
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

// â”€â”€ Form Section with Step Number â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FormSection extends StatelessWidget {
  final int step;
  final String title;
  final bool isActive;
  final Widget child;

  const _FormSection({
    required this.step,
    required this.title,
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.cardDark : AppTheme.surfaceDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(
          color: isActive ? AppTheme.redAlert.withValues(alpha: 0.3) : AppTheme.textMuted.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppTheme.redAlert.withValues(alpha: 0.15) : AppTheme.textMuted.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text('$step',
                    style: TextStyle(
                      color: isActive ? AppTheme.redAlert : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                  color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PastDisputeTile extends StatelessWidget {
  final Map<String, dynamic> dispute;
  const _PastDisputeTile({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final isUserFavor = dispute['verdict'] == 'user_favor';
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isUserFavor ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.12),
          ),
          child: Center(
            child: Icon(Icons.gavel_rounded,
                color: isUserFavor ? AppTheme.greenSuccess : AppTheme.goldAccent, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${dispute['type']} Â· ${dispute['provider']}',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${dispute['id']} Â· ${dispute['date']}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isUserFavor ? AppTheme.greenSuccess : AppTheme.goldAccent).withValues(alpha: 0.15),
              borderRadius: AppTheme.radiusSm,
            ),
            child: Text(
              isUserFavor ? 'âœ… Won' : 'âš–ï¸ Mediated',
              style: TextStyle(
                color: isUserFavor ? AppTheme.greenSuccess : AppTheme.goldAccent,
                fontSize: 10, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if ((dispute['refund'] as double) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Rs. ${(dispute['refund'] as double).toInt()} refunded',
                  style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 10)),
            ),
        ]),
      ]),
    );
  }
}

class _DisputeResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _DisputeResultCard({required this.result});

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'user_favor':     return AppTheme.greenSuccess;
      case 'provider_favor': return AppTheme.goldAccent;
      case 'mediated':       return AppTheme.blueInfo;
      default:               return AppTheme.redAlert;
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = result['verdict'] as String;
    final color = _verdictColor(verdict);
    final refund = (result['refund_amount_pkr'] as num?)?.toDouble() ?? 0.0;
    final penalty = result['penalty_to_provider'] as String? ?? 'none';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Text('âš–ï¸ ', style: TextStyle(fontSize: 20)),
          Text('Dispute Agent Verdict',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            verdict == 'user_favor' ? 'âœ… Decided in Your Favour' :
            verdict == 'mediated'   ? 'ðŸ¤ Mediated Settlement' :
            verdict == 'provider_favor' ? 'âš–ï¸ Decided for Provider' : 'ðŸš¨ Escalated',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(result['reasoning'] as String,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        if (refund > 0) _InfoRow('Refund Amount', 'Rs. ${refund.toStringAsFixed(0)}', AppTheme.greenSuccess),
        _InfoRow('Action', result['action'] as String? ?? '-', AppTheme.blueInfo),
        _InfoRow('Provider Penalty', penalty, penalty == 'none' ? AppTheme.textMuted : AppTheme.redAlert),
        if (result['escalate_to_human'] == true) ...[
          const SizedBox(height: 10),
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
              Text('Escalated to human support team',
                  style: TextStyle(color: AppTheme.redAlert, fontSize: 12)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _InfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}
