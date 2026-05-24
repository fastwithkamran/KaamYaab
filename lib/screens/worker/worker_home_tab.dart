import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/location_service.dart';
import '../../services/booking_history_service.dart';
import '../../widgets/worker_agent_chat.dart';

class WorkerHomeTab extends StatefulWidget {
  final VoidCallback onEditProfile;
  const WorkerHomeTab({super.key, required this.onEditProfile});

  @override
  State<WorkerHomeTab> createState() => _WorkerHomeTabState();
}

class _WorkerHomeTabState extends State<WorkerHomeTab>
    with TickerProviderStateMixin {
  final bool _isUrdu = LanguageService().isUrdu;
  late AnimationController _pulseCtrl;

  String _workerName = '';
  String _workerCategory = 'Unassigned';
  String? _subRole;
  bool _isOnline = true;
  bool _profileComplete = false;
  double _rating = 0;
  int _totalJobs = 0;

  bool _hasAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadProfile(isFirstLoad: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _loadProfile({bool isFirstLoad = false}) {
    AuthService().refreshCurrentUser().then((_) {
      if (!mounted) return;
      final user = AuthService().currentUser;
      if (user == null) return;
      setState(() {
        _workerName = user.name;
        _workerCategory = user.serviceCategory ?? 'Unassigned';
        _subRole = user.subRole;
        _isOnline = user.isAvailable;
        _profileComplete = user.isProfileComplete;
        _rating = user.rating;
        _totalJobs = user.totalJobs;
      });
      if (!_profileComplete && isFirstLoad && !_hasAutoOpened) {
        _hasAutoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openVoiceAgent());
      }
    });
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

  // Safe Firestore Timestamp / DateTime / String → DateTime conversion.
  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      final result = (raw as dynamic).toDate();
      if (result is DateTime) return result;
    } catch (_) {}
    return null;
  }

  void _openVoiceAgent() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          const WorkerAgentChatBottomSheet(initialMode: AgentInputMode.voice),
    ).then((_) => _loadProfile());
  }

  Future<void> _toggleOnline() async {
    HapticFeedback.mediumImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);
    await AuthService().setWorkerAvailability(newStatus);
    if (newStatus) {
      final user = AuthService().currentUser;
      if (user == null) return;
      try {
        final loc = await LocationService().getCurrentLocation();
        if (loc.isSuccess && loc.data != null) {
          await LocationService().saveUserLocation(user.uid, loc.data!);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.tealPrimary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: () async => _loadProfile(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (!_profileComplete) ...[
              _buildSetupBanner(),
              const SizedBox(height: 16),
            ],
            _buildOnlineToggle(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 20),
            _buildDnaScoreCard(),
            const SizedBox(height: 20),
            _buildAIAgentCard(),
            const SizedBox(height: 20),
            _buildEarningsSnapshot(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.tealGlow,
          ),
          child: Center(
            child: Text(
              (_workerName.length >= 2
                      ? _workerName.substring(0, 2)
                      : _workerName)
                  .toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTheme.timeGreeting(),
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(
                _workerName.isEmpty ? '...' : _workerName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20),
              ),
              Text(
                _workerCategory == 'Unassigned'
                    ? _t('Setup Required', 'سیٹ اپ کی ضرورت ہے')
                    : (_subRole ?? _workerCategory),
                style: TextStyle(
                  color: _workerCategory == 'Unassigned'
                      ? AppTheme.goldAccent
                      : AppTheme.tealPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Pulsing online dot
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) => Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: AppTheme.greenSuccess
                            .withValues(alpha: 0.5 * _pulseCtrl.value),
                        blurRadius: 10 + 6 * _pulseCtrl.value,
                        spreadRadius: 2 * _pulseCtrl.value,
                      ),
                    ]
                  : [],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Setup banner ────────────────────────────────────────────────────────────
  Widget _buildSetupBanner() {
    return GestureDetector(
      onTap: _openVoiceAgent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.goldAccent.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.goldAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'Complete your profile to start receiving jobs.',
                'جاب پانے کے لیے اپنا پروفائل مکمل کریں۔',
              ),
              style: const TextStyle(
                  color: AppTheme.goldAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: AppTheme.goldAccent, size: 14),
        ]),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  // ── Online toggle ────────────────────────────────────────────────────────────
  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: _isOnline
              ? AppTheme.greenSuccess.withValues(alpha: 0.08)
              : AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: _isOnline ? AppTheme.greenSuccess : Colors.white12,
            width: _isOnline ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            _isOnline ? Icons.check_circle : Icons.power_settings_new,
            color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline
                      ? _t('YOU ARE ONLINE', 'آپ آن لائن ہیں')
                      : _t('YOU ARE OFFLINE', 'آپ آف لائن ہیں'),
                  style: TextStyle(
                    color: _isOnline
                        ? AppTheme.greenSuccess
                        : AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _isOnline
                      ? _t('Ready for jobs', 'کام کے لیے تیار')
                      : _t('Tap to go online', 'آن لائن ہونے کے لیے دبائیں'),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOnline,
            onChanged: (_) => _toggleOnline(),
            activeThumbColor: AppTheme.greenSuccess,
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08);
  }

  // ── Stats row ────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BookingHistoryService().watchWorkerBookings(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final completed = all.where((b) => b['status'] == 'completed').length;
        final totalEarnings = all.fold<double>(
          0,
          (sum, b) =>
              sum + ((b['final_price_pkr'] as num?)?.toDouble() ?? 0),
        );
        return Row(children: [
          _statCard('Total Jobs', '$completed', Icons.work_outline,
              AppTheme.tealPrimary),
          const SizedBox(width: 12),
          _statCard(
              'Rating',
              _totalJobs == 0
                  ? 'New'
                  : _rating.toStringAsFixed(1),
              Icons.star_outline,
              AppTheme.goldAccent),
          const SizedBox(width: 12),
          _statCard(
              'Earned',
              'Rs.${totalEarnings.toInt()}',
              Icons.account_balance_wallet_outlined,
              AppTheme.greenSuccess),
        ]);
      },
    ).animate().fadeIn(delay: 180.ms);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── AI Agent card ────────────────────────────────────────────────────────────
  Widget _buildAIAgentCard() {
    return GestureDetector(
      onTap: widget.onEditProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.purpleAgent.withValues(alpha: 0.22),
              AppTheme.purpleAgent.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
              color: AppTheme.purpleAgent.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.purpleAgent.withValues(alpha: 0.18),
              border: Border.all(
                  color: AppTheme.purpleAgent.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: AppTheme.purpleLight, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileComplete
                      ? _t('Update Profile via AI', 'AI سے پروفائل اپ ڈیٹ کریں')
                      : _t('Set Up Profile with AI', 'AI سے پروفائل بنائیں'),
                  style: const TextStyle(
                      color: AppTheme.purpleLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('Talk to the AI assistant with your voice',
                      'اپنی آواز سے AI اسسٹنٹ سے بات کریں'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: AppTheme.purpleLight, size: 16),
        ]),
      ),
    ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.08);
  }

  // ── Earnings snapshot ────────────────────────────────────────────────────────
  Widget _buildEarningsSnapshot() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BookingHistoryService().watchWorkerBookings(),
      builder: (context, snap) {
        final bookings = snap.data ?? [];
        final today = DateTime.now();
        final todayBookings = bookings.where((b) {
          final dt = _parseTimestamp(b['created_at']);
          if (dt == null) return false;
          return dt.year == today.year &&
              dt.month == today.month &&
              dt.day == today.day;
        }).toList();

        final todayEarnings = todayBookings.fold<double>(
          0,
          (s, b) => s + ((b['final_price_pkr'] as num?)?.toDouble() ?? 0),
        );

        final activeCount = bookings
            .where((b) =>
                b['status'] == 'en_route' || b['status'] == 'in_progress')
            .length;

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
              const Text(
                'Today\'s Snapshot',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _snapshotItem("Today's Earnings",
                    'Rs.${todayEarnings.toInt()}', AppTheme.greenSuccess),
                const SizedBox(width: 16),
                _snapshotItem(
                    'Today\'s Jobs', '${todayBookings.length}', AppTheme.tealPrimary),
                const SizedBox(width: 16),
                _snapshotItem(
                    'Active Now', '$activeCount', AppTheme.goldAccent),
              ]),
            ],
          ),
        ).animate().fadeIn(delay: 320.ms);
      },
    );
  }

  Widget _snapshotItem(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildDnaScoreCard() {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    final score = user.dnaScore;
    final label = user.dnaLabel;
    final scoreColor = AppTheme.dnaScoreColor(score);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: scoreColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.04),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        children: [
          // Left: Score & Label Badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.1),
                  border: Border.all(color: scoreColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Right: Info text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('KaamYaab DNA Score', 'کام یاب ڈی این اے اسکور'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'Your score dynamically calculates based on your ratings, jobs completed, and experience. Keep performing well to unlock more benefits.',
                    'آپ کے اسکور کا حساب آپ کی ریٹنگز، مکمل شدہ کام اور تجربے کی بنیاد پر کیا جاتا ہے۔ مزید فوائد کے لیے اپنی کارکردگی بہتر رکھیں۔',
                  ),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05);
  }
}
