import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import 'simulation_dashboard_screen.dart';

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
                    _SupportTab(lang: _lang),
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
          Tab(text: _t('Support', 'مدد')),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

// ── Booking History Tab ──────────────────────────────────────────────────────
class _BookingHistoryTab extends StatelessWidget {
  final LanguageService lang;
  const _BookingHistoryTab({required this.lang});

  String _t(String en, String ur) => lang.t(en, ur);

  // Placeholder bookings — replace with Firestore stream
  static const _mockBookings = <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    if (_mockBookings.isEmpty) {
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
      itemCount: _mockBookings.length,
      itemBuilder: (_, i) {
        final b = _mockBookings[i];
        return _BookingTile(booking: b, lang: lang);
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
            activeColor: AppTheme.tealPrimary,
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
          subtitle: _t('Upload demo workers to DB', 'ڈیٹا بیس میں ڈیمو کارکن'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.tealPrimary),
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding Firestore...')));
            await AuthService().seedDemoData();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firestore Seeded!')));
          },
        ),
        _SettingRow(
          icon: Icons.upload_rounded,
          title: _t('Seed Firestore', 'فائر اسٹور میں ڈیٹا ڈالیں'),
          subtitle: _t('Upload demo workers to DB', 'ڈیٹا بیس میں ڈیمو کارکن'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.tealPrimary),
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding Firestore...')));
            await AuthService().seedDemoData();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firestore Seeded!')));
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

// ── Support Tab ──────────────────────────────────────────────────────────────
class _SupportTab extends StatelessWidget {
  final LanguageService lang;
  const _SupportTab({required this.lang});

  String _t(String en, String ur) => lang.t(en, ur);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(title: _t('Help & Support', 'مدد اور سپورٹ')),
        _SupportTile(
          emoji: '📞',
          title: _t('Call Support', 'سپورٹ کال'),
          subtitle: _t('0311-KAAMYAAB • Available 9am-9pm', '0311-KAAMYAAB • دستیاب صبح 9 سے رات 9 تک'),
          color: AppTheme.tealPrimary,
          onTap: () {},
        ),
        _SupportTile(
          emoji: '💬',
          title: _t('In-App Chat', 'ان-ایپ چیٹ'),
          subtitle: _t('Message us in app for quick help', 'فوری مدد کے لیے ایپ میں پیغام بھیجیں'),
          color: const Color(0xFF25D366),
          onTap: () {},
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: _t('FAQ', 'عام سوالات')),
        _FaqTile(
          q: _t('How do I cancel a booking?', 'میں بکنگ کیسے منسوخ کروں؟'),
          a: _t(
            'Go to Booking History, tap your booking and select Cancel. Free cancellation up to 2 hours before.',
            'بکنگ ہسٹری میں جائیں، اپنی بکنگ پر ٹیپ کریں اور منسوخ کریں۔ 2 گھنٹے پہلے تک مفت منسوخی۔',
          ),
        ),
        _FaqTile(
          q: _t('Is payment safe?', 'کیا ادائیگی محفوظ ہے؟'),
          a: _t(
            'Yes! We use escrow-based payments. Your money is held safely until the job is completed.',
            'جی ہاں! ہم ایسکرو ادائیگی استعمال کرتے ہیں۔ آپ کی رقم کام مکمل ہونے تک محفوظ رہتی ہے۔',
          ),
        ),
        _FaqTile(
          q: _t('What if the worker doesn\'t show?', 'اگر کارکن نہ آئے تو کیا ہوگا؟'),
          a: _t(
            'You will receive a full refund automatically if the worker doesn\'t arrive within 30 minutes of the scheduled time.',
            'اگر کارکن مقررہ وقت کے 30 منٹ بعد بھی نہ آئے تو آپ کو خودبخود مکمل رقم واپس مل جائے گی۔',
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }
}

class _SupportTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SupportTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
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
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _expanded
              ? AppTheme.tealPrimary.withValues(alpha: 0.06)
              : AppTheme.cardDark,
          borderRadius: AppTheme.radiusMd,
          border: Border.all(
            color: _expanded
                ? AppTheme.tealPrimary.withValues(alpha: 0.25)
                : AppTheme.textMuted.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.q,
                      style: TextStyle(
                        color: _expanded ? AppTheme.tealPrimary : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(widget.a,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  )),
            ],
          ],
        ),
      ),
    );
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
