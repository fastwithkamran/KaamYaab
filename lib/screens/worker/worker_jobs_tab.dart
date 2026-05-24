import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/booking_history_service.dart';

class WorkerJobsTab extends StatefulWidget {
  const WorkerJobsTab({super.key});

  @override
  State<WorkerJobsTab> createState() => _WorkerJobsTabState();
}

class _WorkerJobsTabState extends State<WorkerJobsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSegmentBar(),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _BookingList(filter: _activeFilter, emptyLabel: 'No active jobs right now'),
              _BookingList(filter: _historyFilter, emptyLabel: 'No completed jobs yet'),
            ],
          ),
        ),
      ],
    );
  }

  bool _activeFilter(Map<String, dynamic> b) {
    final s = (b['status'] as String? ?? '').toLowerCase();
    return s == 'en_route' || s == 'in_progress' || s == 'confirmed' || s == 'scheduled';
  }

  bool _historyFilter(Map<String, dynamic> b) {
    final s = (b['status'] as String? ?? '').toLowerCase();
    return s == 'completed' || s == 'cancelled' || s == 'disputed';
  }

  Widget _buildSegmentBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.radiusMd,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: '  Active  '),
          Tab(text: '  History  '),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable list for active / history
// ─────────────────────────────────────────────────────────────────────────────
class _BookingList extends StatelessWidget {
  final bool Function(Map<String, dynamic>) filter;
  final String emptyLabel;

  const _BookingList({required this.filter, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BookingHistoryService().watchWorkerBookings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.tealPrimary),
          );
        }

        final all = snap.data ?? [];
        final items = all.where(filter).toList();

        if (items.isEmpty) return _emptyState(emptyLabel);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              _BookingCard(booking: items[i]).animate().fadeIn(
                    delay: Duration(milliseconds: 60 * i),
                  ),
        );
      },
    );
  }

  Widget _emptyState(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_off_outlined,
              color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual booking card
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  Color get _statusColor {
    switch ((booking['status'] as String? ?? '').toLowerCase()) {
      case 'completed':
        return AppTheme.greenSuccess;
      case 'cancelled':
        return AppTheme.redAlert;
      case 'disputed':
        return AppTheme.goldAccent;
      case 'en_route':
      case 'in_progress':
        return AppTheme.tealPrimary;
      default:
        return AppTheme.purpleAgent;
    }
  }

  IconData get _statusIcon {
    switch ((booking['status'] as String? ?? '').toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'disputed':
        return Icons.report_problem_outlined;
      case 'en_route':
        return Icons.directions_car_outlined;
      case 'in_progress':
        return Icons.build_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  String get _statusLabel {
    final s = (booking['status'] as String? ?? '').toLowerCase();
    if (s.isEmpty) return 'Unknown';
    if (s == 'en_route') return 'En Route';
    if (s == 'in_progress') return 'In Progress';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final customerName = booking['customer_phone'] as String? ?? 'Customer';
    final serviceType = booking['service_type'] as String? ?? 'Service';
    final date = booking['scheduled_date'] as String? ?? '';
    final time = booking['scheduled_time'] as String? ?? '';
    final price =
        (booking['final_price_pkr'] as num?)?.toDouble() ?? 0;
    final receipt = booking['receipt_number'] as String? ?? '';
    final rating = (booking['user_rating'] as num?)?.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: service + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    serviceType,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: AppTheme.radiusSm,
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon, color: _statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info grid
            Row(children: [
              _infoChip(Icons.person_outline, customerName),
              const SizedBox(width: 10),
              _infoChip(Icons.calendar_today_outlined, date),
              const SizedBox(width: 10),
              _infoChip(Icons.access_time_outlined, time),
            ]),
            const SizedBox(height: 12),
            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  receipt.isNotEmpty ? 'Receipt: $receipt' : '',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
                Text(
                  'Rs.${price.toInt()}',
                  style: const TextStyle(
                      color: AppTheme.greenSuccess,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ],
            ),
            // Rating row (if available)
            if (rating != null && rating > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star, color: AppTheme.goldAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Customer rated: ${rating.toStringAsFixed(1)}',
                  style: const TextStyle(
                      color: AppTheme.goldAccent, fontSize: 12),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Expanded(
      child: Row(children: [
        Icon(icon, color: AppTheme.textMuted, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
