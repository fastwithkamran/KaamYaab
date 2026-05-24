import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import '../models/booking_model.dart';
import '../models/service_request_model.dart';
import '../services/in_app_notification_service.dart';
import '../services/booking_history_service.dart';
import '../services/worker_notification_service.dart';
import '../services/matching_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/customer_notification_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
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

  PriceQuote? _quote;
  double _finalPrice = 0;
  late String _receiptNumber;
  String? _bookingId;
  StreamSubscription<DocumentSnapshot>? _bookingSub;

  double _rating = 0;
  String _feedback = '';
  bool _feedbackSubmitted = false;
  bool _bookingPersisted = false;

  // ── Negotiation agent state ───────────────────────────────────────────────
  double? _workerMinRate;
  double? _workerMaxRate;
  String _workerNegotiationStyle = 'moderate';
  bool _isNegotiating = false;
  bool _negotiationDone = false;
  String? _liveNegotiationResult;
  final TextEditingController _offerCtrl = TextEditingController();

  late AnimationController _successCtrl;
  late Animation<double> _successAnim;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _finalPrice = widget.negotiatedPrice;
    _receiptNumber =
        'KY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // ── Load worker negotiation floor from matching service cache ─────────
    _loadWorkerNegotiationData();

    _quote = _buildQuote();

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _successAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 600), () {
      MatchingService.bookSlot(
          widget.match.provider.id, widget.match.recommendedSlot);
      _runBookingFlow();
    });
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _successCtrl.dispose();
    _pulseCtrl.dispose();
    _offerCtrl.dispose();
    super.dispose();
  }

  /// Pulls negotiation data for this provider from MatchingService cache.
  /// Falls back to 80 % of base rate if not cached (mock/JSON providers).
  void _loadWorkerNegotiationData() {
    final cached =
        MatchingService.getNegotiationData(widget.match.provider.id);
    if (cached != null) {
      _workerMinRate = (cached['minRatePkr'] as num?)?.toDouble();
      _workerMaxRate = (cached['maxRatePkr'] as num?)?.toDouble();
      _workerNegotiationStyle =
          cached['negotiationStyle'] as String? ?? 'moderate';
    } else {
      // Fallback for mock/JSON providers that have no live record
      _workerMinRate = widget.match.provider.baseRatePkr * 0.80;
      _workerMaxRate = widget.match.provider.baseRatePkr * 1.5;
      _workerNegotiationStyle = 'moderate';
    }
  }

  PriceQuote _buildQuote() {
    final p = widget.match.provider;
    final base = p.baseRatePkr;
    final distanceCharge =
        widget.match.distanceKm > 5 ? (widget.match.distanceKm - 5) * 15 : 0.0;
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

    // Build breakdown parts — only show non-zero lines
    final parts = [
      'Base Rs.${base.toInt()}',
      if (distanceCharge > 0) 'Distance Rs.${distanceCharge.toInt()}',
      if (complexitySurcharge > 0) 'Complexity Rs.${complexitySurcharge.toInt()}',
      if (urgencyAdj > 0) 'Urgency Rs.${urgencyAdj.toInt()}',
      if (demandSurcharge > 0) 'Demand Rs.${demandSurcharge.toInt()}',
      '- Loyalty Rs.${loyaltyDiscount.toInt()}',
      if (budgetAdjustment > 0) '- Budget Rs.${budgetAdjustment.toInt()}',
      if (_workerMinRate != null) 'Floor Rs.${_workerMinRate!.toInt()} (min)',
    ];

    return PriceQuote(
      basePkr: base,
      urgencyAdjPkr: urgencyAdj,
      distanceCostPkr: distanceCharge,
      surgeMultiplier: widget.surgeMultiplier,
      loyaltyDiscountPkr: loyaltyDiscount,
      totalPkr: total,
      breakdown: parts.join(' | '),
      // Not negotiable if firm style or very high DNA
      isNegotiable:
          p.dnascore < 900 && _workerNegotiationStyle != 'firm',
    );
  }

  // ── Live AI negotiation ───────────────────────────────────────────────────
  Future<void> _runNegotiation() async {
    final offer = double.tryParse(_offerCtrl.text.trim());
    if (offer == null || offer <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid offer amount.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isNegotiating = true);

    try {
      // Single lookup — AuthService is a singleton so calling it twice
      // returns the same object; cache it once to make that explicit.
      final customer = AuthService().currentUser;
      final result = await AiService.negotiatePrice(
        originalQuote: _finalPrice,
        userOffer: offer,
        providerName: widget.match.provider.name,
        serviceType: widget.request.serviceType,
        providerDnaScore: widget.match.provider.dnascore,
        surgeMultiplier: widget.surgeMultiplier,
        isRepeatCustomer: customer != null && customer.totalJobs > 3,
        workerMinRatePkr: _workerMinRate,
        workerNegotiationStyle: _workerNegotiationStyle,
      );

      final counterOffer =
          (result['counter_offer_pkr'] as num?)?.toDouble() ?? _finalPrice;
      final reasoning = result['reasoning'] as String? ?? '';

      // Notify the worker of the negotiation request
      if (customer != null) {
        WorkerNotificationService().notifyNegotiationRequest(
          workerUid: widget.match.provider.id,
          customerName: customer.name.isNotEmpty ? customer.name : customer.phone,
          serviceType: widget.request.serviceType,
          originalPrice: _finalPrice,
          offerPrice: offer,
          receiptNumber: _receiptNumber,
        );
      }

      // Notify the customer of the worker's counter-offer
      if (customer != null) {
        CustomerNotificationService().notifyWorkerCounterOffer(
          customerUid: customer.uid,
          workerName: widget.match.provider.name,
          serviceType: widget.request.serviceType,
          counterOffer: counterOffer,
        );
      }

      if (mounted) {
        setState(() {
          _isNegotiating = false;
          _negotiationDone = true;
          _liveNegotiationResult = reasoning;
          _finalPrice = counterOffer; // always apply the counter
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isNegotiating = false;
          _liveNegotiationResult =
              'Negotiation agent unavailable. Using quoted price.';
        });
      }
    }
  }

  // ── Booking pipeline ──────────────────────────────────────────────────────
  Future<void> _runBookingFlow() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    // Fetch the signed-in customer once — the user never changes mid-flow
    // and AuthService is a singleton, so three repeated calls inside the loop
    // were wasteful.
    final customer = AuthService().currentUser;

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

      if (i == 4 && Firebase.apps.isNotEmpty) {
        try {
          final locResult = await LocationService().getCurrentLocation();
          if (locResult.isSuccess && locResult.data != null) {
            final userLat = locResult.data!.latitude;
            final userLng = locResult.data!.longitude;
            final distKm = widget.match.distanceKm.clamp(0.5, 15.0);
            final angle = (widget.match.provider.id.hashCode % 360) * 3.14159 / 180;
            final latOffset = (distKm / 111.0) * math.cos(angle);
            final lngOffset = (distKm / 111.0) * math.sin(angle) / math.cos(userLat * 3.14159 / 180);
            final workerStartLat = userLat + latOffset;
            final workerStartLng = userLng + lngOffset;

            final totalSteps = 8;
            for (int step = 0; step <= totalSteps; step++) {
              if (!mounted) break;
              final progress = step / totalSteps;
              final currentLat = workerStartLat + (userLat - workerStartLat) * progress;
              final currentLng = workerStartLng + (userLng - workerStartLng) * progress;
              final etaMin = ((1.0 - progress) * widget.match.etaMinutes).round();
              final statusStr = step == totalSteps
                  ? 'Arrived'
                  : (step >= totalSteps - 2 ? 'Arriving Soon' : 'En-Route');

              await FirebaseFirestore.instance
                  .collection('worker_locations')
                  .doc(widget.match.provider.id)
                  .set({
                'latitude': currentLat,
                'longitude': currentLng,
                'status': statusStr,
                'progress': progress,
                'eta_minutes': etaMin,
                'updated_at': FieldValue.serverTimestamp(),
              });

              // Also publish a dynamic notification trigger if arriving soon
              if (step == totalSteps - 2 && mounted) {
                await InAppNotificationService.showMessage(context,
                    title: 'Arriving Soon',
                    message: '${widget.match.provider.name} is just 1 minute away!',
                    icon: Icons.directions_car_rounded,
                    type: InAppNotificationType.toast);
              }

              await Future.delayed(const Duration(milliseconds: 1200));
            }
          } else {
            await Future.delayed(const Duration(milliseconds: 2000));
          }
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 2000));
        }
      } else {
        await Future.delayed(
            Duration(milliseconds: i == 4 ? 2000 : i == 5 ? 2500 : 1200));
      }
      if (!mounted) return;

      setState(() {
        _steps = _steps.asMap().entries.map((e) {
          if (e.key == i) {
            return e.value.copyWith(
                status: 'completed',
                timestamp: _now(),
                agentNote: _stepNote(i));
          }
          return e.value;
        }).toList();
      });

      if (i == 1 && mounted) {
        if (customer != null) {
          CustomerNotificationService().notifyWorkerArrived(
            customerUid: customer.uid,
            workerName: widget.match.provider.name,
            serviceType: widget.request.serviceType,
          );
        }
        await InAppNotificationService.showMessage(context,
            title: 'Booking Confirmation',
            message: _stepNote(i),
            icon: Icons.notifications_active_rounded,
            type: InAppNotificationType.toast);
      }
      if (i == 4 && mounted) {
        if (customer != null) {
          CustomerNotificationService().notifyWorkerEnRoute(
            customerUid: customer.uid,
            workerName: widget.match.provider.name,
            serviceType: widget.request.serviceType,
            etaMinutes: widget.match.etaMinutes,
          );
        }
        await InAppNotificationService.showMessage(context,
            title: 'En-Route Update',
            message: _stepNote(i),
            icon: Icons.directions_car_rounded,
            type: InAppNotificationType.bottomSheet);
      }
      if (i == 5 && mounted) {
        if (customer != null) {
          CustomerNotificationService().notifyWorkerCompleted(
            customerUid: customer.uid,
            workerName: widget.match.provider.name,
            serviceType: widget.request.serviceType,
            finalPrice: _finalPrice,
          );
        }
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
      case 0:
        return 'Task sent to ${p.name} and 2 others near ${widget.request.area}';
      case 1:
        return '${p.name} accepted! Time confirmed for ${widget.match.recommendedSlot}';
      case 2:
        return 'Contact details exchanged. Receipt #$_receiptNumber. Call ${p.name} at ${p.phone} if needed.';
      case 3:
        return 'Reminders set: T-24h, T-1h, T-15min';
      case 4:
        return '${p.name} is en-route — ETA ${widget.match.etaMinutes} minutes';
      case 5:
        return 'Service completion logged with photo checklist';
      case 6:
        return 'DNA Score updated — ${p.name} earned +2 points';
      default:
        return '';
    }
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _feedbackSubmitted = true);
    try {
      await BookingHistoryService().updateFeedback(
          requestId: widget.request.id,
          rating: _rating,
          feedback: _feedback);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⭐ Feedback submitted! DNA Score updated.',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        backgroundColor: AppTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      ));
    }
  }

  Future<void> _persistBookingHistory() async {
    if (_bookingPersisted || _quote == null) return;
    final date = DateTime.now();
    final scheduledDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      if (_bookingId != null) {
        await BookingHistoryService().updateBookingStatus(
          _bookingId!,
          'completed',
          receiptNumber: _receiptNumber,
          finalPrice: _finalPrice,
        );
      } else {
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
          // Save live negotiation result if no upstream note was provided
          negotiatedNote: widget.negotiationNote ?? _liveNegotiationResult,
        );
      }

      // Notify the worker of the confirmed booking
      final customer = AuthService().currentUser;
      if (customer != null) {
        await WorkerNotificationService().notifyBookingConfirmed(
          workerUid: widget.match.provider.id,
          customerName: customer.name.isNotEmpty ? customer.name : customer.phone,
          serviceType: widget.request.serviceType,
          scheduledDate: scheduledDate,
          scheduledTime: widget.match.recommendedSlot,
          finalPricePkr: _finalPrice,
          receiptNumber: _receiptNumber,
        );
      }

      _bookingPersisted = true;
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.match.provider;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(p)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildPriceCard(),
                    ),
                  ),
                  // ── Negotiation panel (before booking starts, if negotiable) ──
                  if (!_isRunning && !_isComplete && (_quote?.isNegotiable ?? false))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _buildNegotiationPanel(),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: AppTheme.radiusLg,
                          border: Border.all(
                              color: AppTheme.textMuted.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tealPrimary
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppTheme.tealPrimary,
                                      size: 16),
                                ),
                                const SizedBox(width: 10),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Booking Pipeline',
                                        style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                    Text('AI orchestrating 7-step agentic flow',
                                        style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ..._steps.asMap().entries.map((e) => _TimelineStep(
                                  step: e.value,
                                  index: e.key,
                                  isLast: e.key == _steps.length - 1,
                                  currentStep: _currentStep,
                                )),
                            if (_isComplete) ...[
                              const SizedBox(height: 20),
                              _buildSuccessBanner(),
                              const SizedBox(height: 16),
                              _buildFeedback(),
                            ],
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating live tracking button ─────────────────────────────────
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
                          match: widget.match, request: widget.request),
                      transitionsBuilder: (_, a, b, child) => SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 1), end: Offset.zero)
                            .animate(CurvedAnimation(
                                parent: a, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                      transitionDuration: const Duration(milliseconds: 350),
                    )),
                icon: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, child) => Transform.scale(
                      scale: 1.0 + 0.1 * _pulseCtrl.value, child: child),
                  child: const Icon(Icons.my_location_rounded, size: 18),
                ),
                label: const Text('Track Worker Live',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.radiusMd),
                  elevation: 8,
                  shadowColor:
                      AppTheme.tealPrimary.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),
            ),
        ],
      ),
    );
  }

  // ── Header — unchanged from your version ─────────────────────────────────
  Widget _buildHeader(ServiceProvider p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.tealGlassGradient,
        borderRadius: AppTheme.radiusLg,
        border:
            Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
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
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.cardDark,
              child: Text(
                p.name.length >= 2 ? p.name.substring(0, 2) : p.name,
                style: const TextStyle(
                    color: AppTheme.tealPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
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
                Text(
                  '${widget.request.serviceType} · ${widget.request.area} · ${widget.match.recommendedSlot}',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (_isRunning)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) =>
                  Opacity(opacity: 0.5 + 0.5 * _pulseCtrl.value, child: child),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.tealPrimary),
              ),
            )
          else if (_isComplete)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppTheme.greenSuccess.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.greenSuccess, size: 16),
            ),
        ],
      ),
    );
  }

  // ── Price card — your UI + negotiation style badge + floor row ────────────
  Widget _buildPriceCard() {
    final styleColor = _workerNegotiationStyle == 'firm'
        ? AppTheme.redAlert
        : _workerNegotiationStyle == 'flexible'
            ? AppTheme.greenSuccess
            : AppTheme.goldAccent;
    final styleLabel = _workerNegotiationStyle == 'firm'
        ? '🔒 Firm'
        : _workerNegotiationStyle == 'flexible'
            ? '🤝 Flexible'
            : '↕ Moderate';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border:
            Border.all(color: AppTheme.textMuted.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppTheme.goldAccent, size: 18),
              const SizedBox(width: 8),
              const Text('Price Breakdown',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              // ── Negotiation style badge ──────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: styleColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSm,
                  border: Border.all(
                      color: styleColor.withValues(alpha: 0.35)),
                ),
                child: Text(styleLabel,
                    style: TextStyle(
                        color: styleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.radiusMd,
                  boxShadow: AppTheme.tealGlow,
                ),
                child: Text('Rs. ${_finalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: AppTheme.radiusSm,
            ),
            child: Text(_quote!.breakdown,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11, height: 1.5)),
          ),

          // ── Worker floor info row ────────────────────────────────────────
          if (_workerMinRate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.purpleAgent.withValues(alpha: 0.07),
                borderRadius: AppTheme.radiusSm,
                border: Border.all(
                    color: AppTheme.purpleAgent.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.purpleLight, size: 13),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'AI floor: Rs.${_workerMinRate!.toInt()} minimum · '
                    'Rs.${_workerMaxRate?.toInt() ?? "—"} max for complex jobs.',
                    style: const TextStyle(
                        color: AppTheme.purpleLight,
                        fontSize: 10,
                        height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          // ── Pre-negotiated note (from upstream) ──────────────────────────
          if (widget.negotiationNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.greenSuccess.withValues(alpha: 0.07),
                borderRadius: AppTheme.radiusSm,
                border: Border.all(
                    color: AppTheme.greenSuccess.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.handshake_rounded,
                    color: AppTheme.greenSuccess, size: 14),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.negotiationNote!,
                        style: const TextStyle(
                            color: AppTheme.greenSuccess, fontSize: 11))),
              ]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  // ── Negotiation panel — redesigned to point to Chat ──────────────────────────
  Widget _buildNegotiationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border:
            Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.goldAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handshake_outlined,
                color: AppTheme.goldAccent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Negotiate Price',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Text(
                'Chat with the worker directly to discuss pricing or requirements.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  peerId: widget.match.provider.id,
                  peerName: widget.match.provider.name,
                  bookingId: _bookingId,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Open Chat for Negotiation',
                style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05);
  }

  // ── Success banner — unchanged from your version ──────────────────────────
  Widget _buildSuccessBanner() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, child) => Transform.scale(
        scale: 0.85 + 0.15 * _successAnim.value,
        child:
            Opacity(opacity: _successAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.radiusLg,
          boxShadow: AppTheme.tealGlowStrong,
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            const Text('Booking Confirmed!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              '${widget.match.provider.name} arrives by ${widget.match.recommendedSlot} · Rs. ${_finalPrice.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusMd,
              ),
              child: Text(
                'Receipt $_receiptNumber',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feedback — unchanged from your version ────────────────────────────────
  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(
            color: AppTheme.goldAccent.withValues(alpha: 0.2)),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppTheme.goldAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded,
                color: AppTheme.goldAccent, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Service Quality Loop',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Text('Your rating updates the provider\'s DNA Score',
                style:
                    TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 16),
        const Text('COMPLETION CHECKLIST',
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3)),
        const SizedBox(height: 10),
        _buildChecklistItem(
            Icons.task_alt_rounded, 'Task completed as requested?'),
        _buildChecklistItem(
            Icons.cleaning_services_rounded, 'Area left clean & tidy?'),
        _buildChecklistItem(Icons.payments_rounded, 'Payment settled?'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('📸 Camera launched (simulated)'),
                behavior: SnackBarBehavior.floating),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(children: [
              Icon(Icons.add_a_photo_rounded,
                  color: AppTheme.textMuted, size: 24),
              SizedBox(height: 6),
              Text('Attach Photo Evidence (Optional)',
                  style:
                      TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: Colors.white10),
        const SizedBox(height: 14),
        const Center(
            child: Text('RATE YOUR EXPERIENCE',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3))),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = _rating > i;
            return GestureDetector(
              onTap: _feedbackSubmitted
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = (i + 1).toDouble());
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: filled
                      ? AppTheme.goldAccent
                      : AppTheme.textMuted,
                  size: 36,
                )
                    .animate(target: filled ? 1 : 0)
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.2, 1.2),
                        duration: 150.ms)
                    .then()
                    .scale(end: const Offset(1, 1), duration: 100.ms),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          enabled: !_feedbackSubmitted,
          style:
              const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
            onPressed: (_feedbackSubmitted || _rating == 0)
                ? null
                : _submitFeedback,
            icon: Icon(
                _feedbackSubmitted
                    ? Icons.check_circle_rounded
                    : Icons.send_rounded,
                size: 16),
            label: Text(
                _feedbackSubmitted
                    ? 'Submitted — DNA Score Updated!'
                    : 'Submit Rating',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _feedbackSubmitted
                  ? AppTheme.greenSuccess
                  : AppTheme.goldAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DisputeScreen())),
            icon: const Icon(Icons.gavel_rounded,
                size: 16, color: AppTheme.redAlert),
            label: const Text('File a Dispute',
                style: TextStyle(
                    color: AppTheme.redAlert,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: AppTheme.redAlert.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildChecklistItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon,
            color: AppTheme.tealPrimary.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

// ── Timeline Step — unchanged from your version ───────────────────────────────
class _TimelineStep extends StatelessWidget {
  final BookingStep step;
  final int index, currentStep;
  final bool isLast;
  const _TimelineStep(
      {required this.step,
      required this.index,
      required this.isLast,
      required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.status == 'completed';
    final isActive = step.status == 'active';
    final isPending = !isCompleted && !isActive;
    final color = isCompleted
        ? AppTheme.greenSuccess
        : isActive
            ? AppTheme.tealPrimary
            : AppTheme.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: isPending ? 0.06 : 0.14),
                  border:
                      Border.all(color: color, width: isActive ? 2 : 1.5),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: AppTheme.tealPrimary
                                  .withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: 1)
                        ]
                      : [],
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check_rounded, color: color, size: 15)
                      : isActive
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: color))
                          : Text('${index + 1}',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                ),
              ),
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
                              ? AppTheme.greenSuccess
                                  .withValues(alpha: 0.5)
                              : color.withValues(alpha: 0.15),
                          AppTheme.textMuted.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
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
                            color: isPending
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontWeight: isActive || isCompleted
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 13,
                          )),
                    ),
                    if (step.timestamp != null)
                      Text(step.timestamp!,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                  const SizedBox(height: 2),
                  Text(step.description,
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          height: 1.4)),
                  if (step.agentNote != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.greenSuccess.withValues(alpha: 0.07),
                        borderRadius: AppTheme.radiusSm,
                        border: Border.all(
                            color: AppTheme.greenSuccess
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_rounded,
                            color: AppTheme.greenSuccess, size: 11),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(step.agentNote!,
                                style: const TextStyle(
                                    color: AppTheme.greenSuccess,
                                    fontSize: 10,
                                    height: 1.3))),
                      ]),
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