import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class WorkerDetailScreen extends StatefulWidget {
  final AppUser worker;
  const WorkerDetailScreen({super.key, required this.worker});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  bool _bookingRequested = false;
  bool _workerBanned = false;

  @override
  void initState() {
    super.initState();
    _checkBan();
  }

  Future<void> _checkBan() async {
    final banned = await AuthService().isUserBanned(widget.worker.uid);
    if (mounted) setState(() => _workerBanned = banned);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              _buildSliverHeader(w),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildStatRow(w),
                    const SizedBox(height: 20),
                    if (w.bio != null && w.bio!.isNotEmpty) ...[
                      _buildSection('About', Icons.info_outline, AppTheme.blueInfo,
                          Text(w.bio!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6))),
                      const SizedBox(height: 16),
                    ],
                    _buildSection('Specialization', Icons.build_outlined, AppTheme.tealPrimary, _buildSpecRow(w)),
                    const SizedBox(height: 16),
                    _buildSection('Skills', Icons.checklist_outlined, AppTheme.purpleAgent, _buildSkillChips(w)),
                    const SizedBox(height: 16),
                    _buildSection('Service Details', Icons.receipt_long_outlined, AppTheme.goldAccent, _buildServiceDetails(w)),
                    const SizedBox(height: 16),
                    _buildContactCard(w),
                    const SizedBox(height: 16),
                    if (_workerBanned)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.redError.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radiusMd,
                          border: Border.all(color: AppTheme.redError.withValues(alpha: 0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.block, color: AppTheme.redError, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('This worker has been suspended by our admin team.',
                              style: TextStyle(color: AppTheme.redError, fontSize: 13))),
                        ]),
                      ),
                  ]),
                ),
              ),
            ],
          ),

          // Bottom booking bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBookingBar(w),
          ),
        ],
      ),
    );
  }

  // ── Sliver app bar with photo ─────────────────────────────────────────────
  Widget _buildSliverHeader(AppUser w) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.backgroundDark,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: AppTheme.radiusSm),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroImage(w),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.backgroundDark],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Name + role at bottom
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(w.name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: w.isAvailable
                          ? AppTheme.greenSuccess.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(
                        color: w.isAvailable ? AppTheme.greenSuccess : Colors.white24,
                      ),
                    ),
                    child: Text(w.isAvailable ? '✓ Available Now' : '✗ Offline',
                        style: TextStyle(
                          color: w.isAvailable ? AppTheme.greenSuccess : AppTheme.textMuted,
                          fontSize: 11, fontWeight: FontWeight.w600,
                        )),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(w.subRole ?? w.serviceCategory ?? '',
                    style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(AppUser w) {
    if (w.hasProfileImage) {
      try {
        final bytes = base64Decode(w.profileImageBase64!);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    final colors = _avatarGradients[w.serviceCategory] ?? [AppTheme.tealDark, AppTheme.tealPrimary];
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_categoryEmoji[w.serviceCategory] ?? '👷', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(w.name.split(' ').map((e) => e[0]).take(2).join(),
              style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatRow(AppUser w) {
    return Row(children: [
      _statCard('⭐', w.rating.toStringAsFixed(1), 'Rating'),
      const SizedBox(width: 10),
      _statCard('💼', '${w.totalJobs}', 'Jobs Done'),
      const SizedBox(width: 10),
      _statCard('🕐', '${w.experienceYears ?? 1}y', 'Experience'),
      const SizedBox(width: 10),
      _statCard('💰', 'Rs.${(w.baseRatePkr ?? 0).toInt()}', 'Per Hour'),
    ].map((e) => Expanded(child: e)).toList().cast<Widget>());
  }

  Widget _statCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  // ── Section container ──────────────────────────────────────────────────────
  Widget _buildSection(String title, IconData icon, Color color, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        content,
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSpecRow(AppUser w) {
    return Row(children: [
      const Icon(Icons.category_outlined, color: AppTheme.tealPrimary, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Category: ${w.serviceCategory ?? "—"}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        if (w.subRole != null)
          Text('Specialty: ${w.subRole}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text('Based in: ${w.area.isNotEmpty ? "${w.area}, " : ""}${w.city}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ])),
    ]);
  }

  Widget _buildSkillChips(AppUser w) {
    final skills = w.skills ?? [];
    if (skills.isEmpty) return const Text('No skills listed.', style: TextStyle(color: AppTheme.textMuted));
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: skills.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.purpleAgent.withValues(alpha: 0.12),
          borderRadius: AppTheme.radiusSm,
          border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
        ),
        child: Text(s, style: const TextStyle(color: AppTheme.purpleLight, fontSize: 12, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Widget _buildServiceDetails(AppUser w) {
    final items = [
      ('💰 Hourly Rate', w.rateDisplay.isNotEmpty ? w.rateDisplay : 'Negotiable'),
      ('📅 Experience', '${w.experienceYears ?? 1} year${(w.experienceYears ?? 1) == 1 ? '' : 's'}'),
      ('📍 Service Area', w.city),
      ('✅ Status', w.isAvailable ? 'Available Now' : 'Currently Busy'),
    ];
    return Column(
      children: items.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 130, child: Text(e.$1, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          Expanded(child: Text(e.$2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      )).toList(),
    );
  }

  Widget _buildContactCard(AppUser w) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.tealPrimary.withValues(alpha: 0.1),
          AppTheme.blueInfo.withValues(alpha: 0.05),
        ]),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.phone_outlined, color: AppTheme.tealPrimary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Contact', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          Text(w.phone, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
            borderRadius: AppTheme.radiusSm,
          ),
          child: const Text('Show Number', style: TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── Bottom booking bar ────────────────────────────────────────────────────
  Widget _buildBookingBar(AppUser w) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        // Rate display
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(w.rateDisplay.isNotEmpty ? w.rateDisplay : 'Negotiable',
              style: const TextStyle(color: AppTheme.goldAccent, fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('per hour', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: (_workerBanned || !w.isAvailable || _bookingRequested) ? null : _requestBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: w.isAvailable && !_workerBanned ? AppTheme.tealPrimary : AppTheme.textMuted.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
              elevation: 0,
            ),
            child: Text(
              _workerBanned ? '🚫 Worker Suspended'
                  : !w.isAvailable ? '⏸ Currently Offline'
                  : _bookingRequested ? '✓ Request Sent!'
                  : '📅 Book ${w.name.split(' ').first}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ]),
    );
  }

  void _requestBooking() {
    HapticFeedback.heavyImpact();
    setState(() => _bookingRequested = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Booking request sent to ${widget.worker.name}!'),
      backgroundColor: AppTheme.greenSuccess.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
    ));
    // Navigate back after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  static const _categoryEmoji = {
    'Plumber': '🔧', 'Electrician': '⚡', 'AC Technician': '❄️',
    'Carpenter': '🪚', 'Painter': '🎨', 'Cleaner': '🧹',
    'Driver': '🚗', 'Security Guard': '🛡️', 'Cook': '👨‍🍳', 'Mason': '🧱',
  };

  static final _avatarGradients = {
    'Plumber': [const Color(0xFF1E3A5F), const Color(0xFF3B82F6)],
    'Electrician': [const Color(0xFF4A1E0A), const Color(0xFFF59E0B)],
    'AC Technician': [const Color(0xFF0A3A4A), const Color(0xFF00BFA5)],
    'Carpenter': [const Color(0xFF3A2A0A), const Color(0xFFB45309)],
    'Painter': [const Color(0xFF2A0A3A), const Color(0xFF8B5CF6)],
    'Cleaner': [const Color(0xFF0A3A1E), const Color(0xFF22C55E)],
    'Driver': [const Color(0xFF1A1A3A), const Color(0xFF6366F1)],
    'Security Guard': [const Color(0xFF3A0A0A), const Color(0xFFEF4444)],
  };
}
