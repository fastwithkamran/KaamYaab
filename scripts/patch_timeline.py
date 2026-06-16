content = open('lib/screens/booking_flow_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n').replace('\r', '\n')

# ── Find and replace the entire _TimelineStep class ──────────────────────────
idx_ts = n.find('\n// -- Timeline Step')
if idx_ts == -1:
    idx_ts = n.rfind('\nclass _TimelineStep ')
print('_TimelineStep at:', idx_ts)

# Everything from _TimelineStep to end of file
old_tail = n[idx_ts:]

new_tail = '''

// ── _InfoChip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── _AgentStatusBanner ───────────────────────────────────────────────────────
// Dynamic banner at top of pipeline card showing what AI is doing right now.
class _AgentStatusBanner extends StatelessWidget {
  final List<BookingStep> steps;
  final int currentStep;
  final String workerName;
  final bool isComplete;
  final String? workerResponse;

  const _AgentStatusBanner({
    required this.steps,
    required this.currentStep,
    required this.workerName,
    required this.isComplete,
    required this.workerResponse,
  });

  static const _stepIcons = [
    Icons.send_rounded,
    Icons.handshake_rounded,
    Icons.phone_in_talk_rounded,
    Icons.notifications_active_rounded,
    Icons.directions_car_rounded,
    Icons.build_rounded,
    Icons.star_rounded,
  ];

  (String, Color, IconData) get _status {
    if (isComplete) {
      return ('✅  Booking fully complete!', AppTheme.greenSuccess, Icons.celebration_rounded);
    }
    if (currentStep < 0) {
      return ('⏳  Preparing booking...', AppTheme.textMuted, Icons.hourglass_top_rounded);
    }
    if (workerResponse == 'rejected') {
      return ('❌  Worker declined the request', AppTheme.redAlert, Icons.cancel_rounded);
    }
    final labels = [
      '📡  Notifying $workerName...',
      '⏳  Waiting for $workerName to respond...',
      '🤝  Deal locked — details exchanged',
      '🔔  Reminders scheduled for you',
      '🚗  $workerName is on the way!',
      '🔧  Job in progress',
      '⭐  Wrapping up — please rate!',
    ];
    final colours = [
      AppTheme.tealPrimary,
      AppTheme.goldAccent,
      AppTheme.greenSuccess,
      AppTheme.purpleLight,
      AppTheme.tealPrimary,
      AppTheme.goldAccent,
      AppTheme.goldAccent,
    ];
    final i = currentStep.clamp(0, labels.length - 1);
    return (labels[i], colours[i], _stepIcons[i]);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('AI Agentic Pipeline  ·  7-step orchestration',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ]),
          ),
          if (!isComplete && currentStep >= 0 && workerResponse != 'rejected')
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color.withValues(alpha: 0.7),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── _TimelineStep — premium redesign ─────────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final BookingStep step;
  final int index, currentStep;
  final bool isLast;

  const _TimelineStep({
    required this.step,
    required this.index,
    required this.isLast,
    required this.currentStep,
  });

  static const _stepIcons = [
    Icons.send_rounded,
    Icons.handshake_rounded,
    Icons.phone_in_talk_rounded,
    Icons.notifications_active_rounded,
    Icons.directions_car_rounded,
    Icons.build_rounded,
    Icons.star_rounded,
  ];

  static const _stepEmojis = ['📡', '✋', '📞', '🔔', '🚗', '🔧', '⭐'];

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.status == 'completed';
    final isActive    = step.status == 'active';
    final isFailed    = step.status == 'failed';
    final isPending   = !isCompleted && !isActive && !isFailed;

    final Color dotColor;
    final Color lineColor;
    if (isCompleted) {
      dotColor = AppTheme.greenSuccess;
      lineColor = AppTheme.greenSuccess;
    } else if (isActive) {
      dotColor = AppTheme.tealPrimary;
      lineColor = AppTheme.tealPrimary.withValues(alpha: 0.3);
    } else if (isFailed) {
      dotColor = AppTheme.redAlert;
      lineColor = AppTheme.redAlert.withValues(alpha: 0.2);
    } else {
      dotColor = AppTheme.textMuted.withValues(alpha: 0.4);
      lineColor = AppTheme.textMuted.withValues(alpha: 0.1);
    }

    final stepIcon = index < _stepIcons.length ? _stepIcons[index] : Icons.circle;
    final stepEmoji = index < _stepEmojis.length ? _stepEmojis[index] : '•';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left column: dot + connector line ───────────────────────────
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Step dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor.withValues(alpha: isPending ? 0.04 : 0.13),
                    border: Border.all(
                      color: dotColor,
                      width: isActive ? 2 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppTheme.tealPrimary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check_rounded, color: dotColor, size: 16)
                        : isFailed
                            ? Icon(Icons.close_rounded, color: dotColor, size: 16)
                            : isActive
                                ? SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: dotColor))
                                : Text(stepEmoji,
                                    style: const TextStyle(fontSize: 14)),
                  ),
                ),
                // Connector line — dashed when pending, solid when done
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: isCompleted
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.greenSuccess.withValues(alpha: 0.7),
                                    AppTheme.greenSuccess.withValues(alpha: 0.15),
                                  ],
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _DashedLinePainter(lineColor),
                              size: const Size(2, double.infinity),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Right column: title + description + note ─────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(step.title,
                          style: TextStyle(
                            color: isPending
                                ? AppTheme.textMuted
                                : isFailed
                                    ? AppTheme.redAlert
                                    : AppTheme.textPrimary,
                            fontWeight: (isActive || isCompleted)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 13,
                          )),
                    ),
                    if (step.timestamp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(step.timestamp!,
                            style: const TextStyle(
                                color: AppTheme.greenSuccess,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(step.description,
                      style: TextStyle(
                          color: isPending
                              ? AppTheme.textMuted.withValues(alpha: 0.5)
                              : AppTheme.textMuted,
                          fontSize: 11,
                          height: 1.4)),

                  // Agent note bubble
                  if (step.agentNote != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFailed
                            ? AppTheme.redAlert.withValues(alpha: 0.07)
                            : AppTheme.greenSuccess.withValues(alpha: 0.07),
                        borderRadius: AppTheme.radiusSm,
                        border: Border.all(
                            color: isFailed
                                ? AppTheme.redAlert.withValues(alpha: 0.25)
                                : AppTheme.greenSuccess.withValues(alpha: 0.2)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(
                          isFailed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          color: isFailed ? AppTheme.redAlert : AppTheme.greenSuccess,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(step.agentNote!,
                                style: TextStyle(
                                    color: isFailed ? AppTheme.redAlert : AppTheme.greenSuccess,
                                    fontSize: 10,
                                    height: 1.4))),
                      ]),
                    ),
                  ],

                  // "Agent working..." shimmer text for active step
                  if (isActive && step.agentNote == null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.tealPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Agent working on this step...',
                          style: TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashed connector line painter ─────────────────────────────────────────────
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
'''

n = n[:idx_ts] + new_tail
open('lib/screens/booking_flow_screen.dart', 'w', encoding='utf-8').write(n)
print('SUCCESS: _TimelineStep + new widgets written')
