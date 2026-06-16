import re, sys

content = open('lib/screens/booking_flow_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n').replace('\r', '\n')
changes = 0

# ─────────────────────────────────────────────────────────────────────────────
# 1. Replace _buildHeader with a premium worker identity card
# ─────────────────────────────────────────────────────────────────────────────
old = '''  // ── Header — unchanged from your version ─────────────────────────────────
  Widget _buildHeader(ServiceProvider p) {'''
idx_header_start = n.find(old)
if idx_header_start == -1:
    # Try without the comment
    old = '  Widget _buildHeader(ServiceProvider p) {'
    idx_header_start = n.find(old)

idx_header_end = n.find('\n  Widget _buildPriceCard()', idx_header_start)
if idx_header_start != -1 and idx_header_end != -1:
    old_header = n[idx_header_start:idx_header_end]
    new_header = '''  // ── Header — rich worker identity card ──────────────────────────────────
  Widget _buildHeader(ServiceProvider p) {
    // Determine live status label + colour based on booking state
    final String statusLabel;
    final Color statusColor;
    if (_isComplete) {
      statusLabel = 'Completed';
      statusColor = AppTheme.greenSuccess;
    } else if (_currentStep >= 4) {
      statusLabel = 'En-Route';
      statusColor = AppTheme.tealPrimary;
    } else if (_workerResponse == 'accepted') {
      statusLabel = 'Accepted';
      statusColor = AppTheme.greenSuccess;
    } else if (_isRunning) {
      statusLabel = 'Connecting';
      statusColor = AppTheme.goldAccent;
    } else {
      statusLabel = 'Pending';
      statusColor = AppTheme.textMuted;
    }

    // Category icon
    final categoryIcons = {
      'Plumber': '🔧', 'Electrician': '⚡', 'Carpenter': '🪚',
      'Painter': '🎨', 'Cleaner': '🧹', 'Driver': '🚗',
      'Cook': '👨‍🍳', 'Mason': '🧱', 'AC Technician': '❄️',
    };
    final catIcon = categoryIcons.entries
        .where((e) => widget.request.serviceType.toLowerCase().contains(e.key.toLowerCase()))
        .map((e) => e.value)
        .firstOrNull ?? '👷';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tealPrimary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: back + avatar + name + status ──────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: AppTheme.radiusSm),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppTheme.textSecondary, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar with gradient ring + category badge overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.surfaceDark,
                      child: Text(
                        p.name.length >= 2 ? p.name.substring(0, 2) : p.name,
                        style: const TextStyle(
                            color: AppTheme.tealPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        shape: BoxShape.circle,
                      ),
                      child: Text(catIcon, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    // Status pill + DNA badge row
                    Row(children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12 + 0.06 * _pulseCtrl.value),
                            borderRadius: AppTheme.radiusSm,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.purpleAgent.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radiusSm,
                        ),
                        child: Text(
                          '⭐ ${p.rating.toStringAsFixed(1)}  🧬 DNA ${p.dnascore}',
                          style: const TextStyle(
                              color: AppTheme.purpleLight,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Info chips row ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _InfoChip(Icons.build_rounded, widget.request.serviceType, AppTheme.tealPrimary),
              const SizedBox(width: 6),
              _InfoChip(Icons.location_on_rounded, widget.request.area, AppTheme.goldAccent),
              const SizedBox(width: 6),
              _InfoChip(Icons.schedule_rounded, widget.match.recommendedSlot, AppTheme.greenSuccess),
              const SizedBox(width: 6),
              _InfoChip(Icons.directions_walk_rounded, '${widget.match.distanceKm.toStringAsFixed(1)} km · ${widget.match.etaMinutes} min', AppTheme.textMuted),
            ]),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05);
  }'''
    n = n[:idx_header_start] + new_header + n[idx_header_end:]
    changes += 1
    print('SUCCESS 1: _buildHeader replaced')
else:
    print('FAIL 1: header not found', idx_header_start, idx_header_end)

open('lib/screens/booking_flow_screen.dart', 'w', encoding='utf-8').write(n)
print(f'Done. {changes} changes made.')
