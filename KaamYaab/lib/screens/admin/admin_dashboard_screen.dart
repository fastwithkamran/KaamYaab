import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<AppUser> _allUsers = [];
  List<String> _bannedUids = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final users = await AuthService().getAllUsers();
    final banned = await AuthService().getBannedUids();
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _bannedUids = banned;
      _loading = false;
    });
  }

  List<AppUser> get _filtered =>
      _allUsers.where(_matches).toList();
  List<AppUser> get _workers =>
      _allUsers.where((u) => u.isWorker && _matches(u)).toList();
  List<AppUser> get _customers =>
      _allUsers.where((u) => u.isCustomer && _matches(u)).toList();

  bool _matches(AppUser u) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return u.name.toLowerCase().contains(q) ||
        u.phone.contains(q) ||
        u.city.toLowerCase().contains(q);
  }

  bool _isBanned(String uid) => _bannedUids.contains(uid);

  Future<void> _toggleBan(AppUser user) async {
    HapticFeedback.mediumImpact();
    if (_isBanned(user.uid)) {
      await AuthService().unbanUser(user.uid);
      if (!mounted) return;
      _showSnack('✅ ${user.name} has been unbanned.', AppTheme.greenSuccess);
    } else {
      final confirmed = await _showDialog(
        title: 'Ban ${user.name}?',
        message: 'They won\'t be able to log in until unbanned.',
        confirmLabel: 'Ban User',
        confirmColor: AppTheme.redError,
      );
      if (!confirmed) return;
      await AuthService().banUser(user.uid);
      if (!mounted) return;
      _showSnack('🚫 ${user.name} has been banned.', AppTheme.redError);
    }
    await _loadData();
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await _showDialog(
      title: 'Remove ${user.name}?',
      message: 'This permanently deletes their account. Cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.redError,
    );
    if (!confirmed) return;
    await AuthService().deleteUser(user.uid);
    if (!mounted) return;
    _showSnack('🗑️ Account removed.', AppTheme.textMuted);
    await _loadData();
  }

  Future<bool> _showDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            confirmColor: confirmColor,
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
    ));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🛡️ Admin Panel',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Super Admin · KaamYaab',
                          style: TextStyle(color: AppTheme.goldAccent.withValues(alpha: 0.8), fontSize: 12)),
                    ]),
                  ),
                  _StatBadge(label: 'Total', value: _allUsers.length.toString()),
                  const SizedBox(width: 8),
                  _StatBadge(label: 'Banned', value: _bannedUids.length.toString(), color: AppTheme.redError),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, color: AppTheme.tealPrimary),
                    tooltip: 'Refresh',
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 12),

              // ── Search ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or city...',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.radiusMd,
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppTheme.radiusMd,
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.radiusMd,
                      borderSide: const BorderSide(color: AppTheme.tealPrimary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Tabs ──────────────────────────────────────────────────────
              TabBar(
                controller: _tabCtrl,
                indicatorColor: AppTheme.tealPrimary,
                labelColor: AppTheme.tealPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: 'All (${_filtered.length})'),
                  Tab(text: 'Workers (${_workers.length})'),
                  Tab(text: 'Customers (${_customers.length})'),
                ],
              ),

              // ── Tab content ───────────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary))
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _UserList(users: _filtered, bannedUids: _bannedUids,
                              onToggleBan: _toggleBan, onDelete: _deleteUser),
                          _UserList(users: _workers, bannedUids: _bannedUids,
                              onToggleBan: _toggleBan, onDelete: _deleteUser),
                          _UserList(users: _customers, bannedUids: _bannedUids,
                              onToggleBan: _toggleBan, onDelete: _deleteUser),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User list ─────────────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final List<AppUser> users;
  final List<String> bannedUids;
  final Future<void> Function(AppUser) onToggleBan;
  final Future<void> Function(AppUser) onDelete;

  const _UserList({
    required this.users,
    required this.bannedUids,
    required this.onToggleBan,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('👥', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No users found',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = users[i];
        return _UserTile(
          user: u,
          banned: bannedUids.contains(u.uid),
          onToggleBan: () => onToggleBan(u),
          onDelete: () => onDelete(u),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms);
      },
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool banned;
  final VoidCallback onToggleBan;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.banned,
    required this.onToggleBan,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = user.isWorker ? AppTheme.purpleAgent : AppTheme.tealPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: banned
            ? AppTheme.redError.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(
          color: banned
              ? AppTheme.redError.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Name + role
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(user.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                _Pill(
                    label: user.isWorker ? '🔧 Worker' : '🏠 Customer',
                    color: accent),
                if (banned) ...[
                  const SizedBox(width: 6),
                  _Pill(label: '🚫 BANNED', color: AppTheme.redError),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${user.phone}  ·  ${user.city}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
        ]),

        // Worker extra info
        if (user.isWorker && user.serviceCategory != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.build_outlined, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(user.serviceCategory!,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.star, size: 13, color: AppTheme.goldAccent),
            const SizedBox(width: 4),
            Text(user.rating.toStringAsFixed(1),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(width: 12),
            Text('${user.totalJobs} jobs',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ]),
        ],

        const SizedBox(height: 10),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 6),

        // Actions
        Row(children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onToggleBan,
              icon: Icon(
                banned ? Icons.lock_open_outlined : Icons.block,
                size: 16,
                color: banned ? AppTheme.greenSuccess : AppTheme.redError,
              ),
              label: Text(
                banned ? 'Unban' : 'Ban',
                style: TextStyle(
                  color: banned ? AppTheme.greenSuccess : AppTheme.redError,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
          Container(width: 1, height: 20, color: Colors.white12),
          Expanded(
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textMuted),
              label: const Text('Remove',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppTheme.radiusSm,
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, this.color = AppTheme.tealPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, color: confirmColor, size: 44),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                  elevation: 0,
                ),
                child: Text(confirmLabel),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}