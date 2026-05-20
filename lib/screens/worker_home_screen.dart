import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/location_service.dart';
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
  final bool _isUrdu = LanguageService().isUrdu;
  List<String> _availabilityRules = [];

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    LocationService().getCurrentLocation();
    final user = AuthService().currentUser;
    _workerName = user?.name ?? 'Worker';
    _workerCategory = user?.serviceCategory ?? 'Technician';
    _availabilityRules = user?.availabilityRules ?? [];
    _isOnline = user?.isAvailable ?? true;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    if (_workerCategory == 'Unassigned' || _availabilityRules.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openVoiceAgent();
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

  void _refreshAvailability() {
    final user = AuthService().currentUser;
    if (user != null && mounted) {
      setState(() {
        _availabilityRules = user.availabilityRules ?? [];
        _workerCategory = user.serviceCategory ?? 'Technician';
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

  Future<void> _toggleOnline() async {
    HapticFeedback.mediumImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);
    await AuthService().setWorkerAvailability(newStatus);
    
    if (newStatus) {
      // Auto-save location when going online to help matching
      final user = AuthService().currentUser;
      if (user == null) return; // Guard: no crash if session expired
      try {
        final loc = await LocationService().getCurrentLocation();
        if (loc.isSuccess && loc.data != null) {
          await LocationService().saveUserLocation(user.uid, loc.data!);
        }
      } catch (_) {
        // GPS unavailable — location will be updated next time
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: Text(_t('Logout', 'لاگ آؤٹ'), style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(_t('Are you sure you want to logout?', 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'کینسل'), style: const TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Logout', 'لاگ آؤٹ'), style: const TextStyle(color: AppTheme.redAlert)),
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildOnlineToggle(),
                      const SizedBox(height: 24),
                      _buildBigVoiceButton(),
                      const SizedBox(height: 24),
                      _buildAvailabilitySummary(),
                    ],
                  ),
                ),
              ),
              _buildLogoutButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.tealGlow,
          ),
          child: Center(
            child: Text(
              (_workerName.length >= 2 ? _workerName.substring(0, 2) : _workerName).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_workerName,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const SizedBox(height: 2),
              Text(
                _workerCategory == 'Unassigned' ? _t('Setup Required', 'سیٹ اپ کی ضرورت ہے') : _workerCategory,
                style: TextStyle(
                  color: _workerCategory == 'Unassigned' ? AppTheme.goldAccent : AppTheme.tealPrimary,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIcon(),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatusIcon() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, _) {
        final pulse = _pulseCtrl.value;
        return Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
            boxShadow: _isOnline ? [
              BoxShadow(
                color: AppTheme.greenSuccess.withValues(alpha: 0.4 * pulse),
                blurRadius: 8 + 4 * pulse, spreadRadius: 2 * pulse,
              ),
            ] : [],
          ),
        );
      },
    );
  }

  // ── Big Online Toggle ───────────────────────────────────────────────────────
  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: _isOnline ? AppTheme.greenSuccess.withValues(alpha: 0.1) : AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: _isOnline ? AppTheme.greenSuccess : Colors.white12,
            width: _isOnline ? 2 : 1,
          ),
          boxShadow: _isOnline ? [BoxShadow(color: AppTheme.greenSuccess.withValues(alpha: 0.1), blurRadius: 20)] : [],
        ),
        child: Row(
          children: [
            Icon(_isOnline ? Icons.check_circle : Icons.power_settings_new,
                color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isOnline ? _t('YOU ARE ONLINE', 'آپ آن لائن ہیں') : _t('YOU ARE OFFLINE', 'آپ آف لائن ہیں'),
                  style: TextStyle(
                    color: _isOnline ? AppTheme.greenSuccess : AppTheme.textSecondary,
                    fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1,
                  ),
                ),
                Text(
                  _isOnline ? _t('Ready for jobs', 'کام کے لیے تیار') : _t('Tap to start working', 'کام شروع کرنے کے لیے دبائیں'),
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ]),
            ),
            Switch(
              value: _isOnline,
              onChanged: (_) => _toggleOnline(),
              activeThumbColor: AppTheme.greenSuccess,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  // ── Big Voice Button ───────────────────────────────────────────────────────
  Widget _buildBigVoiceButton() {
    return GestureDetector(
      onTap: _openVoiceAgent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.purpleAgent.withValues(alpha: 0.25), AppTheme.purpleAgent.withValues(alpha: 0.1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.radiusXl,
          border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(color: AppTheme.purpleAgent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAgent.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.purpleAgent, width: 2),
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 48),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms),
            const SizedBox(height: 20),
            Text(
              _t('Talk to Assistant', 'اسسٹنٹ سے بات کریں'),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _t('Set your work and time with your voice', 'اپنی آواز سے کام اور وقت بتائیں'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  // ── Availability Summary ────────────────────────────────────────────────────
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
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_availabilityRules.isEmpty)
             Text(
                _t(
                  'No schedule set. Tap the purple button above to set it.',
                  'کوئی شیڈول سیٹ نہیں ہے۔ سیٹ کرنے کے لیے اوپر والا بٹن دبائیں۔',
                ),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              )
          else
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _availabilityRules.map((rule) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusMd,
                  border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.event_available, color: AppTheme.tealPrimary, size: 16),
                  const SizedBox(width: 8),
                  Text(rule, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              )).toList(),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: AppTheme.textMuted, size: 16),
        label: Text(_t('Logout', 'لاگ آؤٹ'), style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ),
    );
  }
}