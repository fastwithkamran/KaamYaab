content = open('lib/screens/booking_flow_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n').replace('\r', '\n')
changes = 0

# ─────────────────────────────────────────────────────────────────────────────
# 1. Replace _buildNegotiationPanel with chat-style version
# ─────────────────────────────────────────────────────────────────────────────
old_neg_start = n.find('\n  // -- Negotiation panel')
if old_neg_start == -1:
    old_neg_start = n.find('\n  Widget _buildNegotiationPanel()')
old_neg_end = n.find('\n  // -- Success banner', old_neg_start)
if old_neg_end == -1:
    old_neg_end = n.find('\n  Widget _buildSuccessBanner()', old_neg_start)

print('neg panel:', old_neg_start, '->', old_neg_end)

if old_neg_start != -1 and old_neg_end != -1:
    new_neg = '''
  // ── Negotiation panel — chat-style with quick-offer chips ────────────────
  Widget _buildNegotiationPanel() {
    final quickOffers = [
      (_finalPrice * 0.80).round(),
      (_finalPrice * 0.85).round(),
      (_finalPrice * 0.90).round(),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldAccent.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Panel header ────────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.goldAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handshake_outlined,
                color: AppTheme.goldAccent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Negotiate Price',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text(
                _workerMinRate != null
                    ? 'Floor Rs.${_workerMinRate!.toInt()} · Agent negotiates on worker\'s behalf'
                    : 'Make a counter-offer. AI agent will respond.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ]),
          ),
          if (_negotiationDone)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: AppTheme.greenSuccess.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.greenSuccess, size: 14),
            ),
        ]),

        const SizedBox(height: 14),

        // ── Chat-style conversation bubbles ──────────────────────────────
        if (_liveNegotiationResult != null) ...[
          // User offer bubble (right-aligned)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('You offered',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                Text(
                  'Rs. ${_offerCtrl.text.isNotEmpty ? _offerCtrl.text : "—"}',
                  style: const TextStyle(
                      color: AppTheme.tealPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          // Agent response bubble (left-aligned)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAgent.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _negotiationDone
                      ? AppTheme.greenSuccess.withValues(alpha: 0.08)
                      : AppTheme.purpleAgent.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: _negotiationDone
                        ? AppTheme.greenSuccess.withValues(alpha: 0.25)
                        : AppTheme.purpleAgent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Negotiation Agent',
                      style: TextStyle(
                          color: AppTheme.purpleLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(_liveNegotiationResult!,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12, height: 1.4)),
                  if (_negotiationDone) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.greenSuccess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Final: Rs.${_finalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.greenSuccess,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Quick-offer chips ────────────────────────────────────────────
        if (!_negotiationDone) ...[
          const Text('QUICK OFFERS',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(children: quickOffers.map((amt) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isNegotiating ? null : () {
                _offerCtrl.text = amt.toString();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: Text('Rs.$amt',
                    style: const TextStyle(
                        color: AppTheme.goldAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 12),
        ],

        // ── Input row ────────────────────────────────────────────────────
        if (!_negotiationDone)
          Row(children: [
            Expanded(
              child: TextField(
                controller: _offerCtrl,
                enabled: !_negotiationDone && !_isNegotiating,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Your offer in Rs.',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  prefixText: 'Rs. ',
                  prefixStyle: const TextStyle(
                      color: AppTheme.goldAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed:
                    (_negotiationDone || _isNegotiating) ? null : _runNegotiation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  disabledBackgroundColor:
                      AppTheme.goldAccent.withValues(alpha: 0.4),
                ),
                child: _isNegotiating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Send',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
      ]),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05);
  }'''
    n = n[:old_neg_start] + new_neg + n[old_neg_end:]
    changes += 1
    print('SUCCESS 1: negotiation panel replaced')
else:
    print('FAIL 1: neg panel not found', old_neg_start, old_neg_end)

# ─────────────────────────────────────────────────────────────────────────────
# 2. Replace _buildSuccessBanner with enhanced version
# ─────────────────────────────────────────────────────────────────────────────
old_success_start = n.find('\n  // -- Success banner')
if old_success_start == -1:
    old_success_start = n.find('\n  Widget _buildSuccessBanner()')
old_success_end = n.find('\n  // -- Feedback', old_success_start)
if old_success_end == -1:
    old_success_end = n.find('\n  Widget _buildFeedback()', old_success_start)

print('success banner:', old_success_start, '->', old_success_end)

if old_success_start != -1 and old_success_end != -1:
    new_success = '''
  // ── Success banner — celebration card ────────────────────────────────────
  Widget _buildSuccessBanner() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, child) => Transform.scale(
        scale: 0.85 + 0.15 * _successAnim.value,
        child: Opacity(
            opacity: _successAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9B87), Color(0xFF06B3A0), Color(0xFF048C7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.radiusLg,
          boxShadow: [
            BoxShadow(
              color: AppTheme.tealPrimary.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(children: [
          // ── Top celebration section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(children: [
              const Text('🎉', style: TextStyle(fontSize: 48))
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5), duration: 600.ms,
                      curve: Curves.elasticOut),
              const SizedBox(height: 10),
              const Text('Booking Confirmed!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text(
                '${widget.match.provider.name} will arrive by ${widget.match.recommendedSlot}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),

              // ── Info chips ──────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuccessChip(
                      Icons.payments_rounded, 'Rs.${_finalPrice.toStringAsFixed(0)}'),
                  _SuccessChip(Icons.schedule_rounded, widget.match.recommendedSlot),
                  _SuccessChip(Icons.receipt_long_rounded, _receiptNumber),
                ],
              ),
            ]),
          ),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),

          // ── Action buttons ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call Worker',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📞 Calling ${widget.match.provider.name}... (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Add to Calendar',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📅 Added to calendar (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔗 Share link copied (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }'''
    n = n[:old_success_start] + new_success + n[old_success_end:]
    changes += 1
    print('SUCCESS 2: success banner replaced')
else:
    print('FAIL 2: success banner not found', old_success_start, old_success_end)

open('lib/screens/booking_flow_screen.dart', 'w', encoding='utf-8').write(n)
print(f'Done. {changes} changes made.')
