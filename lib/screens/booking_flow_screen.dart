import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import '../models/booking_model.dart';
import '../models/service_request_model.dart';
import '../services/in_app_notification_service.dart';
import '../services/booking_history_service.dart';
import '../services/matching_service.dart';
import 'live_tracking_screen.dart';
import 'dispute_screen.dart';

class BookingFlowScreen extends StatefulWidget {
  final ProviderMatch match;
  final ServiceRequest request;
  final double surgeMultiplier;
  final double negotiatedPrice;
  final String? negotiationNote;

  const BookingFlowScreen({
    super.key,
    required this.match,
    required this.request,
    required this.surgeMultiplier,
    required this.negotiatedPrice,
    this.negotiationNote,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen>
    with TickerProviderStateMixin {
  List<BookingStep> _steps = BookingStep.initialSteps();
  int _currentStep = -1;
  bool _isRunning = false;
  bool _isComplete = false;
  // ignore: unused_field
  final bool _isFailed = false; // reserved for future error handling

  PriceQuote? _quote;
  double _finalPrice = 0;
  late String _receiptNumber; // generated once in initState

  double _rating = 0;
  String _feedback = ''; // collected post-booking
  bool _feedbackSubmitted = false;
  bool _bookingPersisted = false;

  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  @override
  void initState() {
    super.initState();
    _finalPrice = widget.negotiatedPrice;
    _receiptNumber = 'KY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _quote = _buildQuote();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successAnim = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    Future.delayed(const Duration(milliseconds: 600), () {
      // Lock this provider's slot to prevent double-booking
      MatchingService.bookSlot(widget.match.provider.id, widget.match.recommendedSlot);
      _runBookingFlow();
    });
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  PriceQuote _buildQuote() {
    final p = widget.match.provider;
    final base = p.baseRatePkr;
    final distanceCharge = widget.match.distanceKm > 5
        ? (widget.match.distanceKm - 5) * 15
        : 0.0;
    final complexitySurcharge = widget.request.jobComplexity == 'complex'
        ? base * 0.40
        : widget.request.jobComplexity == 'intermediate'
            ? base * 0.20
            : 0.0;
    final urgencyAdj = (widget.request.preferredDate == 'today' ||
            widget.request.urgency == 'emergency')
        ? base * 0.25
        : (widget.request.preferredDate == 'tomorrow' &&
                widget.request.preferredTime == 'morning')
            ? base * 0.10
            : 0.0;
    // README pricing rule caps demand surge contribution at 35%.
    final demandRate = (widget.surgeMultiplier - 1).clamp(0.0, 0.35);
    final demandSurcharge =
        (base + distanceCharge + complexitySurcharge + urgencyAdj) * demandRate;
    final loyaltyDiscount = base * 0.05;
    final budgetAdjustment =
        widget.request.budgetSensitivity >= 0.75 ? base * 0.05 : 0.0;
    final total = base +
        distanceCharge +
        complexitySurcharge +
        urgencyAdj +
        demandSurcharge -
        loyaltyDiscount -
        budgetAdjustment;
    final breakdownParts = [
      'Base Rs.${base.toInt()}',
      'Distance Rs.${distanceCharge.toInt()}',
      'Complexity Rs.${complexitySurcharge.toInt()}',
      'Urgency Rs.${urgencyAdj.toInt()}',
      'Demand Rs.${demandSurcharge.toInt()}',
      '- Loyalty Rs.${loyaltyDiscount.toInt()}',
      '- Budget Rs.${budgetAdjustment.toInt()}',
    ];

    return PriceQuote(
      basePkr: base,
      urgencyAdjPkr: urgencyAdj,
      distanceCostPkr: distanceCharge,
      surgeMultiplier: widget.surgeMultiplier,
      loyaltyDiscountPkr: loyaltyDiscount,
      totalPkr: total,
      breakdown: breakdownParts.join(' | '),
      isNegotiable: p.dnascore < 900,
    );
  }

  Future<void> _runBookingFlow() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;

      setState(() {
        _currentStep = i;
        _steps = _steps.asMap().entries.map((e) {
          if (e.key < i) return e.value.copyWith(status: 'completed');
          if (e.key == i) return e.value.copyWith(status: 'active');
          return e.value;
        }).toList();
      });

      await Future.delayed(Duration(
        milliseconds: i == 4 ? 2000 : i == 5 ? 2500 : 1200,
      ));

      if (!mounted) return;
      setState(() {
        _steps = _steps.asMap().entries.map((e) {
          if (e.key == i) {
            return e.value.copyWith(
              status: 'completed',
              timestamp: _now(),
              agentNote: _stepNote(i),
            );
          }
          return e.value;
        }).toList();
      });

      if (i == 1) {
        if (!mounted) return;
        await InAppNotificationService.showMessage(
          context,
          title: 'Booking Confirmation',
          message: _stepNote(i),
          icon: Icons.notifications_active_rounded,
          type: InAppNotificationType.toast,
        );
      }

      if (i == 4) {
        if (!mounted) return;
        await InAppNotificationService.showMessage(
          context,
          title: 'En-Route Update',
          message: _stepNote(i),
          icon: Icons.directions_car_rounded,
          type: InAppNotificationType.bottomSheet,
        );
      }

      HapticFeedback.lightImpact();
    }

    if (mounted) {
      setState(() {
        _isComplete = true;
        _isRunning = false;
        _currentStep = _steps.length;
      });
      _successCtrl.forward();
      HapticFeedback.heavyImpact();
      await _persistBookingHistory();
    }
  }

  String _now() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _stepNote(int step) {
    final p = widget.match.provider;
    switch (step) {
      case 0: return 'Task sent to ${p.name} and 2 others near ${widget.request.area}';
      case 1: return '${p.name} accepted! Time confirmed for ${widget.match.recommendedSlot}';
      case 2: return 'Contact details exchanged. Receipt #$_receiptNumber. Call ${p.name} at ${p.phone} if needed.';
      case 3: return 'Reminders set: T-24h, T-1h, T-15min';
      case 4: return '${p.name} is en-route — ETA ${widget.match.etaMinutes} minutes';
      case 5: return 'Service completion logged with photo checklist';
      case 6: return 'DNA Score updated — ${p.name} earned +2 points';
      default: return '';
    }
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _feedbackSubmitted = true);
    // ISSUE-010 FIX: persist the feedback text alongside the booking
    try {
      await BookingHistoryService().updateFeedback(
        requestId: widget.request.id,
        rating: _rating,
        feedback: _feedback,
      );
    } catch (_) {
      // Non-blocking if service unavailable
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⭐ Feedback submitted! DNA Score updated.',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
        ),
      );
    }
  }

  Future<void> _persistBookingHistory() async {
    if (_bookingPersisted || _quote == null) return;
    final date = DateTime.now();
    final scheduledDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      await BookingHistoryService().saveCompletedBooking(
        requestId: widget.request.id,
        providerId: widget.match.provider.id,
        providerName: widget.match.provider.name,
        serviceType: widget.request.serviceType,
        userArea: widget.request.area,
        scheduledDate: scheduledDate,
        scheduledTime: widget.match.recommendedSlot,
        quotedPricePkr: _quote!.totalPkr,
        finalPricePkr: _finalPrice,
        status: 'completed',
        receiptNumber: _receiptNumber,
        surgeMultiplier: widget.surgeMultiplier,
        negotiatedNote: widget.negotiationNote,
      );
      _bookingPersisted = true;
    } catch (_) {
      // Non-blocking in demo mode when Firebase is unavailable.
    }
  }

  // _extractReceiptNumber() removed — receipt is now generated once in
  // initState() as _receiptNumber and embedded directly into step 2's note.

  @override
  Widget build(BuildContext context) {
    final p = widget.match.provider;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(p)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: _buildPriceCard(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: AppTheme.radiusLg,
                          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline header
                            const Text('Booking Pipeline',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text('AI orchestrating 7-step agentic flow',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            const SizedBox(height: 16),

                            // Timeline steps
                            ..._steps.asMap().entries.map((e) =>
                                _TimelineStep(
                                  step: e.value,
                                  index: e.key,
                                  isLast: e.key == _steps.length - 1,
                                  currentStep: _currentStep,
                                )),

                            // Success banner
                            if (_isComplete) ...[
                              const SizedBox(height: 16),
                              _buildSuccessBanner(),
                            ],

                            // Feedback section
                            if (_isComplete) ...[
                              const SizedBox(height: 16),
                              _buildFeedback(),
                            ],

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Floating Live Tracking button (appears at En-Route step) ──
          if (_currentStep >= 4)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, a, b) => LiveTrackingScreen(
                      match: widget.match,
                      request: widget.request,
                    ),
                    transitionsBuilder: (_, a, b, child) => SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Track Worker Live',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                  elevation: 8,
                  shadowColor: AppTheme.tealPrimary.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ServiceProvider p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.tealGlassGradient,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: AppTheme.radiusSm,
            ),
            child: const Icon(Icons.arrow_back_ios_rounded,
                color: AppTheme.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
          child: Text(
            p.name.length >= 2 ? p.name.substring(0, 2) : p.name,
            style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${widget.request.serviceType} · ${widget.request.area} · ${widget.match.recommendedSlot}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        if (_isRunning)
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary),
          )
        else if (_isComplete)
          const Icon(Icons.check_circle_rounded, color: AppTheme.greenSuccess, size: 22),
      ]),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💰 Price Breakdown',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text('Rs. ${_finalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppTheme.tealPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        const SizedBox(height: 4),
        Text(_quote!.breakdown,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),

        if (widget.negotiationNote != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.greenSuccess.withValues(alpha: 0.08),
              borderRadius: AppTheme.radiusSm,
              border: Border.all(color: AppTheme.greenSuccess.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.handshake_rounded, color: AppTheme.greenSuccess, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.negotiationNote!,
                  style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 11))),
            ]),
          ),
        ],
      ]),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildSuccessBanner() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, child) => Transform.scale(
        scale: 0.8 + 0.2 * _successAnim.value,
        child: Opacity(opacity: _successAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.radiusLg,
          boxShadow: AppTheme.tealGlowStrong,
        ),
        child: Column(children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Booking Confirmed!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${widget.match.provider.name} will arrive by ${widget.match.recommendedSlot} · Rs. ${_finalPrice.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⭐ Service Quality Loop',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Your verification updates the provider\'s DNA Score',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 14),

        // Quality Checklist
        const Text('Completion Checklist', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildChecklistItem('Task completed as requested?'),
        _buildChecklistItem('Area left clean & tidy?'),
        _buildChecklistItem('Payment settled?'),
        const SizedBox(height: 14),

        // Photo Evidence Placeholder
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('📸 Camera launched (simulated)'), behavior: SnackBarBehavior.floating));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: Colors.white12, style: BorderStyle.solid),
            ),
            child: const Column(children: [
              Icon(Icons.add_a_photo_rounded, color: AppTheme.textMuted, size: 24),
              SizedBox(height: 4),
              Text('Attach Photo Evidence (Optional)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),

        // Star rating
        const Center(
          child: Text('Rate Provider', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: List.generate(5, (i) {
            return GestureDetector(
              onTap: _feedbackSubmitted ? null : () {
                HapticFeedback.selectionClick();
                setState(() => _rating = i + 1);
              },
              child: Icon(
                _rating > i ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _rating > i ? AppTheme.goldAccent : AppTheme.textMuted,
                size: 34,
              ).animate(target: _rating > i ? 1 : 0)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 150.ms)
                  .then().scale(end: const Offset(1, 1), duration: 100.ms),
            );
          }),
        ),

        const SizedBox(height: 12),
        TextField(
          enabled: !_feedbackSubmitted,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          maxLines: 2,
          onChanged: (v) => _feedback = v,
          decoration: const InputDecoration(
            hintText: 'Leave a comment (optional)...',
            labelText: 'Feedback',
          ),
        ),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_feedbackSubmitted || _rating == 0) ? null : _submitFeedback,
            icon: _feedbackSubmitted
                ? const Icon(Icons.check_circle_rounded)
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_feedbackSubmitted ? 'Submitted — DNA Score Updated!' : 'Submit Rating'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _feedbackSubmitted ? AppTheme.greenSuccess : AppTheme.goldAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        // ISSUE-012 FIX: Dispute button visible after booking completion
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DisputeScreen()),
            ),
            icon: const Icon(Icons.gavel_rounded, size: 16, color: AppTheme.redAlert),
            label: const Text('File a Dispute',
                style: TextStyle(color: AppTheme.redAlert, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.redAlert.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildChecklistItem(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppTheme.tealPrimary.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }
}

// ── Timeline Step ──────────────────────────────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final BookingStep step;
  final int index;
  final bool isLast;
  final int currentStep;

  const _TimelineStep({
    required this.step,
    required this.index,
    required this.isLast,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.status == 'completed';
    final isActive = step.status == 'active';

    final color = isCompleted
        ? AppTheme.greenSuccess
        : isActive
            ? AppTheme.tealPrimary
            : AppTheme.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left rail (icon + connector) ──
          Column(
            children: [
              // Circle icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color, width: isActive ? 2 : 1.5),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppTheme.tealPrimary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)]
                      : [],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: AppTheme.greenSuccess, size: 16)
                      : isActive
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary),
                            )
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                ),
              ),
              // Connector line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isCompleted
                              ? AppTheme.greenSuccess.withValues(alpha: 0.6)
                              : isActive
                                  ? AppTheme.tealPrimary.withValues(alpha: 0.4)
                                  : AppTheme.textMuted.withValues(alpha: 0.15),
                          AppTheme.textMuted.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // ── Content ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(step.title,
                          style: TextStyle(
                            color: isCompleted
                                ? AppTheme.textPrimary
                                : isActive
                                    ? AppTheme.tealPrimary
                                    : AppTheme.textMuted,
                            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          )),
                    ),
                    if (step.timestamp != null)
                      Text(step.timestamp!,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                  const SizedBox(height: 2),
                  Text(step.description,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),
                  if (step.agentNote != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.greenSuccess.withValues(alpha: 0.08),
                        borderRadius: AppTheme.radiusSm,
                      ),
                      child: Text(
                        '✓ ${step.agentNote!}',
                        style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 10, height: 1.3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
