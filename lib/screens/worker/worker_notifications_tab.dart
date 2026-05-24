import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/worker_notification_service.dart';

class WorkerNotificationsTab extends StatefulWidget {
  const WorkerNotificationsTab({super.key});

  @override
  State<WorkerNotificationsTab> createState() => _WorkerNotificationsTabState();
}

class _WorkerNotificationsTabState extends State<WorkerNotificationsTab> {
  final bool _isUrdu = LanguageService().isUrdu;
  final _notifService = WorkerNotificationService();

  String _t(String en, String ur) => _isUrdu ? ur : en;

  Color _getNotifColor(WorkerNotifType type) {
    switch (type) {
      case WorkerNotifType.booking:
        return AppTheme.tealPrimary;
      case WorkerNotifType.negotiation:
        return AppTheme.purpleLight;
      case WorkerNotifType.dispute:
        return AppTheme.redAlert;
    }
  }

  IconData _getNotifIcon(WorkerNotifType type) {
    switch (type) {
      case WorkerNotifType.booking:
        return Icons.star_rounded;
      case WorkerNotifType.negotiation:
        return Icons.handshake_rounded;
      case WorkerNotifType.dispute:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = AuthService().currentUser;
    if (worker == null) {
      return Center(
        child: Text(
          _t('Please log in', 'براہ کرم لاگ ان کریں'),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<WorkerNotification>>(
        stream: _notifService.watchNotifications(worker.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealPrimary),
            );
          }

          final notifications = snapshot.data ?? [];
          // Derive unread count from the same list — no second Firestore stream needed.
          final unreadCount = notifications.where((n) => !n.isRead).length;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                _t('Notifications', 'نوٹیفیکیشنز'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              actions: [
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final messenger = ScaffoldMessenger.of(context);
                      await _notifService.markAllRead(worker.uid);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(_t('All marked as read', 'تمام پڑھے ہوئے نشان زد کر دیے گئے')),
                          backgroundColor: AppTheme.tealPrimary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.done_all, color: AppTheme.tealPrimary, size: 18),
                    label: Text(
                      _t('Mark all read', 'سب پڑھیں'),
                      style: const TextStyle(
                        color: AppTheme.tealPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return _buildNotifCard(notif, worker.uid)
                          .animate()
                          .fadeIn(duration: 350.ms, delay: Duration(milliseconds: 50 * index))
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: AppTheme.textMuted.withValues(alpha: 0.6),
              size: 48,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            _t('All caught up!', 'کوئی نیا نوٹیفیکیشن نہیں ہے!'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('New updates and booking offers will appear here.', 'نئے نوٹیفیکیشنز یہاں ظاہر ہوں گے۔'),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(WorkerNotification notif, String workerUid) {
    final themeColor = _getNotifColor(notif.type);
    final themeIcon = _getNotifIcon(notif.type);

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          _notifService.markRead(workerUid, notif.id);
        }
      },
      borderRadius: AppTheme.radiusLg,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead ? AppTheme.cardDark : AppTheme.cardDark.withValues(alpha: 0.85),
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: notif.isRead
                ? Colors.white.withValues(alpha: 0.06)
                : themeColor.withValues(alpha: 0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: notif.isRead
              ? []
              : [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                themeIcon,
                color: themeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Details section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.body,
                    style: TextStyle(
                      color: notif.isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return _t('Just now', 'ابھی ابھی');
    } else if (diff.inMinutes < 60) {
      return _t('${diff.inMinutes}m ago', '${diff.inMinutes} منٹ پہلے');
    } else if (diff.inHours < 24) {
      return _t('${diff.inHours}h ago', '${diff.inHours} گھنٹے پہلے');
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
