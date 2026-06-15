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

import '../services/auth_service.dart';
import '../services/customer_notification_service.dart';
import '../services/location_service.dart';
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

  double _rating = 0;
  String _feedback = '';
  bool _feedbackSubmitted = false;
  bool _bookingPersisted = false;
  String? _requestNotifId;
  String? _workerResponse; // pending, accepted, rejected

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
      final customer = AuthService().currentUser;
      
      // Send negotiation request to worker
      final notifId = await WorkerNotificationService().notifyNegotiationRequest(
        workerUid: widget.match.provider.id,
        customerUid: customer?.uid ?? 'anon',
        customerName: customer?.name.isNotEmpty == true ? customer!.name : (customer?.phone ?? 'Customer'),
        serviceType: widget.request.serviceType,
        originalPrice: _finalPrice,
        offerPrice: offer,
        requestId: widget.request.id,
        receiptNumber: _receiptNumber,
      );

      if (notifId != null) {
        // ── Mock worker: auto-accept after 2s (no real user behind this provider) ──
        if (widget.match.provider.isMock) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() {
              _isNegotiating = false;
              _negotiationDone = true;
              _liveNegotiationResult = 'Worker accepted your offer! Rs.$offer confirmed.';
              _finalPrice = offer;
            });
          }
        } else {
          final startTime = DateTime.now();
          bool resolved = false;
          
          // Wait for worker or 20s simulation timeout
          while (!resolved && DateTime.now().difference(startTime).inSeconds < 20) {
            final snap = await FirebaseFirestore.instance
                .collection('worker_notifications')
                .doc(widget.match.provider.id)
                .collection('items')
                .doc(notifId)
                .get();
            
            if (snap.exists) {
              final data = snap.data();
              final status = (data?['meta'] as Map?)?['status'] as String?;
              
              if (status == 'accepted') {
                if (mounted) {
                  setState(() {
                    _isNegotiating = false;
                    _negotiationDone = true;
                    _liveNegotiationResult = 'Worker accepted your offer! Rs.$offer confirmed.';
                    _finalPrice = offer;
                  });
                }
                resolved = true;
              } else if (status == 'rejected') {
                if (mounted) {
                  setState(() {
                    _isNegotiating = false;
                    _negotiationDone = true;
                    _liveNegotiationResult = 'Worker declined the offer. Keeping original price.';
                  });
                }
                resolved = true;
              } else if (status == 'countered') {
                final counter = (data?['meta'] as Map?)?['counter_offer_pkr'] as num?;
                if (mounted) {
                  setState(() {
                    _isNegotiating = false;
                    _negotiationDone = true;
                    _liveNegotiationResult = 'Worker countered with Rs.${counter?.toInt()}.';
                    _finalPrice = counter?.toDouble() ?? _finalPrice;
                  });
                }
                resolved = true;
              }
            }
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
          }

          // Simulation fallback if no response
          if (!resolved && mounted) {
             setState(() {
               _isNegotiating = false;
               _liveNegotiationResult = 'No response from worker. Using AI recommended rate.';
               // Optionally fall back to AI or original price
             });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isNegotiating = false;
          _liveNegotiationResult =
              'Negotiation service unavailable. Using quoted price.';
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

      if (i == 0) {
        // ── Step 0: Notifying Workers ──────────────────────────────────────
        final date = DateTime.now();
        final scheduledDate =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        _requestNotifId = await WorkerNotificationService().notifyBookingRequest(
          workerUid: widget.match.provider.id,
          customerUid: customer?.uid ?? 'anon',
          customerName: customer?.name.isNotEmpty == true ? customer!.name : (customer?.phone ?? 'Customer'),
          serviceType: widget.request.serviceType,
          scheduledDate: scheduledDate,
          scheduledTime: widget.match.recommendedSlot,
          offeredPricePkr: _finalPrice,
          requestId: widget.request.id,
          jobDescription: widget.request.rawInput,
          urgency: widget.request.urgency,
        );
        
        await Future.delayed(const Duration(milliseconds: 1500));
      } else if (i == 1) {
        // ── Step 1: Worker Acceptance ──────────────────────────────────────
        if (_requestNotifId != null) {
          // ── Mock worker: simulate instant acceptance (no real user) ──────
          if (widget.match.provider.isMock) {
            await Future.delayed(const Duration(seconds: 3));
            if (!mounted) return;
            _workerResponse = 'accepted';
          } else {
            final startTime = DateTime.now();
            bool resolved = false;
            
            // Poll/Wait for worker response or 30s timeout
            while (!resolved && DateTime.now().difference(startTime).inSeconds < 30) {
              final snap = await FirebaseFirestore.instance
                  .collection('worker_notifications')
                  .doc(widget.match.provider.id)
                  .collection('items')
                  .doc(_requestNotifId)
                  .get();
              
              if (snap.exists) {
                final status = (snap.data()?['meta'] as Map?)?['status'] as String?;
                if (status == 'accepted' || status == 'rejected') {
                  _workerResponse = status;
                  resolved = true;
                  break;
                }
              }
              await Future.delayed(const Duration(seconds: 1));
              if (!mounted) return;
            }
          }

          if (_workerResponse != 'accepted') {
            setState(() {
              _isRunning = false;
              _steps = _steps.map((s) => s.stepNumber == 2 
                ? s.copyWith(
                    status: 'failed', 
                    agentNote: _workerResponse == 'rejected' 
                        ? 'Worker declined the proposal.' 
                        : 'No response from worker. Proposal expired.') 
                : s).toList();
            });
            return;
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 2000));
        }
      } else if (i == 4 && Firebase.apps.isNotEmpty) {
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
        return 'Task sent to ${p.name} near ${widget.request.area}';
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
                            _AgentStatusBanner(
                              steps: _steps,
                              currentStep: _currentStep,
                              workerName: p.name,
                              isComplete: _isComplete,
                              workerResponse: _workerResponse,
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

  // ── Header — rich worker identity card ──────────────────────────────────
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
  }
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

  // ── Negotiation panel — styled to match the rest of the screen ────────────
  // ── Negotiation panel — chat-style with quick-offer chips ────────────────
  Widget _buildNegotiationPanel() {
    final quickOffers = [
      (_finalPrice * 0.80).round(),
      (_finalPrice * 0.85).round(),
      (_finalPrice * 0.90).round(),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldAccent.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Panel header ────────────────────────────────────────────────
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
              Text(
                _workerMinRate != null
                    ? 'Floor Rs.${_workerMinRate!.toInt()} · AI agent negotiates on behalf of worker'
                    : 'Make a counter-offer. AI agent will respond.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ]),
          ),
          if (_negotiationDone)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: AppTheme.greenSuccess.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.greenSuccess, size: 14),
            ),
        ]),

        const SizedBox(height: 14),

        // ── Chat-style conversation bubbles ──────────────────────────────
        if (_liveNegotiationResult != null) ...[
          // User offer bubble (right-aligned)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('You offered',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                Text(
                  'Rs. ${_offerCtrl.text.isNotEmpty ? _offerCtrl.text : "—"}',
                  style: const TextStyle(
                      color: AppTheme.tealPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          // Agent response bubble (left-aligned)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAgent.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _negotiationDone
                      ? AppTheme.greenSuccess.withValues(alpha: 0.08)
                      : AppTheme.purpleAgent.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: _negotiationDone
                        ? AppTheme.greenSuccess.withValues(alpha: 0.25)
                        : AppTheme.purpleAgent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Negotiation Agent',
                      style: TextStyle(
                          color: AppTheme.purpleLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(_liveNegotiationResult!,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12, height: 1.4)),
                  if (_negotiationDone) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.greenSuccess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Final: Rs.${_finalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.greenSuccess,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Quick-offer chips ────────────────────────────────────────────
        if (!_negotiationDone) ...[
          const Text('QUICK OFFERS',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(children: quickOffers.map((amt) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isNegotiating ? null : () {
                _offerCtrl.text = amt.toString();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.goldAccent.withValues(alpha: 0.3)),
                ),
                child: Text('Rs.$amt',
                    style: const TextStyle(
                        color: AppTheme.goldAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 12),
        ],

        // ── Input row ────────────────────────────────────────────────────
        if (!_negotiationDone)
          Row(children: [
            Expanded(
              child: TextField(
                controller: _offerCtrl,
                enabled: !_negotiationDone && !_isNegotiating,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Your offer in Rs.',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  prefixText: 'Rs. ',
                  prefixStyle: const TextStyle(
                      color: AppTheme.goldAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed:
                    (_negotiationDone || _isNegotiating) ? null : _runNegotiation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  disabledBackgroundColor:
                      AppTheme.goldAccent.withValues(alpha: 0.4),
                ),
                child: _isNegotiating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Send',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
      ]),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05);
  }
  // ── Success banner — celebration card ────────────────────────────────────
  Widget _buildSuccessBanner() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, child) => Transform.scale(
        scale: 0.85 + 0.15 * _successAnim.value,
        child: Opacity(
            opacity: _successAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9B87), Color(0xFF06B3A0), Color(0xFF048C7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.radiusLg,
          boxShadow: [
            BoxShadow(
              color: AppTheme.tealPrimary.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(children: [
          // ── Top celebration section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(children: [
              const Text('🎉', style: TextStyle(fontSize: 48))
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5), duration: 600.ms,
                      curve: Curves.elasticOut),
              const SizedBox(height: 10),
              const Text('Booking Confirmed!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text(
                '${widget.match.provider.name} will arrive by ${widget.match.recommendedSlot}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),

              // ── Info chips ──────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuccessChip(
                      Icons.payments_rounded, 'Rs.${_finalPrice.toStringAsFixed(0)}'),
                  _SuccessChip(Icons.schedule_rounded, widget.match.recommendedSlot),
                  _SuccessChip(Icons.receipt_long_rounded, _receiptNumber),
                ],
              ),
            ]),
          ),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),

          // ── Action buttons ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call Worker',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📞 Calling ${widget.match.provider.name}... (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Add to Calendar',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📅 Added to calendar (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuccessActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔗 Share link copied (simulated)'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.cardDark,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
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

// ── _InfoChip ─────────────────────────────────────────────────────────────────

// ── _SuccessChip ──────────────────────────────────────────────────────────────
class _SuccessChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SuccessChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── _SuccessActionButton ──────────────────────────────────────────────────────
class _SuccessActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SuccessActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}


class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── _AgentStatusBanner ───────────────────────────────────────────────────────
// Dynamic banner at top of pipeline card showing what AI is doing right now.
class _AgentStatusBanner extends StatelessWidget {
  final List<BookingStep> steps;
  final int currentStep;
  final String workerName;
  final bool isComplete;
  final String? workerResponse;

  const _AgentStatusBanner({
    required this.steps,
    required this.currentStep,
    required this.workerName,
    required this.isComplete,
    required this.workerResponse,
  });

  static const _stepIcons = [
    Icons.send_rounded,
    Icons.handshake_rounded,
    Icons.phone_in_talk_rounded,
    Icons.notifications_active_rounded,
    Icons.directions_car_rounded,
    Icons.build_rounded,
    Icons.star_rounded,
  ];

  (String, Color, IconData) get _status {
    if (isComplete) {
      return ('✅  Booking fully complete!', AppTheme.greenSuccess, Icons.celebration_rounded);
    }
    if (currentStep < 0) {
      return ('⏳  Preparing booking...', AppTheme.textMuted, Icons.hourglass_top_rounded);
    }
    if (workerResponse == 'rejected') {
      return ('❌  Worker declined the request', AppTheme.redAlert, Icons.cancel_rounded);
    }
    final labels = [
      '📡  Notifying $workerName...',
      '⏳  Waiting for $workerName to respond...',
      '🤝  Deal locked — details exchanged',
      '🔔  Reminders scheduled for you',
      '🚗  $workerName is on the way!',
      '🔧  Job in progress',
      '⭐  Wrapping up — please rate!',
    ];
    final colours = [
      AppTheme.tealPrimary,
      AppTheme.goldAccent,
      AppTheme.greenSuccess,
      AppTheme.purpleLight,
      AppTheme.tealPrimary,
      AppTheme.goldAccent,
      AppTheme.goldAccent,
    ];
    final i = currentStep.clamp(0, labels.length - 1);
    return (labels[i], colours[i], _stepIcons[i]);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('AI Agentic Pipeline  ·  7-step orchestration',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ]),
          ),
          if (!isComplete && currentStep >= 0 && workerResponse != 'rejected')
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color.withValues(alpha: 0.7),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── _TimelineStep — premium redesign ─────────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final BookingStep step;
  final int index, currentStep;
  final bool isLast;

  const _TimelineStep({
    required this.step,
    required this.index,
    required this.isLast,
    required this.currentStep,
  });

  // Step icons are represented via _stepEmojis for the dot center.

  static const _stepEmojis = ['📡', '✋', '📞', '🔔', '🚗', '🔧', '⭐'];

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.status == 'completed';
    final isActive    = step.status == 'active';
    final isFailed    = step.status == 'failed';
    final isPending   = !isCompleted && !isActive && !isFailed;

    final Color dotColor;
    final Color lineColor;
    if (isCompleted) {
      dotColor = AppTheme.greenSuccess;
      lineColor = AppTheme.greenSuccess;
    } else if (isActive) {
      dotColor = AppTheme.tealPrimary;
      lineColor = AppTheme.tealPrimary.withValues(alpha: 0.3);
    } else if (isFailed) {
      dotColor = AppTheme.redAlert;
      lineColor = AppTheme.redAlert.withValues(alpha: 0.2);
    } else {
      dotColor = AppTheme.textMuted.withValues(alpha: 0.4);
      lineColor = AppTheme.textMuted.withValues(alpha: 0.1);
    }

    final stepEmoji = index < _stepEmojis.length ? _stepEmojis[index] : '•';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left column: dot + connector line ───────────────────────────
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Step dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor.withValues(alpha: isPending ? 0.04 : 0.13),
                    border: Border.all(
                      color: dotColor,
                      width: isActive ? 2 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppTheme.tealPrimary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check_rounded, color: dotColor, size: 16)
                        : isFailed
                            ? Icon(Icons.close_rounded, color: dotColor, size: 16)
                            : isActive
                                ? SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: dotColor))
                                : Text(stepEmoji,
                                    style: const TextStyle(fontSize: 14)),
                  ),
                ),
                // Connector line — dashed when pending, solid when done
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: isCompleted
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.greenSuccess.withValues(alpha: 0.7),
                                    AppTheme.greenSuccess.withValues(alpha: 0.15),
                                  ],
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _DashedLinePainter(lineColor),
                              size: const Size(2, double.infinity),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Right column: title + description + note ─────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(step.title,
                          style: TextStyle(
                            color: isPending
                                ? AppTheme.textMuted
                                : isFailed
                                    ? AppTheme.redAlert
                                    : AppTheme.textPrimary,
                            fontWeight: (isActive || isCompleted)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 13,
                          )),
                    ),
                    if (step.timestamp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(step.timestamp!,
                            style: const TextStyle(
                                color: AppTheme.greenSuccess,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(step.description,
                      style: TextStyle(
                          color: isPending
                              ? AppTheme.textMuted.withValues(alpha: 0.5)
                              : AppTheme.textMuted,
                          fontSize: 11,
                          height: 1.4)),

                  // Agent note bubble
                  if (step.agentNote != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFailed
                            ? AppTheme.redAlert.withValues(alpha: 0.07)
                            : AppTheme.greenSuccess.withValues(alpha: 0.07),
                        borderRadius: AppTheme.radiusSm,
                        border: Border.all(
                            color: isFailed
                                ? AppTheme.redAlert.withValues(alpha: 0.25)
                                : AppTheme.greenSuccess.withValues(alpha: 0.2)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(
                          isFailed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          color: isFailed ? AppTheme.redAlert : AppTheme.greenSuccess,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(step.agentNote!,
                                style: TextStyle(
                                    color: isFailed ? AppTheme.redAlert : AppTheme.greenSuccess,
                                    fontSize: 10,
                                    height: 1.4))),
                      ]),
                    ),
                  ],

                  // "Agent working..." shimmer text for active step
                  if (isActive && step.agentNote == null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.tealPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Agent working on this step...',
                          style: TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                    ]),
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

// ── Dashed connector line painter ─────────────────────────────────────────────
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
