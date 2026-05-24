import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/worker_agent_chat.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with TickerProviderStateMixin {
  late String _providerName;
  late String _providerCategory;
  final int _dnascore = 912;
  final double _todayEarnings = 5400;
  final double _weekEarnings = 28700;
  final int _completedToday = 4;
  final int _pendingJobs = 2;

  bool _isOnline = true;
  int _adviceIndex = 0;

  double _displayedTodayEarnings = 0;
  double _displayedWeekEarnings = 0;
  late AnimationController _counterCtrl;
  late Animation<double> _counterAnim;

  final List<Map<String, dynamic>> _upcomingJobs = [
    {'time': '10:00 AM', 'service': 'AC Repair', 'area': 'G-13', 'price': 1800.0, 'status': 'confirmed', 'customer': 'Ali Hassan'},
    {'time': '02:00 PM', 'service': 'AC Repair', 'area': 'G-11', 'price': 1500.0, 'status': 'confirmed', 'customer': 'Saima Bibi'},
    {'time': '04:30 PM', 'service': 'Gas Refill', 'area': 'G-13', 'price': 2200.0, 'status': 'surge', 'customer': 'Waqar Bhai'},
  ];

  final List<Map<String, dynamic>> _hotZones = [
    {'area': 'G-13', 'demand': 14, 'surge': 1.6, 'color': 0xFFEF4444},
    {'area': 'G-11', 'demand': 9, 'surge': 1.3, 'color': 0xFFF59E0B},
    {'area': 'G-14', 'demand': 6, 'surge': 1.0, 'color': 0xFF22C55E},
    {'area': 'F-10', 'demand': 4, 'surge': 1.0, 'color': 0xFF22C55E},
  ];

  final List<FlSpot> _earningsData = [
    FlSpot(0, 3200), FlSpot(1, 4800), FlSpot(2, 2900),
    FlSpot(3, 6100), FlSpot(4, 5400), FlSpot(5, 7200), FlSpot(6, 5400),
  ];

  final List<String> _agentAdvice = [
    '⚡ Accept 2 more AC jobs today — surge window closes at 6 PM',
    '🗺️ Move towards G-13 — 7 requests in the last 30 mins',
    '🏆 Your DNA Score is 912 — top 5% of providers',
    '💰 You can earn 1.6x by accepting urgent bookings now',
  ];

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _providerName = user?.name ?? 'Provider';
    _providerCategory = user?.serviceCategory ?? 'Technician';

    _counterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _counterAnim = CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOutCubic);
    _counterAnim.addListener(() {
      setState(() {
        _displayedTodayEarnings = _todayEarnings * _counterAnim.value;
        _displayedWeekEarnings = _weekEarnings * _counterAnim.value;
      });
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _counterCtrl.forward();
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _adviceIndex = (_adviceIndex + 1) % _agentAdvice.length);
      return true;
    });
  }

  @override
  void dispose() {
    _counterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.purpleAgent,
        elevation: 8,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
        label: const Text('AI Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const WorkerAgentChatBottomSheet(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      // Avatar with gradient ring
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.cardDark,
                          child: Text(
                            _providerName.length >= 2 ? _providerName.substring(0, 2) : _providerName,
                            style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _providerName,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              'Provider · $_providerCategory',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Online toggle
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final newStatus = !_isOnline;
                          setState(() => _isOnline = newStatus);
                          await AuthService().setWorkerAvailability(newStatus);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppTheme.greenSuccess.withValues(alpha: 0.12)
                                : AppTheme.textMuted.withValues(alpha: 0.08),
                            borderRadius: AppTheme.radiusMd,
                            border: Border.all(
                              color: _isOnline
                                  ? AppTheme.greenSuccess.withValues(alpha: 0.5)
                                  : AppTheme.textMuted.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isOnline ? AppTheme.greenSuccess : AppTheme.textMuted,
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // DNA Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.radiusMd,
                          boxShadow: AppTheme.tealGlow,
                        ),
                        child: Column(
                          children: [
                            Text('$_dnascore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            const Text('DNA', style: TextStyle(color: Colors.white60, fontSize: 8, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
              ),

              // ── Agent Advice Banner ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_adviceIndex),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.agentGradient,
                        borderRadius: AppTheme.radiusMd,
                        boxShadow: [BoxShadow(color: AppTheme.purpleAgent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _agentAdvice[_adviceIndex],
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppTheme.radiusSm,
                            ),
                            child: Text(
                              '${_adviceIndex + 1}/${_agentAdvice.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ),

              // ── Stats Row ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(
                        label: "Today's Earnings",
                        value: 'Rs. ${_displayedTodayEarnings.toInt()}',
                        icon: Icons.monetization_on_rounded,
                        color: AppTheme.goldAccent,
                        subtitle: '+12% vs yesterday',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        label: 'Completed',
                        value: '$_completedToday',
                        icon: Icons.check_circle_rounded,
                        color: AppTheme.greenSuccess,
                        subtitle: 'of ${_completedToday + _pendingJobs} jobs',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        label: 'Pending',
                        value: '$_pendingJobs',
                        icon: Icons.pending_rounded,
                        color: AppTheme.blueInfo,
                        subtitle: 'next at 10 AM',
                      )),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),
              ),

              // ── Earnings Chart ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: AppTheme.radiusLg,
                      border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.show_chart_rounded, color: AppTheme.tealPrimary, size: 18),
                            const SizedBox(width: 8),
                            const Text('Weekly Earnings', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.tealPrimary.withValues(alpha: 0.12),
                                borderRadius: AppTheme.radiusSm,
                              ),
                              child: Text(
                                'Rs. ${_displayedWeekEarnings.toInt()}',
                                style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Tap bars for daily breakdown', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 120,
                          child: LineChart(LineChartData(
                            gridData: FlGridData(
                              show: true,
                              getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1),
                              getDrawingVerticalLine: (_) => FlLine(color: Colors.transparent),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                    final isToday = v.toInt() == 6;
                                    return Text(days[v.toInt()],
                                        style: TextStyle(
                                          color: isToday ? AppTheme.tealPrimary : AppTheme.textMuted,
                                          fontSize: 10,
                                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                        ));
                                  },
                                  reservedSize: 22,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _earningsData,
                                isCurved: true,
                                color: AppTheme.tealPrimary,
                                barWidth: 2.5,
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [AppTheme.tealPrimary.withValues(alpha: 0.25), Colors.transparent],
                                  ),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, _, _, i) => FlDotCirclePainter(
                                    radius: i == 6 ? 5 : 0,
                                    color: AppTheme.tealPrimary,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          )),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),

              // ── Hot Zones ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(icon: Icons.local_fire_department_rounded, color: AppTheme.redAlert, title: 'Demand Hot Zones', subtitle: 'Highest AC Repair demand right now'),
                      const SizedBox(height: 10),
                      ..._hotZones.asMap().entries.map((e) => _HotZoneTile(zone: e.value, index: e.key, maxDemand: 14)),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ),

              // ── Today's Schedule ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(icon: Icons.calendar_today_rounded, color: AppTheme.blueInfo, title: "Today's Schedule", subtitle: '${_upcomingJobs.length} jobs lined up'),
                      const SizedBox(height: 10),
                      ..._upcomingJobs.map((j) => _JobTile(job: j)),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ),

              // ── Optimal Slots ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.07),
                      borderRadius: AppTheme.radiusLg,
                      border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(color: AppTheme.goldAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.lightbulb_rounded, color: AppTheme.goldAccent, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Text('Agent Recommended Slots', style: TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Based on demand forecast, these slots offer maximum earning potential today:',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _SlotChip('2:00 PM', '1.6x surge'),
                            _SlotChip('3:00 PM', '1.8x surge'),
                            _SlotChip('5:00 PM', '1.4x surge'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final String? subtitle;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ],
        ],
      ),
    );
  }
}

// ── Hot Zone Tile ──────────────────────────────────────────────────────────
class _HotZoneTile extends StatelessWidget {
  final Map<String, dynamic> zone;
  final int index, maxDemand;
  const _HotZoneTile({required this.zone, required this.index, required this.maxDemand});

  @override
  Widget build(BuildContext context) {
    final color = Color(zone['color'] as int);
    final surge = zone['surge'] as double;
    final demand = zone['demand'] as int;
    final demandRatio = demand / maxDemand;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
                child: Center(child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone['area'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$demand active requests', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: AppTheme.radiusSm),
                    child: Text('${surge.toStringAsFixed(1)}x', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    surge >= 1.5 ? 'High Surge' : surge >= 1.2 ? 'Moderate' : 'Normal',
                    style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppTheme.radiusSm,
            child: LinearProgressIndicator(
              value: demandRatio,
              backgroundColor: color.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 80)).slideX(begin: 0.05);
  }
}

// ── Job Tile ────────────────────────────────────────────────────────────────
class _JobTile extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final isSurge = job['status'] == 'surge';
    final accentColor = isSurge ? AppTheme.goldAccent : AppTheme.tealPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSurge ? AppTheme.goldAccent.withValues(alpha: 0.07) : AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: accentColor.withValues(alpha: isSurge ? 0.3 : 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withValues(alpha: 0.1)),
            child: Icon(Icons.access_time_rounded, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${job['time']} · ${job['service']}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 10, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text('${job['area']} · ${job['customer']}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs. ${(job['price'] as double).toInt()}',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w800, fontSize: 13)),
              if (isSurge)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusSm,
                  ),
                  child: const Text('⚡ Surge', style: TextStyle(color: AppTheme.goldAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Slot Chip ────────────────────────────────────────────────────────────────
class _SlotChip extends StatelessWidget {
  final String time, label;
  const _SlotChip(this.time, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.goldAccent.withValues(alpha: 0.12),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time, style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w800, fontSize: 12)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        ],
      ),
    );
  }
}