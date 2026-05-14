import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/language_service.dart';
import '../services/gemini_service.dart';
import '../services/matching_service.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../widgets/provider_card.dart';
import '../widgets/live_agent_panel.dart';
import '../models/agent_model.dart';
import 'booking_flow_screen.dart';

/// A conversation step the AI agent presents to the user.
class _AgentStep {
  final String agentText;       // What the AI says aloud + shows
  final String fieldLabel;      // Input label (shown above the field)
  final String hint;            // Placeholder text
  final IconData icon;
  final String? Function(String?) validator;

  const _AgentStep({
    required this.agentText,
    required this.fieldLabel,
    required this.hint,
    required this.icon,
    required this.validator,
  });
}

/// Voice-guided booking verification agent screen.
///
/// The AI agent speaks each question aloud (via flutter_tts) and confirms
/// all booking details — service, location, budget, and time — before
/// the user proceeds to find workers.
class VoiceBookingAgent extends StatefulWidget {
  final String? initialService;

  const VoiceBookingAgent({super.key, this.initialService});

  @override
  State<VoiceBookingAgent> createState() => _VoiceBookingAgentState();
}

class _VoiceBookingAgentState extends State<VoiceBookingAgent>
    with TickerProviderStateMixin {
  late FlutterTts _tts;
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;

  final List<TextEditingController> _ctrls = [];
  final _lang = LanguageService();

  int _currentStep = 0;
  bool _speaking = false;
  bool _completed = false;
  bool _detectingLocation = false;
  bool _isMatching = false;
  List<ProviderMatch> _matches = [];
  List<AgentStep> _agentSteps = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;
  final List<String> _answers = [];

  String _t(String en, String ur) => _lang.t(en, ur);

  // ── Conversation steps ───────────────────────────────────────────────────
  late final List<_AgentStep> _steps;

  @override
  void initState() {
    super.initState();

    final isUrdu = _lang.isUrdu;
    _steps = [
      _AgentStep(
        agentText: isUrdu
            ? 'السلام علیکم! آج آپ کو کون سی خدمت چاہیے؟ مثلاً پلمبر، الیکٹریشن، کارپینٹر یا کلینر۔'
            : 'Hello! What service do you need today? For example, plumber, electrician, carpenter, or cleaner.',
        fieldLabel: isUrdu ? 'مطلوبہ خدمت' : 'Service Needed',
        hint: isUrdu ? 'مثلاً: پلمبر، الیکٹریشن...' : 'e.g. Plumber, Electrician...',
        icon: Icons.build_outlined,
        validator: (v) => v == null || v.trim().isEmpty
            ? (isUrdu ? 'براہ کرم خدمت بتائیں' : 'Please tell us what service you need')
            : null,
      ),
      _AgentStep(
        agentText: isUrdu
            ? 'ٹھیک ہے! آپ کا علاقہ یا پتہ کیا ہے؟ محلہ اور شہر ضرور بتائیں۔'
            : 'Got it! Now, what is your exact location or area? Please include your neighbourhood and city.',
        fieldLabel: isUrdu ? 'آپ کا مقام' : 'Your Location / Area',
        hint: isUrdu ? 'مثلاً: DHA فیز 5، لاہور' : 'e.g. DHA Phase 5, Lahore',
        icon: Icons.location_on_outlined,
        validator: (v) => v == null || v.trim().isEmpty
            ? (isUrdu ? 'براہ کرم مقام بتائیں' : 'Please enter your location')
            : null,
      ),
      _AgentStep(
        agentText: isUrdu
            ? 'بہت اچھا! آپ کو یہ خدمت کب چاہیے؟ مثلاً آج دوپہر 3 بجے یا کل صبح۔'
            : 'Perfect. When do you need this service? You can say "Today at 3pm" or "Tomorrow morning".',
        fieldLabel: isUrdu ? 'وقت اور تاریخ' : 'Preferred Date & Time',
        hint: isUrdu ? 'مثلاً: آج 3 بجے، کل صبح' : 'e.g. Today 3pm, Tomorrow morning',
        icon: Icons.schedule_outlined,
        validator: (v) => v == null || v.trim().isEmpty
            ? (isUrdu ? 'براہ کرم وقت بتائیں' : 'Please mention when you need the service')
            : null,
      ),
      _AgentStep(
        agentText: isUrdu
            ? 'بجٹ کیا ہے؟ روپے میں بتائیں، یا کہیں "لچکدار"۔'
            : 'What is your budget? Enter an amount in PKR, or say "flexible".',
        fieldLabel: isUrdu ? 'بجٹ (روپے)' : 'Budget (PKR)',
        hint: isUrdu ? 'مثلاً: 500، 1000-2000، لچکدار' : 'e.g. 500, 1000-2000, flexible',
        icon: Icons.payments_outlined,
        validator: (v) => v == null || v.trim().isEmpty
            ? (isUrdu ? 'براہ کرم بجٹ بتائیں' : 'Please mention your budget')
            : null,
      ),
      _AgentStep(
        agentText: isUrdu
            ? 'آخری سوال — کوئی خاص ہدایت؟ مثلاً اپنے اوزار لائیں، یا مسئلے کی تفصیل۔'
            : 'Last question — any specific instructions for the worker?',
        fieldLabel: isUrdu ? 'اضافی ہدایات (اختیاری)' : 'Additional Instructions (optional)',
        hint: isUrdu ? 'مثلاً: اوزار لائیں، پچھلے دروازے سے...' : 'e.g. Bring tools, access from back gate...',
        icon: Icons.notes_outlined,
        validator: (_) => null,
      ),
    ];

    // Init one controller per step
    for (final _ in _steps) {
      _ctrls.add(TextEditingController());
    }

    // Pre-fill service if passed
    if (widget.initialService != null) {
      _ctrls[0].text = widget.initialService!;
    }

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    // Use Urdu voice if language is Urdu
    await _tts.setLanguage(_lang.isUrdu ? 'ur-PK' : 'en-US');
    await _tts.setSpeechRate(_lang.isUrdu ? 0.40 : 0.45);
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });

    await Future.delayed(const Duration(milliseconds: 600));
    _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_currentStep >= _steps.length) return;
    final text = _steps[_currentStep].agentText;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _speaking = false);
  }

  Future<void> _nextStep() async {
    // Validate current field
    final ctrl = _ctrls[_currentStep];
    final validator = _steps[_currentStep].validator;
    final error = validator(ctrl.text);
    if (error != null) {
      _showFieldError(error);
      return;
    }

    HapticFeedback.selectionClick();
    await _stopSpeaking();
    _answers.add(ctrl.text.trim());

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      await Future.delayed(const Duration(milliseconds: 400));
      _speakCurrent();
      // Auto-detect GPS on location step (step 1)
      if (_currentStep == 1 && _ctrls[1].text.isEmpty) {
        _autoDetectLocation();
      }
    } else {
      _answers.add(ctrl.text.trim());
      setState(() => _completed = true);
      final doneText = _lang.isUrdu
          ? 'شکریہ! میں ابھی آپ کے لیے بہترین کارکن تلاش کر رہا ہوں۔'
          : 'Great! Finding the best worker for you now!';
      await _tts.speak(doneText);
      // Kick off AI matching pipeline
      await _runAiMatching();
    }
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    _stopSpeaking();
    setState(() => _currentStep--);
    _speakCurrent();
  }

  void _showFieldError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.redError.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
    ));
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _detectingLocation = true);
    final result = await LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() => _detectingLocation = false);
    if (result.isSuccess && _ctrls[1].text.isEmpty) {
      _ctrls[1].text = result.data!.shortAddress;
      setState(() {});
    }
  }

  Future<void> _runAiMatching() async {
    if (_answers.isEmpty) return;
    setState(() {
      _isMatching = true;
      _agentSteps = [];
    });
    try {
      final service = _answers.isNotEmpty ? _answers[0] : 'General';
      final location = _answers.length > 1 ? _answers[1] : 'Islamabad';
      
      _agentSteps.add(AgentStep(
        agentName: AgentIdentity.intent,
        task: 'Parsing multilingual request',
        reasoning: 'Extracting service type, location, urgency, and budget sensitivity...',
        toolCall: 'gemini.extract_intent(raw_input)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      setState(() {});
      
      // Simulate real-time reasoning delay
      await Future.delayed(const Duration(seconds: 1));

      // Extract intent via Gemini
      final intentResult = await GeminiService.extractIntent(
          '$service, $location, ${_answers.length > 2 ? _answers[2] : "flexible"}');
      final serviceType = intentResult['service_type'] as String? ?? service;
      final area = intentResult['area'] as String? ?? 'G-13';
      final urgency = intentResult['urgency'] as String? ?? 'medium';
      
      setState(() {
        _agentSteps[_agentSteps.length - 1] = _agentSteps.last.copyWith(status: AgentStepStatus.done, decision: 'Intent extracted: $serviceType');
      });
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _agentSteps.add(AgentStep(
          agentName: AgentIdentity.surge,
          task: 'Checking demand in $area',
          reasoning: 'Scanning active requests and provider availability...',
          toolCall: 'surge_agent.check(area=$area, service=$serviceType)',
          status: AgentStepStatus.thinking,
          timestamp: DateTime.now(),
        ));
      });
      
      await Future.delayed(const Duration(milliseconds: 1500));

      _currentRequest = ServiceRequest(
        id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
        rawInput: service,
        serviceType: serviceType,
        location: location,
        area: area,
        urgency: urgency,
        preferredTime: _answers.length > 2 ? _answers[2] : 'flexible',
        preferredDate: 'flexible',
        budgetSensitivity: 0.5,
        confidence: (intentResult['confidence'] as num?)?.toDouble() ?? 0.8,
        language: _lang.isUrdu ? 'ur' : 'en',
        createdAt: DateTime.now(),
        status: 'pending',
      );

      final results = await MatchingService.matchProviders(
        request: _currentRequest!,
        userLat: 33.7215,
        userLng: 73.0433,
      );
      
      setState(() {
        _agentSteps[_agentSteps.length - 1] = _agentSteps.last.copyWith(status: AgentStepStatus.done, decision: 'Surge multiplier: 1.0');
      });
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _agentSteps.add(AgentStep(
          agentName: AgentIdentity.matching,
          task: 'Ranking workers via 8-factor DNA',
          reasoning: 'Evaluating distance, rating, reliability, price, capacity...',
          toolCall: 'matcher.rank_providers()',
          status: AgentStepStatus.thinking,
          timestamp: DateTime.now(),
        ));
      });
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      setState(() {
        _agentSteps[_agentSteps.length - 1] = _agentSteps.last.copyWith(status: AgentStepStatus.done, decision: '${results.length} workers matched');
        _matches = results;
        _isMatching = false;
      });
    } catch (e) {
      setState(() => _isMatching = false);
    }
  }

  void _openBooking(ProviderMatch match) {
    HapticFeedback.mediumImpact();
    _stopSpeaking();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => BookingFlowScreen(
        match: match,
        request: _currentRequest!,
        surgeMultiplier: 1.0,
      ),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  void dispose() {
    _tts.stop();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

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
              Expanded(
                child: _completed
                    ? _buildSummary()
                    : _buildConversation(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () { _stopSpeaking(); Navigator.pop(context); },
          icon: const Icon(Icons.close, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _t('KaamYaab Assistant', '🤖 کامیاب معاون'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _completed
                  ? _t('Booking details confirmed!', 'بکنگ تفصیلات تصدیق!')
                  : _t('Step ${_currentStep + 1} of ${_steps.length}',
                      'مرحلہ ${_currentStep + 1} / ${_steps.length}'),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ]),
        ),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: AppTheme.radiusSm,
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _steps.length,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppTheme.tealPrimary),
              minHeight: 4,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Main conversation UI ───────────────────────────────────────────────────
  Widget _buildConversation() {
    final step = _steps[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar + voice wave
          Center(
            child: Column(children: [
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 80 + (_speaking ? _pulseCtrl.value * 10 : 0),
                  height: 80 + (_speaking ? _pulseCtrl.value * 10 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _speaking
                        ? RadialGradient(colors: [
                            AppTheme.tealPrimary.withValues(alpha: 0.4),
                            AppTheme.tealPrimary.withValues(alpha: 0.1),
                          ])
                        : const RadialGradient(colors: [
                            AppTheme.cardDark,
                            AppTheme.surfaceDark,
                          ]),
                    border: Border.all(
                      color: _speaking ? AppTheme.tealPrimary : Colors.white12,
                      width: _speaking ? 2 : 1,
                    ),
                    boxShadow: _speaking ? AppTheme.tealGlow : [],
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 36),
                ),
              ),

              const SizedBox(height: 8),

              // Voice wave bars
              if (_speaking)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (i) {
                    return AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (_, __) {
                        final offset = (i / 7) * 2 * math.pi;
                        final t = (_waveCtrl.value * 2 * math.pi + offset) % (2 * math.pi);
                        final height = (6.0 + (1.0 + math.sin(t)) * 14.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  }),
                )
              else
                GestureDetector(
                  onTap: _speakCurrent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.volume_up_outlined, color: AppTheme.tealPrimary, size: 16),
                      SizedBox(width: 6),
                      Text('Tap to replay', style: TextStyle(color: AppTheme.tealPrimary, fontSize: 12)),
                    ]),
                  ),
                ),

              const SizedBox(height: 24),
            ]),
          ),

          // Agent speech bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.tealPrimary.withValues(alpha: 0.12),
                AppTheme.blueInfo.withValues(alpha: 0.06),
              ]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.25)),
            ),
            child: Text(
              step.agentText,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.5,
                  fontWeight: FontWeight.w400),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          // User input field
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.fieldLabel,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ctrls[_currentStep],
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onFieldSubmitted: (_) => _nextStep(),
              decoration: InputDecoration(
                hintText: step.hint,
                hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                prefixIcon: Icon(step.icon, color: AppTheme.tealPrimary, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMd,
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMd,
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMd,
                  borderSide: const BorderSide(color: AppTheme.tealPrimary, width: 1.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            // Location step: show auto-detect status
            if (_currentStep == 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _detectingLocation
                    ? const Row(children: [
                        SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(color: AppTheme.tealPrimary, strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Auto-detecting your location...',
                            style: TextStyle(color: AppTheme.tealLight, fontSize: 12)),
                      ])
                    : GestureDetector(
                        onTap: _autoDetectLocation,
                        child: const Row(children: [
                          Icon(Icons.my_location, color: AppTheme.tealPrimary, size: 14),
                          SizedBox(width: 6),
                          Text('Auto-detect my location',
                              style: TextStyle(color: AppTheme.tealPrimary, fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
              ),
          ]).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 28),

          // Navigation buttons
          Row(children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: Icon(
                  _currentStep == _steps.length - 1
                      ? Icons.check_circle_outline
                      : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  _currentStep == _steps.length - 1 ? 'Confirm Details' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Summary + AI Results ──────────────────────────────────────────────────
  Widget _buildSummary() {
    final labels = [
      _t('Service', 'خدمت'),
      _t('Location', 'مقام'),
      _t('Time', 'وقت'),
      _t('Budget', 'بجٹ'),
      _t('Notes', 'نوٹ'),
    ];
    final icons = [
      Icons.build_outlined, Icons.location_on_outlined,
      Icons.schedule_outlined, Icons.payments_outlined, Icons.notes_outlined,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.tealPrimary.withValues(alpha: 0.15),
                AppTheme.blueInfo.withValues(alpha: 0.08),
              ]),
              borderRadius: AppTheme.radiusLg,
              border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.tealPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _t('Booking Summary', 'بکنگ خلاصہ'),
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _completed = false;
                      _currentStep = 0;
                      _answers.clear();
                      _matches = [];
                    }),
                    child: Text(
                      _t('Edit', 'ترمیم'),
                      style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ...List.generate(_answers.length, (i) {
                  if (i >= labels.length || _answers[i].isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Icon(icons[i], color: AppTheme.tealPrimary, size: 14),
                      const SizedBox(width: 8),
                      Text('${labels[i]}: ',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Expanded(child: Text(_answers[i],
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  );
                }),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),


          // Live Agent Reasoning
          if (_agentSteps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: LiveAgentPanel(
                steps: _agentSteps,
                isVisible: true,
                onToggle: () {},
              ),
            ),

          // Matched workers section
          Row(children: [
            Text(
              _t('AI Matched Workers', '🧬 AI سے ملے کارکن'),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (_matches.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: Text(
                  '${_matches.length} ${_t("found", "ملے")}',
                  style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ]).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 4),
          Text(
            _t('DNA-ranked for your request', 'آپ کی درخواست کے لیے درجہ بندی'),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 14),

          // Loading / empty / results
          if (_isMatching)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  const CircularProgressIndicator(color: AppTheme.tealPrimary, strokeWidth: 2.5),
                  const SizedBox(height: 14),
                  Text(
                    _t('Analyzing your request...', 'آپ کی درخواست کا تجزیہ ہو رہا ہے...'),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ]),
              ).animate().fadeIn(),
            )
          else if (_matches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.1)),
              ),
              child: Column(children: [
                const Text('🔍', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  _t('No workers found.\nTry a different category or location.',
                     'کوئی کارکن نہیں ملا۔\nمختلف زمرہ یا مقام آزمائیں۔'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
              ]),
            ).animate().fadeIn()
          else
            ...List.generate(_matches.length, (i) {
              final match = _matches[i];
              return ProviderCard(
                match: match,
                rank: i + 1,
                isExpanded: _expandedCard == i,
                onTap: () => setState(() => _expandedCard = _expandedCard == i ? -1 : i),
                onBook: () => _openBooking(match),
              );
            }),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

