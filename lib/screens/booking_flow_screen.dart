import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import '../models/booking_model.dart';
import '../models/service_request_model.dart';
import '../services/gemini_service.dart';
import '../services/in_app_notification_service.dart';
import '../services/location_service.dart';
import '../services/booking_history_service.dart';

class BookingFlowScreen extends StatefulWidget {
  final ProviderMatch match;
  final ServiceRequest request;
  final double surgeMultiplier;

  const BookingFlowScreen({
    super.key,
    required this.match,
    required this.request,
    required this.surgeMultiplier,
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
  bool _isFailed = false; // reserved for future error handling

  PriceQuote? _quote;
  bool _negotiating = false;
  bool _negotiated = false;
  String? _negotiationNote;
  double _finalPrice = 0;

  double _rating = 0;
  // ignore: unused_field
  String _feedback = ''; // collected post-booking
  bool _feedbackSubmitted = false;
  bool _bookingPersisted = false;

  // GPS — auto-detect customer location for better worker dispatch
  // ignore: unused_field
  LocationData? _customerLocation;
  // ignore: unused_field
  bool _workerVerified = false;
  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  @override
  void initState() {
    super.initState();
    _finalPrice = widget.match.quotePkr;
    _quote = _buildQuote();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successAnim = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    Future.delayed(const Duration(milliseconds: 600), _runBookingFlow);
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
        await InAppNotificationService.showMessage(
          context,
          title: 'Booking Confirmation',
          message: _stepNote(i),
          icon: Icons.notifications_active_rounded,
          type: InAppNotificationType.toast,
        );
      }

      if (i == 4) {
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
      case 0: return '${p.name}\'s slot at ${widget.match.recommendedSlot} locked for ${widget.request.area}';
      case 1: return 'In-app booking notification sent to ${p.phone}';
      case 2: return 'Receipt #KG-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)} generated';
      case 3: return 'Reminders set: T-24h, T-1h, T-15min';
      case 4: return '${p.name} is en-route â€” ETA ${widget.match.etaMinutes} minutes';
      case 5: return 'Service completion logged with photo checklist';
      case 6: return 'DNA Score updated â€” ${p.name} earned +2 points';
      default: return '';
    }
  }

  Future<void> _negotiatePrice() async {
    setState(() => _negotiating = true);
    final result = await GeminiService.negotiatePrice(
      providerName: widget.match.provider.name,
      originalQuote: _finalPrice,
      userOffer: _finalPrice * 0.88,
      serviceType: widget.request.serviceType,
      providerDnaScore: widget.match.provider.dnascore,
      surgeMultiplier: widget.surgeMultiplier,
      isRepeatCustomer: false,
    );

    final counterOffer = (result['counter_offer_pkr'] as num).toDouble();
    setState(() {
      _negotiating = false;
      _negotiated = true;
      _finalPrice = counterOffer;
      _negotiationNote = result['note'] as String?;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _feedbackSubmitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [
          Text('â­ '),
          Text('Feedback submitted! DNA Score updated.',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: AppTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      ),
    );
  }

  Future<void> _persistBookingHistory() async {
    if (_bookingPersisted || _quote == null) return;
    final date = DateTime.now();
    final scheduledDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final receipt = _extractReceiptNumber();

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
        receiptNumber: receipt,
        surgeMultiplier: widget.surgeMultiplier,
        negotiatedNote: _negotiationNote,
      );
      _bookingPersisted = true;
    } catch (_) {
      // Non-blocking in demo mode when Firebase is unavailable.
    }
  }

  String _extractReceiptNumber() {
    String? note;
    for (final step in _steps) {
      if (step.stepNumber == 3 && (step.agentNote?.contains('Receipt #') ?? false)) {
        note = step.agentNote;
        break;
      }
    }
    if (note == null) {
      return 'KG-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
    final idx = note.indexOf('Receipt #');
    if (idx == -1) {
      return 'KG-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
    return note.substring(idx + 'Receipt #'.length).trim();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.match.provider;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildHeader(p),

              // â”€â”€ Scrollable body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price quote card
                      if (_quote != null) _buildPriceCard(),
                      const SizedBox(height: 20),

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

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
            p.name.substring(0, 2),
            style: const TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${widget.request.serviceType} Â· ${widget.request.area} Â· ${widget.match.recommendedSlot}',
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
          const Text('ðŸ’° Price Breakdown',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text('Rs. ${_finalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppTheme.tealPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        const SizedBox(height: 4),
        Text(_quote!.breakdown,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),

        if (_negotiated && _negotiationNote != null) ...[
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
              Expanded(child: Text(_negotiationNote!,
                  style: const TextStyle(color: AppTheme.greenSuccess, fontSize: 11))),
            ]),
          ),
        ],

        if (_quote!.isNegotiable && !_negotiated) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _negotiating ? null : _negotiatePrice,
              icon: _negotiating
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary))
                  : const Icon(Icons.handshake_rounded, size: 16, color: AppTheme.tealPrimary),
              label: Text(_negotiating ? 'Negotiating...' : 'Negotiate Better Price',
                  style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.tealPrimary),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
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
          const Text('ðŸŽ‰', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Booking Confirmed!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${widget.match.provider.name} will arrive by ${widget.match.recommendedSlot} Â· Rs. ${_finalPrice.toStringAsFixed(0)}',
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
        const Text('â­ Rate Your Experience',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Your rating updates the provider\'s DNA Score',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 14),

        // Star rating
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            return GestureDetector(
              onTap: _feedbackSubmitted ? null : () {
                HapticFeedback.selectionClick();
                setState(() => _rating = i + 1);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  _rating > i ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _rating > i ? AppTheme.goldAccent : AppTheme.textMuted,
                  size: 36,
                ).animate(target: _rating > i ? 1 : 0)
                    .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 150.ms)
                    .then().scale(end: const Offset(1, 1), duration: 100.ms),
              ),
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
            label: Text(_feedbackSubmitted ? 'Submitted â€” DNA Score Updated!' : 'Submit Rating'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _feedbackSubmitted ? AppTheme.greenSuccess : AppTheme.goldAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
  }
}

// â”€â”€ Timeline Step â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          // â”€â”€ Left rail (icon + connector) â”€â”€
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

          // â”€â”€ Content â”€â”€
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
                        'âœ“ ${step.agentNote!}',
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
