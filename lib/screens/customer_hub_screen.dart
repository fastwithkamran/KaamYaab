import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../services/booking_history_service.dart';
import '../services/provider_data_service.dart';
import 'simulation_dashboard_screen.dart';
import 'disputes_tab.dart';
import '../services/customer_notification_service.dart';

class CustomerHubScreen extends StatefulWidget {
  const CustomerHubScreen({super.key});

  @override
  State<CustomerHubScreen> createState() => _CustomerHubScreenState();
}

class _CustomerHubScreenState extends State<CustomerHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _lang = LanguageService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _t(String en, String ur) => _lang.t(en, ur);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _BookingHistoryTab(lang: _lang),
                    _CustomerNotificationsTab(lang: _lang),
                    _SettingsTab(lang: _lang, onLangChanged: () => setState(() {})),
                    DisputesTab(lang: _lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = AuthService().currentUser;
    final name = user?.name ?? 'User';
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: AppTheme.tealPrimary.withValues(alpha: 0.04), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.tealGlow,
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppTheme.greenSuccess),
                    ),
                    const SizedBox(width: 5),
                    Text(_t('Customer Account', 'کسٹمر اکاؤنٹ'),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: BookingHistoryService().watchCurrentUserBookings(),
            builder: (context, snapshot) {
              final bookingCount = snapshot.data?.length ?? user?.totalJobs ?? 0;
              final rating = user?.rating == 0.0 ? 5.0 : (user?.rating ?? 5.0);
              return Row(
                children: [
                  _HeaderStat(label: _t('Jobs', 'جابز'), value: bookingCount.toString()),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.07)),
                  const SizedBox(width: 12),
                  _HeaderStat(label: _t('Rating', 'ریٹنگ'), value: '${rating.toStringAsFixed(1)}⭐'),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  Widget _buildTabBar() {
    final user = AuthService().currentUser;
    final uid = user?.uid ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: AppTheme.tealPrimary.withValues(alpha: 0.3), blurRadius: 10)
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.history_rounded, size: 12),
            const SizedBox(width: 4),
            Text(_t('History', 'تاریخ')),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            StreamBuilder<int>(
              stream: CustomerNotificationService().watchUnreadCount(uid),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.tealPrimary,
                  child: const Icon(Icons.notifications_rounded, size: 12),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(_t('Inbox', 'ان باکس')),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.tune_rounded, size: 12),
            const SizedBox(width: 4),
            Text(_t('Settings', 'ترتیبات')),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.gavel_rounded, size: 12),
            const SizedBox(width: 4),
            Text(_t('Disputes', 'تنازعات')),
          ])),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

// ── Header Stat Widget ────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ── Booking History Tab ───────────────────────────────────────────────────────
class _BookingHistoryTab extends StatefulWidget {
  final LanguageService lang;
  const _BookingHistoryTab({required this.lang});

  @override
  State<_BookingHistoryTab> createState() => _BookingHistoryTabState();
}

class _BookingHistoryTabState extends State<_BookingHistoryTab> {
  late final Stream<List<Map<String, dynamic>>> _bookingsStream;

  @override
  void initState() {
    super.initState();
    _bookingsStream = BookingHistoryService().watchCurrentUserBookings();
  }

  String _t(String en, String ur) => widget.lang.t(en, ur);

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}
    return null;
  }

  String _formatDate(dynamic value) {
    final dt = _toDate(value);
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealPrimary));
        }

        final bookings = snapshot.data ?? const <Map<String, dynamic>>[];
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      AppTheme.tealPrimary.withValues(alpha: 0.1),
                      AppTheme.tealDark.withValues(alpha: 0.05),
                    ]),
                    border: Border.all(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.2)),
                  ),
                  child: const Center(child: Text('📋', style: TextStyle(fontSize: 38))),
                ),
                const SizedBox(height: 20),
                Text(_t('No bookings yet', 'ابھی کوئی بکنگ نہیں'),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Your booking history will appear here\nonce you place your first order.',
                    'جب آپ پہلی بار بکنگ کریں گے تو\nیہاں ظاہر ہو گا۔',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/workers'),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(_t('Browse Workers', 'کارکن تلاش کریں')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: bookings.length,
          itemBuilder: (_, i) {
            final b = bookings[i];
            return _BookingTile(
              booking: {
                ...b,
                'service': b['service_type'] ?? b['service'] ?? 'Service',
                'worker': b['provider_name'] ?? b['worker'] ?? '',
                'status': b['status'] ?? 'completed',
                'date': _formatDate(b['created_at'] ?? b['date']),
              },
              lang: widget.lang,
              index: i,
            );
          },
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  final LanguageService lang;
  final int index;
  const _BookingTile(
      {required this.booking, required this.lang, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'completed';
    final color = status == 'completed'
        ? AppTheme.greenSuccess
        : status == 'pending'
            ? AppTheme.goldAccent
            : AppTheme.redAlert;
    final serviceIcon = _serviceIcon(booking['service'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Center(child: Text(serviceIcon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking['service'] as String? ?? 'Service',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text('${booking['worker'] ?? 'Worker'} · ${booking['date'] ?? ''}',
                        style:
                            const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: Text(
                  status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              if (booking['final_price_pkr'] != null) ...[
                const SizedBox(height: 3),
                Text('Rs. ${double.tryParse(booking['final_price_pkr'].toString())?.toInt() ?? 0}',
                    style: const TextStyle(
                        color: AppTheme.tealPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideY(begin: 0.05);
  }

  String _serviceIcon(String service) {
    final s = service.toLowerCase();
    if (s.contains('plumb')) return '🔧';
    if (s.contains('electric')) return '⚡';
    if (s.contains('ac') || s.contains('air')) return '❄️';
    if (s.contains('carpen')) return '🔨';
    if (s.contains('paint')) return '🎨';
    if (s.contains('clean')) return '🧹';
    return '🛠️';
  }
}

// ── Settings Tab ──────────────────────────────────────────────────────────────
class _SettingsTab extends StatefulWidget {
  final LanguageService lang;
  final VoidCallback onLangChanged;
  const _SettingsTab({required this.lang, required this.onLangChanged});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _notificationsOn = true;

  String _t(String en, String ur) => widget.lang.t(en, ur);

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.lang.isUrdu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionTitle(title: _t('LANGUAGE', 'زبان')),
        _SettingRow(
          icon: Icons.language_rounded,
          iconColor: AppTheme.blueInfo,
          title: _t('App Language', 'ایپ کی زبان'),
          subtitle: isUrdu ? 'اردو میں چل رہی ہے' : 'Running in English',
          trailing: _LanguageToggle(
            isUrdu: isUrdu,
            onToggle: () async {
              HapticFeedback.selectionClick();
              await widget.lang.setUrdu(!isUrdu);
              widget.onLangChanged();
              setState(() {});
            },
          ),
        ),

        const SizedBox(height: 20),
        _SectionTitle(title: _t('NOTIFICATIONS', 'اطلاعات')),
        _SettingRow(
          icon: Icons.notifications_rounded,
          iconColor: AppTheme.purpleAgent,
          title: _t('Push Notifications', 'پش نوٹیفکیشن'),
          subtitle: _t('Booking updates & alerts', 'بکنگ اپڈیٹس اور الرٹس'),
          trailing: Switch(
            value: _notificationsOn,
            onChanged: (v) => setState(() => _notificationsOn = v),
            activeThumbColor: AppTheme.tealPrimary,
          ),
        ),

        const SizedBox(height: 20),
        _SectionTitle(title: _t('ACCOUNT', 'اکاؤنٹ')),
        _SettingRow(
          icon: Icons.person_outline_rounded,
          iconColor: AppTheme.tealPrimary,
          title: _t('Edit Profile', 'پروفائل ترمیم کریں'),
          subtitle: _t('Name, phone, address', 'نام، فون، پتہ'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          onTap: () {},
        ),
        _SettingRow(
          icon: Icons.security_rounded,
          iconColor: AppTheme.goldAccent,
          title: _t('Privacy & Security', 'رازداری اور سیکیورٹی'),
          subtitle: _t('Password & data', 'پاس ورڈ اور ڈیٹا'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          onTap: () {},
        ),

        const SizedBox(height: 20),
        _SectionTitle(title: _t('DEVELOPER TOOLS', 'ڈیولپر ٹولز')),
        _SettingRow(
          icon: Icons.science_rounded,
          iconColor: AppTheme.purpleAgent,
          title: _t('Hackathon Simulator', 'ہیکاتھون سمیلیٹر'),
          subtitle: _t(
            'Test notifications, tracking & disputes',
            'نوٹیفکیشن، ٹریکنگ اور تنازعات',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.purpleAgent.withValues(alpha: 0.15),
              borderRadius: AppTheme.radiusSm,
            ),
            child: const Text('DEV',
                style: TextStyle(
                    color: AppTheme.purpleAgent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SimulationDashboardScreen()),
          ),
        ),

        // Seed Firestore — seeds mock service providers from the bundled
        // JSON asset only. Demo workers have been removed permanently.
        _SettingRow(
          icon: Icons.upload_rounded,
          iconColor: AppTheme.blueInfo,
          title: _t('Seed Firestore', 'فائر اسٹور میں ڈیٹا ڈالیں'),
          subtitle: _t(
            'Upload mock service providers',
            'موک سروس پرووائیڈر اپلوڈ کریں',
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
                const SnackBar(content: Text('Seeding Firestore...')));
            try {
              await ProviderDataService().seedProvidersFromMockAsset();
              if (messenger.mounted) {
                messenger.showSnackBar(
                    const SnackBar(content: Text('✅ Firestore Seeded!')));
              }
            } catch (_) {
              if (messenger.mounted) {
                messenger.showSnackBar(
                    const SnackBar(content: Text('⚠️ Seeding failed.')));
              }
            }
          },
        ),

        const SizedBox(height: 28),
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            AuthService().signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.redAlert.withValues(alpha: 0.07),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppTheme.redAlert, size: 18),
                SizedBox(width: 8),
                Text('Sign Out',
                    style: TextStyle(
                        color: AppTheme.redAlert,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }
}

// ── Language Toggle ───────────────────────────────────────────────────────────
class _LanguageToggle extends StatelessWidget {
  final bool isUrdu;
  final VoidCallback onToggle;
  const _LanguageToggle({required this.isUrdu, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 72, height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isUrdu ? AppTheme.tealPrimary : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: isUrdu
                  ? AppTheme.tealPrimary
                  : AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment:
              isUrdu ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration:
                  const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  isUrdu ? 'اع' : 'EN',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isUrdu ? AppTheme.tealPrimary : AppTheme.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Notifications Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerNotificationsTab extends StatefulWidget {
  final LanguageService lang;
  const _CustomerNotificationsTab({required this.lang});

  @override
  State<_CustomerNotificationsTab> createState() => _CustomerNotificationsTabState();
}

class _CustomerNotificationsTabState extends State<_CustomerNotificationsTab> {
  final _notifService = CustomerNotificationService();

  String _t(String en, String ur) => widget.lang.t(en, ur);

  Color _getNotifColor(CustomerNotifType type) {
    switch (type) {
      case CustomerNotifType.enRoute:
        return AppTheme.tealPrimary;
      case CustomerNotifType.arrived:
        return AppTheme.greenSuccess;
      case CustomerNotifType.completed:
        return AppTheme.goldAccent;
      case CustomerNotifType.counterOffer:
        return AppTheme.purpleLight;
    }
  }

  IconData _getNotifIcon(CustomerNotifType type) {
    switch (type) {
      case CustomerNotifType.enRoute:
        return Icons.directions_car_rounded;
      case CustomerNotifType.arrived:
        return Icons.person_pin_circle_rounded;
      case CustomerNotifType.completed:
        return Icons.check_circle_rounded;
      case CustomerNotifType.counterOffer:
        return Icons.handshake_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = AuthService().currentUser;
    if (customer == null) {
      return Center(
        child: Text(
          _t('Please log in', 'براہ کرم لاگ ان کریں'),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<CustomerNotification>>(
        stream: _notifService.watchNotifications(customer.uid),
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
                _t('Activity Inbox', 'ان باکس'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              actions: [
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final messenger = ScaffoldMessenger.of(context);
                      await _notifService.markAllRead(customer.uid);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(_t('All marked as read', 'تمام پڑھے ہوئے نشان زد کر دیے گئے')),
                          backgroundColor: AppTheme.tealPrimary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.done_all, color: AppTheme.tealPrimary, size: 16),
                    label: Text(
                      _t('Mark all read', 'سب پڑھیں'),
                      style: const TextStyle(
                        color: AppTheme.tealPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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
                      return _buildNotifCard(notif, customer.uid)
                          .animate()
                          .fadeIn(duration: 350.ms, delay: Duration(milliseconds: 50 * index))
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutQuad);
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
              Icons.notifications_none_rounded,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
              size: 44,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(
            _t('No updates yet!', 'کوئی نیا نوٹیفیکیشن نہیں ہے!'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('Updates on your active bookings and counter-offers will appear here.', 'بکنگ اور کارکن کے جوابات یہاں ظاہر ہوں گے۔'),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(CustomerNotification notif, String customerUid) {
    final themeColor = _getNotifColor(notif.type);
    final themeIcon = _getNotifIcon(notif.type);

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          _notifService.markRead(customerUid, notif.id);
        }
      },
      borderRadius: AppTheme.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? AppTheme.cardDark : AppTheme.cardDark.withValues(alpha: 0.85),
          borderRadius: AppTheme.radiusMd,
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
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                themeIcon,
                color: themeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Text Details
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
                            fontSize: 13,
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
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      color: notif.isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
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