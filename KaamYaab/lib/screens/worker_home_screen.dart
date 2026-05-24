import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/worker_notification_service.dart';
import '../widgets/worker_agent_chat.dart';
import 'worker/worker_home_tab.dart';
import 'worker/worker_jobs_tab.dart';
import 'worker/worker_notifications_tab.dart';
import 'worker/worker_profile_tab.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _currentIndex = 0;
  int _profileVersion = 0;
  int _unreadCount = 0;
  StreamSubscription<int>? _notifSub;

  final bool _isUrdu = LanguageService().isUrdu;

  String _t(String en, String ur) => _isUrdu ? ur : en;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  /// Subscribes to the unread notification count for the signed-in worker.
  /// Using a single StreamSubscription here avoids the two separate Firestore
  /// listeners that the previous `StreamBuilder` approach inside `icon:`/
  /// `activeIcon:` created. The count is stored as a plain state field so
  /// the nav bar can read it synchronously on every build.
  void _subscribeToNotifications() {
    final workerUid = AuthService().currentUser?.uid ?? '';
    if (workerUid.isEmpty) return;
    _notifSub = WorkerNotificationService()
        .watchUnreadCount(workerUid)
        .listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _triggerProfileRefresh() {
    setState(() {
      _profileVersion++;
    });
  }

  void _openVoiceAgent() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          const WorkerAgentChatBottomSheet(initialMode: AgentInputMode.voice),
    ).then((_) {
      _triggerProfileRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define tabs. Home and Profile tabs use a key with version to force reload on updates.
    final List<Widget> tabs = [
      WorkerHomeTab(
        key: ValueKey('home_tab_$_profileVersion'),
        onEditProfile: _openVoiceAgent,
      ),
      const WorkerJobsTab(),
      const WorkerNotificationsTab(),
      WorkerProfileTab(
        key: ValueKey('profile_tab_$_profileVersion'),
        onEditProfile: _openVoiceAgent,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          backgroundColor: AppTheme.cardDark,
          selectedItemColor: AppTheme.tealPrimary,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
          elevation: 8,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home, color: AppTheme.tealPrimary),
              label: _t('Home', 'ہوم'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.work_outline),
              activeIcon: const Icon(Icons.work, color: AppTheme.tealPrimary),
              label: _t('Jobs', 'کام'),
            ),
            BottomNavigationBarItem(
              icon: _notifBadge(active: false),
              activeIcon: _notifBadge(active: true),
              label: _t('Inbox', 'ان باکس'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon:
                  const Icon(Icons.person, color: AppTheme.tealPrimary),
              label: _t('Profile', 'پروفائل'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the notification badge icon for the Inbox nav item.
  Widget _notifBadge({required bool active}) {
    return Badge(
      isLabelVisible: _unreadCount > 0,
      label: Text(
        '$_unreadCount',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      backgroundColor: AppTheme.tealPrimary,
      child: Icon(
        active ? Icons.notifications : Icons.notifications_outlined,
        color: active ? AppTheme.tealPrimary : null,
      ),
    );
  }
}