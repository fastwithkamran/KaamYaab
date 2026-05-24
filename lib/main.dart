import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/worker_home_screen.dart';
import 'screens/customer_hub_screen.dart';
import 'screens/simulation_dashboard_screen.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/language_selection_screen.dart';
import 'screens/workers_browse_screen.dart';
import 'screens/voice_booking_agent.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  // FIX: Track init result so providers can degrade gracefully instead of
  // crashing later with confusing errors when Firestore calls are made.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('⚠️  Firebase init failed — running in offline/demo mode: $e');
  }

  // ── Services ──────────────────────────────────────────────────────────────
  try {
    await AuthService().init();
  } catch (e) {
    debugPrint('⚠️  AuthService init failed: $e');
  }

  try {
    await LanguageService().init();
  } catch (e) {
    debugPrint('⚠️  LanguageService init failed: $e');
  }

  // ── Orientation & UI ──────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundDark,
    ),
  );

  // FIX: Removed `const` from ProviderScope — ProviderScope with overrides
  // cannot be const, and const blocked adding overrides (e.g. for testing).
  runApp(
    ProviderScope(
      overrides: [
        // Exposes Firebase availability so any provider can check it before
        // making Firestore/Auth calls, rather than crashing blindly.
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const KaamYaabApp(),
    ),
  );
}

/// Exposes Firebase init status to the Riverpod provider tree.
/// Usage in any provider: `final ready = ref.watch(firebaseReadyProvider);`
final firebaseReadyProvider = Provider<bool>((ref) => false);

class KaamYaabApp extends StatelessWidget {
  const KaamYaabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KaamYaab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/lang': (context) => const LanguageSelectionScreen(),
        '/login': (context) => const RoleSelectScreen(),
        '/home': (context) => const MainShell(),
        '/dashboard': (context) => const WorkerHomeScreen(),
        '/workers': (context) => const WorkersBrowseScreen(),
        '/voice-booking': (context) => const VoiceBookingAgent(),
        '/hub': (context) => const CustomerHubScreen(),
        '/agent-logs': (context) => const SimulationDashboardScreen(),
        // Legacy aliases
        '/provider-dashboard': (context) => const WorkerHomeScreen(),
      },
      // BookingFlowScreen is pushed via Navigator.push (requires params)
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late final AnimationController _navAnimCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      WorkersBrowseScreen(),
      CustomerHubScreen(),
    ];
    _navAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _itemCtrls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _itemCtrls[0].forward();
  }

  @override
  void dispose() {
    _navAnimCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _itemCtrls[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _itemCtrls[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        itemCtrls: _itemCtrls,
        onTap: _onNavTap,
      ),
    );
  }
}

// ── Floating Glass Bottom Nav Bar ────────────────────────────────────────────
class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final List<AnimationController> itemCtrls;
  final Function(int) onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.itemCtrls,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItemData(Icons.people_rounded, Icons.people_outlined, 'Browse'),
    _NavItemData(Icons.account_circle_rounded, Icons.account_circle_outlined, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.95),
        borderRadius: AppTheme.radiusXl,
        border: Border.all(
          color: AppTheme.tealPrimary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.tealPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              return _GlassNavItem(
                data: _items[i],
                isActive: currentIndex == i,
                ctrl: itemCtrls[i],
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavItemData(this.activeIcon, this.inactiveIcon, this.label);
}

class _GlassNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final AnimationController ctrl;
  final VoidCallback onTap;

  const _GlassNavItem({
    required this.data,
    required this.isActive,
    required this.ctrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          final t = ctrl.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.tealPrimary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: AppTheme.radiusLg,
              border: isActive
                  ? Border.all(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + 0.12 * t,
                  child: Icon(
                    isActive ? data.activeIcon : data.inactiveIcon,
                    color: isActive
                        ? AppTheme.tealPrimary
                        : AppTheme.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.tealPrimary
                        : AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: isActive ? 0.3 : 0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}