import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/worker_agent_chat.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with TickerProviderStateMixin {
  late String _workerName;
  late String _workerCategory;
  bool _isOnline = true;
  List<String> _availabilityRules = [];

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _workerName = user?.name ?? 'Worker';
    _workerCategory = user?.serviceCategory ?? 'Technician';
    _availabilityRules = user?.availabilityRules ?? [];
    _isOnline = user?.isAvailable ?? true;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _refreshAvailability() {
    final user = AuthService().currentUser;
    if (user != null && mounted) {
      setState(() {
        _availabilityRules = user.availabilityRules ?? [];
      });
    }
  }

  void _openVoiceAgent() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WorkerAgentChatBottomSheet(initialMode: AgentInputMode.voice),
    ).then((_) => _refreshAvailability());
  }

  void _openChatAgent() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WorkerAgentChatBottomSheet(initialMode: AgentInputMode.text),
    ).then((_) => _refreshAvailability());
  }

  Future<void> _toggleOnline() async {
    HapticFeedback.mediumImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);
    await AuthService().setWorkerAvailability(newStatus);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.redAlert)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _buildHeader(),
                const SizedBox(height: 28),

                // ── Welcome Card ────────────────────────────────────
                _buildWelcomeCard(),
                const SizedBox(height: 24),

                // ── Agent CTAs ──────────────────────────────────────
                _buildAgentSection(),
                const SizedBox(height: 24),

                // ── Availability Summary ────────────────────────────
                _buildAvailabilitySummary(),
                const SizedBox(height: 24),

                // ── Online/Offline Toggle ───────────────────────────
                _buildOnlineToggle(),
                const SizedBox(height: 16),

                // ── Logout ──────────────────────────────────────────
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.tealGlow,
          ),
          child: Center(
            child: Text(
              _workerName.isNotEmpty ? _workerName.substring(0, 2).toUpperCase() : 'W',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _workerName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Text(
                      _workerCategory,
                      style: const TextStyle(
                        color: AppTheme.tealPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Status indicator
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final pulse = _pulseCtrl.value;
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
                boxShadow: _isOnline
                    ? [
                        BoxShadow(
                          color: AppTheme.greenSuccess.withValues(alpha: 0.4 * pulse),
                          blurRadius: 8 + 4 * pulse,
                          spreadRadius: 2 * pulse,
                        ),
                      ]
                    : [],
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Welcome Card ────────────────────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.purpleAgent.withValues(alpha: 0.2),
            AppTheme.blueInfo.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purpleAgent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🤖', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Text(
                'KaamYaab Agent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Salam, $_workerName! Tell me when you\'re available and I\'ll connect you with customers nearby.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can speak or type — whatever is easier for you.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.05);
  }

  // ── Agent Input Section ─────────────────────────────────────────────────────
  Widget _buildAgentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Your Availability',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose how you\'d like to talk to the agent',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Voice CTA
            Expanded(
              child: _AgentCTA(
                icon: Icons.mic_rounded,
                label: 'Talk to Agent',
                subtitle: 'Use your voice',
                gradient: LinearGradient(
                  colors: [
                    AppTheme.purpleAgent.withValues(alpha: 0.25),
                    AppTheme.purpleAgent.withValues(alpha: 0.1),
                  ],
                ),
                borderColor: AppTheme.purpleAgent.withValues(alpha: 0.4),
                iconColor: AppTheme.purpleAgent,
                onTap: _openVoiceAgent,
              ),
            ),
            const SizedBox(width: 12),
            // Text CTA
            Expanded(
              child: _AgentCTA(
                icon: Icons.chat_rounded,
                label: 'Chat with Agent',
                subtitle: 'Type your schedule',
                gradient: LinearGradient(
                  colors: [
                    AppTheme.tealPrimary.withValues(alpha: 0.2),
                    AppTheme.tealPrimary.withValues(alpha: 0.08),
                  ],
                ),
                borderColor: AppTheme.tealPrimary.withValues(alpha: 0.35),
                iconColor: AppTheme.tealPrimary,
                onTap: _openChatAgent,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.05);
  }

  // ── Availability Summary ────────────────────────────────────────────────────
  Widget _buildAvailabilitySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppTheme.goldAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Your Availability',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_availabilityRules.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.greenSuccess.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusSm,
                  ),
                  child: Text(
                    '${_availabilityRules.length} rule${_availabilityRules.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.greenSuccess,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_availabilityRules.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: AppTheme.textMuted.withValues(alpha: 0.15),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  const Text(
                    'No availability set yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Talk to the agent to set your schedule',
                    style: TextStyle(
                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availabilityRules.map((rule) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.tealPrimary.withValues(alpha: 0.12),
                        AppTheme.blueInfo.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.tealPrimary, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          rule,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.05);
  }

  // ── Online/Offline Toggle ───────────────────────────────────────────────────
  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: _isOnline
              ? LinearGradient(colors: [
                  AppTheme.greenSuccess.withValues(alpha: 0.15),
                  AppTheme.greenSuccess.withValues(alpha: 0.05),
                ])
              : LinearGradient(colors: [
                  AppTheme.textMuted.withValues(alpha: 0.1),
                  AppTheme.textMuted.withValues(alpha: 0.05),
                ]),
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: _isOnline
                ? AppTheme.greenSuccess.withValues(alpha: 0.4)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline
                    ? AppTheme.greenSuccess.withValues(alpha: 0.2)
                    : AppTheme.textMuted.withValues(alpha: 0.1),
              ),
              child: Icon(
                _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? 'You\'re Online' : 'You\'re Offline',
                    style: TextStyle(
                      color: _isOnline ? AppTheme.greenSuccess : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isOnline
                        ? 'Customers can find and book you'
                        : 'Tap to go online and start receiving jobs',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _isOnline
                    ? AppTheme.greenSuccess
                    : AppTheme.textMuted.withValues(alpha: 0.3),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  // ── Logout Button ───────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.redAlert.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.redAlert, size: 18),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                color: AppTheme.redAlert,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}

// ── Agent CTA Card ────────────────────────────────────────────────────────────
class _AgentCTA extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _AgentCTA({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_AgentCTA> createState() => _AgentCTAState();
}

class _AgentCTAState extends State<_AgentCTA> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(color: widget.borderColor),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.iconColor.withValues(alpha: 0.15),
                border: Border.all(color: widget.iconColor.withValues(alpha: 0.3)),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              widget.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
