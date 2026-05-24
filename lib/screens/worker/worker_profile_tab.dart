import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';

class WorkerProfileTab extends StatefulWidget {
  final VoidCallback onEditProfile;
  const WorkerProfileTab({super.key, required this.onEditProfile});

  @override
  State<WorkerProfileTab> createState() => _WorkerProfileTabState();
}

class _WorkerProfileTabState extends State<WorkerProfileTab> {
  final bool _isUrdu = LanguageService().isUrdu;

  String _workerName = '';
  String _workerCategory = 'Unassigned';
  String? _subRole;
  List<String> _availabilityRules = [];
  List<String> _skills = [];
  double? _baseRatePkr;
  double? _minRatePkr;
  double? _maxRatePkr;
  String? _negotiationStyle;
  bool _profileComplete = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    AuthService().refreshCurrentUser().then((_) {
      if (!mounted) return;
      final user = AuthService().currentUser;
      if (user == null) return;
      setState(() {
        _workerName = user.name;
        _workerCategory = user.serviceCategory ?? 'Unassigned';
        _subRole = user.subRole;
        _availabilityRules = user.availabilityRules ?? [];
        _skills = user.skills ?? [];
        _baseRatePkr = user.baseRatePkr;
        _minRatePkr = user.minRatePkr;
        _maxRatePkr = user.maxRatePkr;
        _negotiationStyle = user.negotiationStyle;
        _profileComplete = user.isProfileComplete;
      });
    });
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: Text(_t('Logout', 'لاگ آؤٹ'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
            _t('Are you sure you want to logout?',
                'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'کینسل'),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Logout', 'لاگ آؤٹ'),
                style: const TextStyle(color: AppTheme.redAlert)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().logout();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.tealPrimary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: () async {
        _loadProfile();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            if (_profileComplete) ...[
              _buildDnaScoreCard(),
              const SizedBox(height: 16),
              _buildRateCard(),
              const SizedBox(height: 16),
              _buildAvailabilitySummary(),
              const SizedBox(height: 16),
              if (_skills.isNotEmpty) ...[
                _buildSkillsCard(),
                const SizedBox(height: 24),
              ],
            ] else ...[
              _buildIncompleteBanner(),
              const SizedBox(height: 24),
            ],
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
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
                  fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _workerName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                _workerCategory == 'Unassigned'
                    ? _t('Setup Required', 'سیٹ اپ کی ضرورت ہے')
                    : (_subRole ?? _workerCategory),
                style: TextStyle(
                  color: _workerCategory == 'Unassigned'
                      ? AppTheme.goldAccent
                      : AppTheme.tealPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onEditProfile,
          icon: const Icon(Icons.edit_outlined, color: AppTheme.tealPrimary),
          tooltip: _t('Edit Profile', 'پروفائل تبدیل کریں'),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildIncompleteBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.goldAccent.withValues(alpha: 0.08),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.goldAccent, size: 36),
          const SizedBox(height: 12),
          Text(
            _t('Profile Setup Pending', 'پروفائل سیٹ اپ نامکمل ہے'),
            style: const TextStyle(
              color: AppTheme.goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Please complete your profile to access all features and start getting jobs.',
              'تمام فیچرز تک رسائی حاصل کرنے اور کام شروع کرنے کے لیے اپنا پروفائل مکمل کریں۔',
            ),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onEditProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
            ),
            icon: const Icon(Icons.smart_toy_outlined),
            label: Text(_t('Setup Now with AI', 'ابھی AI کے ساتھ بنائیں')),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildRateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.monetization_on_outlined,
                color: AppTheme.goldAccent, size: 16),
            const SizedBox(width: 8),
            Text(_t('Your Rates', 'آپ کے ریٹ'),
                style: const TextStyle(
                    color: AppTheme.goldAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _rateChip('Base', _baseRatePkr, AppTheme.goldAccent),
            const SizedBox(width: 10),
            _rateChip('Min', _minRatePkr, AppTheme.redAlert),
            const SizedBox(width: 10),
            _rateChip('Max', _maxRatePkr, AppTheme.greenSuccess),
          ]),
          if (_negotiationStyle != null && _negotiationStyle!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.handshake_outlined,
                  color: AppTheme.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Negotiation: ${_negotiationStyle![0].toUpperCase()}${_negotiationStyle!.substring(1)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ]),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _rateChip(String label, double? rate, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusSm,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(label,
              style:
                  TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            rate != null ? 'Rs.${rate.toInt()}' : '—',
            style: TextStyle(
                color: rate != null ? Colors.white : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }

  Widget _buildAvailabilitySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('Your Schedule', 'آپ کا شیڈول'),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_availabilityRules.isEmpty)
            Text(
              _t(
                'No schedule set.',
                'کوئی شیڈول سیٹ نہیں ہے۔',
              ),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availabilityRules
                  .map((rule) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radiusMd,
                          border: Border.all(
                              color: AppTheme.tealPrimary
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.event_available,
                              color: AppTheme.tealPrimary, size: 16),
                          const SizedBox(width: 8),
                          Text(rule,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ))
                  .toList(),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildSkillsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.checklist_outlined,
                color: AppTheme.purpleAgent, size: 16),
            const SizedBox(width: 8),
            Text(_t('Your Skills', 'آپ کی مہارتیں'),
                style: const TextStyle(
                    color: AppTheme.purpleAgent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.purpleAgent.withValues(alpha: 0.1),
                        borderRadius: AppTheme.radiusSm,
                        border: Border.all(
                            color: AppTheme.purpleAgent
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(s,
                          style: const TextStyle(
                              color: AppTheme.purpleLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.redAlert.withValues(alpha: 0.1),
          foregroundColor: AppTheme.redAlert,
          side: const BorderSide(color: AppTheme.redAlert),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
        ),
        icon: const Icon(Icons.logout),
        label: Text(
          _t('Logout', 'لاگ آؤٹ'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ).animate().fadeIn(delay: 350.ms);
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
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05);
  }
}
