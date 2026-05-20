import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/agent_model.dart';

/// The crown jewel — shows Antigravity multi-agent reasoning in real-time.
class LiveAgentPanel extends StatefulWidget {
  final List<AgentStep> steps;
  final bool isVisible;
  final VoidCallback onToggle;

  const LiveAgentPanel({
    super.key,
    required this.steps,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  State<LiveAgentPanel> createState() => _LiveAgentPanelState();
}

class _LiveAgentPanelState extends State<LiveAgentPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThinking = widget.steps.any((s) => s.status == AgentStepStatus.thinking);
    final doneCount = widget.steps.where((s) => s.status == AgentStepStatus.done).length;
    final total = widget.steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Toggle Header ──────────────────────────────────────────────────
        GestureDetector(
          onTap: widget.onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.agentGradient,
              borderRadius: widget.isVisible
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )
                  : AppTheme.radiusMd,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.purpleAgent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing dot when active
                if (hasThinking)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (ctx, _) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.tealLight.withValues(alpha: 
                          0.5 + 0.5 * _pulseController.value,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tealLight
                                .withValues(alpha: 0.6 * _pulseController.value),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'Live Agent Reasoning',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                // Step count badge
                if (total > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Text(
                      '$doneCount/$total agents',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasThinking) ...[
                  const _ThinkingBadge(),
                  const SizedBox(width: 8),
                ],
                Icon(
                  widget.isVisible
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // ─── Steps List ─────────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: widget.isVisible
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF130D2B),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: AppTheme.purpleAgent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: widget.steps.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Waiting for your request...',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: widget.steps.asMap().entries.map((entry) {
                            final i = entry.key;
                            final step = entry.value;
                            final isLast = i == widget.steps.length - 1;
                            return _AgentStepTile(
                              step: step,
                              index: i,
                              isLast: isLast,
                            );
                          }).toList(),
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AgentStepTile extends StatelessWidget {
  final AgentStep step;
  final int index;
  final bool isLast;

  const _AgentStepTile({
    required this.step,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isThinking = step.status == AgentStepStatus.thinking;
    final isDone = step.status == AgentStepStatus.done;
    final isFailed = step.status == AgentStepStatus.failed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: icon + connector line ──
            Column(
              children: [
                // Status icon circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(step.status).withValues(alpha: 0.15),
                    border: Border.all(
                      color: _statusColor(step.status).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: isThinking
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.purpleAgent,
                            ),
                          )
                        : Text(
                            AgentIdentity.emoji(step.agentName),
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                ),
                // Connector line to next step
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _statusColor(step.status).withValues(alpha: 0.5),
                            AppTheme.purpleAgent.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Right: content ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 14 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          step.agentName,
                          style: TextStyle(
                            color: _statusColor(step.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (step.isMocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Text(
                              'SIMULATION',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTime(step.timestamp),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.task,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.reasoning,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    if (step.toolCall != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.blueInfo.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radiusSm,
                          border: Border.all(color: AppTheme.blueInfo.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call_made_rounded,
                                color: AppTheme.blueInfo, size: 10),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                step.toolCall!,
                                style: const TextStyle(
                                  color: AppTheme.blueInfo,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (step.decision != null && isDone) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSuccess.withValues(alpha: 0.08),
                          borderRadius: AppTheme.radiusSm,
                          border: Border.all(color: AppTheme.greenSuccess.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '✓ ${step.decision!}',
                          style: const TextStyle(
                            color: AppTheme.greenSuccess,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (isFailed && step.decision != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.redAlert.withValues(alpha: 0.08),
                          borderRadius: AppTheme.radiusSm,
                        ),
                        child: Text(
                          '✗ ${step.decision!}',
                          style: const TextStyle(
                            color: AppTheme.redAlert,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 120)).slideY(begin: 0.08);
  }

  Color _statusColor(AgentStepStatus s) {
    switch (s) {
      case AgentStepStatus.thinking: return AppTheme.purpleAgent;
      case AgentStepStatus.done:     return AppTheme.greenSuccess;
      case AgentStepStatus.failed:   return AppTheme.redAlert;
      case AgentStepStatus.skipped:  return AppTheme.textMuted;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _ThinkingBadge extends StatefulWidget {
  const _ThinkingBadge();
  @override
  State<_ThinkingBadge> createState() => _ThinkingBadgeState();
}

class _ThinkingBadgeState extends State<_ThinkingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _dots = _dots < 3 ? _dots + 1 : 1);
          _ctrl.forward(from: 0);
        }
      })
      ..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.tealPrimary.withValues(alpha: 0.2),
        borderRadius: AppTheme.radiusSm,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Thinking${'.' * _dots}',
        style: const TextStyle(
          color: AppTheme.tealLight,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
