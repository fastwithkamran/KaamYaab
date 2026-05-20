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
    _tabController = TabController(length: 3, vsync: this);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.tealPrimary.withValues(alpha: 0.12),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
            ),
            child: const Center(child: Text('👤', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('My Account', 'میرا اکاؤنٹ'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _t('Bookings, Settings & More', 'بکنگ، ترتیبات اور مزید'),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.tealPrimary.withValues(alpha: 0.2),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppTheme.tealPrimary,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: _t('History', 'تاریخ')),
          Tab(text: _t('Settings', 'ترتیبات')),
          Tab(text: _t('Disputes', 'تنازعات')),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

// ── Booking History Tab ──────────────────────────────────────────────────────
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
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.tealPrimary),
          );
        }

        final bookings = snapshot.data ?? const <Map<String, dynamic>>[];
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.tealPrimary.withValues(alpha: 0.08),
                    border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.15)),
                  ),
                  child: const Center(
                    child: Text('📋', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _t('No bookings yet', 'ابھی کوئی بکنگ نہیں'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Your booking history will appear here\nonce you place your first order.',
                    'جب آپ پہلی بار بکنگ کریں گے تو\nیہاں ظاہر ہو گا۔',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(_t('Find a Worker', 'کارکن تلاش کریں')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.tealPrimary,
                    side: const BorderSide(color: AppTheme.tealPrimary),
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
  const _BookingTile({required this.booking, required this.lang});

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'completed';
    final color = status == 'completed'
        ? AppTheme.greenSuccess
        : status == 'pending'
            ? AppTheme.goldAccent
            : AppTheme.redAlert;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Icon(Icons.build_rounded, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['service'] as String? ?? 'Service',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${booking['worker'] ?? ''} · ${booking['date'] ?? ''}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppTheme.radiusSm,
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings Tab ─────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(20),
      children: [
        // Language
        _SectionTitle(title: _t('Language', 'زبان')),
        _SettingRow(
          icon: Icons.language_rounded,
          title: _t('App Language', 'ایپ کی زبان'),
          subtitle: isUrdu ? 'اردو' : 'English',
          trailing: GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              await widget.lang.setUrdu(!isUrdu);
              widget.onLangChanged();
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: isUrdu ? AppTheme.tealPrimary : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUrdu ? AppTheme.tealPrimary : AppTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    isUrdu ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isUrdu ? 'اع' : 'EN',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: isUrdu ? AppTheme.tealPrimary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        _SectionTitle(title: _t('Notifications', 'اطلاعات')),
        _SettingRow(
          icon: Icons.notifications_rounded,
          title: _t('Push Notifications', 'پش نوٹیفکیشن'),
          subtitle: _t('Booking updates & alerts', 'بکنگ اپڈیٹس اور الرٹس'),
          trailing: Switch(
            value: _notificationsOn,
            onChanged: (v) => setState(() => _notificationsOn = v),
            activeThumbColor: AppTheme.tealPrimary,
          ),
        ),

        const SizedBox(height: 24),
        _SectionTitle(title: _t('Account', 'اکاؤنٹ')),
        _SettingRow(
          icon: Icons.person_outline_rounded,
          title: _t('Edit Profile', 'پروفائل ترمیم کریں'),
          subtitle: _t('Name, phone, address', 'نام، فون، پتہ'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          onTap: () {},
        ),
        _SettingRow(
          icon: Icons.security_rounded,
          title: _t('Privacy & Security', 'رازداری اور سیکیورٹی'),
          subtitle: _t('Password & data', 'پاس ورڈ اور ڈیٹا'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          onTap: () {},
        ),

        const SizedBox(height: 24),
        _SectionTitle(title: _t('Developer Tools', 'ڈیولپر ٹولز')),
        _SettingRow(
          icon: Icons.bug_report_rounded,
          title: _t('Hackathon Simulator', 'ہیکاتھون سمیلیٹر'),
          subtitle: _t('Test in-app notifications, En-Route, Disputes', 'ان-ایپ نوٹیفکیشن، راستے کی اپڈیٹس، تنازعات'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.tealPrimary),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationDashboardScreen())),
        ),
        _SettingRow(
          icon: Icons.upload_rounded,
          title: _t('Seed Firestore', 'فائر اسٹور میں ڈیٹا ڈالیں'),
          subtitle: _t('Upload demo providers + users', 'ڈیمو پرووائیڈر اور یوزرز اپلوڈ کریں'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.tealPrimary),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(const SnackBar(content: Text('Seeding Firestore...')));
            try {
              await ProviderDataService().seedProvidersFromMockAsset();
              await AuthService().seedDemoData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Firestore Seeded!')),
              );
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Seeding failed. Please try again.')),
              );
            }
          },
        ),

        const SizedBox(height: 32),
        // Sign out
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            AuthService().signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.redAlert.withValues(alpha: 0.08),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.redAlert.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: AppTheme.redAlert, size: 18),
                const SizedBox(width: 8),
                Text(
                  _t('Sign Out', 'سائن آؤٹ'),
                  style: const TextStyle(
                    color: AppTheme.redAlert,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }
}


// ── Shared small widgets ─────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
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
          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tealPrimary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: AppTheme.tealPrimary, size: 18),
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
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
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
