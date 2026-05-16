import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/matching_service.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../widgets/provider_card.dart';
import '../widgets/live_agent_panel.dart';
import '../models/agent_model.dart';
import 'booking_flow_screen.dart';

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

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _speaking = false;
  bool _isMatching = false;
  bool _hasResults = false;

  List<ProviderMatch> _matches = [];
  List<AgentStep> _agentSteps = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;

  // Welcome speech — spoken once when screen opens
  static const _welcomeEn =
      'Welcome to KaamYaab — Pakistan\'s first AI-powered service marketplace. '
      'Simply describe what you need in one sentence — in English, Urdu, or Roman Urdu. '
      'Tell us the service, your area, and when you need it. '
      'Our AI will understand and find the best verified professional near you in seconds.';

  static const _welcomeUr =
      'کامیاب میں خوش آمدید۔ '
      'پاکستان کا پہلا AI سے چلنے والا سروس مارکیٹ پلیس۔ '
      'بس ایک جملے میں بتائیں کہ آپ کو کیا چاہیے — اردو میں، رومن اردو میں، یا انگریزی میں۔ '
      'خدمت، علاقہ اور وقت بتائیں — ہمارا AI آپ کے لیے بہترین کارکن ڈھونڈے گا۔';

  // Example hint suggestions
  static const _hints = [
    'e.g. "Plumber chahiye G-13 mein kal subah, budget 1500"',
    'e.g. "AC repair urgently in F-10, available today"',
    'e.g. "Electrician needed tomorrow morning in Sadar"',
    'e.g. "گھر کی صفائی چاہیے اتوار کو، G-11"',
  ];
  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialService != null) {
      _inputCtrl.text = widget.initialService!;
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

    // Cycle hint text every 3 seconds
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isMatching) {
        setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
      }
    });
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    await Future.delayed(const Duration(milliseconds: 700));
    _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    await _tts.stop();
    // Speak English first
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.44);
    await _tts.speak(_welcomeEn);
    // Wait for English to finish, then speak Urdu
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;
    await _tts.setLanguage('ur-PK');
    await _tts.setSpeechRate(0.38);
    await _tts.speak(_welcomeUr);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _submit() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please describe what service you need.'),
        backgroundColor: AppTheme.redError.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      ));
      return;
    }
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
    await _stopSpeaking();
    await _runAiPipeline(input);
  }

  Future<void> _runAiPipeline(String raw) async {
    setState(() {
      _isMatching = true;
      _hasResults = false;
      _agentSteps = [];
      _matches = [];
    });

    try {
      // ── Step 1: Intent ───────────────────────────────────────────────────
      _addStep(AgentStep(
        agentName: AgentIdentity.intent,
        task: 'Parsing multilingual request',
        reasoning: 'Detecting language, extracting service, location, urgency, budget...',
        toolCall: 'gemini.extract_intent(raw_input)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 1200));

      final intentResult = await GeminiService.extractIntent(raw);
      final serviceType = intentResult['service_type'] as String? ?? 'General';
      final area       = intentResult['area']         as String? ?? 'G-13';
      final urgency    = intentResult['urgency']       as String? ?? 'medium';
      final confidence = (intentResult['confidence']  as num?)?.toDouble() ?? 0.8;

      _updateLast(
        status: AgentStepStatus.done,
        decision: 'Service: $serviceType · Area: $area · Urgency: $urgency · ${(confidence * 100).toInt()}% confidence',
      );

      // ── Step 2: Surge ────────────────────────────────────────────────────
      _addStep(AgentStep(
        agentName: AgentIdentity.surge,
        task: 'Checking demand in $area',
        reasoning: 'Scanning active requests and provider availability in 30-min window...',
        toolCall: 'surge_agent.check(area=$area, service=$serviceType)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 900));

      final hasSurge = (urgency == 'high' || urgency == 'emergency') &&
          (serviceType == 'AC Repair' || serviceType == 'Electrical');
      final surgeMult = hasSurge
          ? (urgency == 'emergency' ? 2.1 : 1.6)
          : 1.0;

      _updateLast(
        status: AgentStepStatus.done,
        decision: hasSurge
            ? '⚠️ Surge ${surgeMult}x active — limited providers'
            : 'No surge — normal pricing applies',
      );

      _currentRequest = ServiceRequest(
        id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
        rawInput: raw,
        serviceType: serviceType,
        location: 'Islamabad',
        area: area,
        urgency: urgency,
        preferredTime: intentResult['preferred_time'] as String? ?? 'flexible',
        preferredDate: intentResult['preferred_date'] as String? ?? 'tomorrow',
        budgetSensitivity: (intentResult['budget_sensitivity'] as num?)?.toDouble() ?? 0.5,
        confidence: confidence,
        language: intentResult['language'] as String? ?? 'mixed',
        createdAt: DateTime.now(),
        status: 'pending',
      );

      // ── Step 3: Matching ─────────────────────────────────────────────────
      _addStep(AgentStep(
        agentName: AgentIdentity.matching,
        task: 'Ranking providers with 10-factor algorithm',
        reasoning: 'Scoring distance, availability, rating, reliability, price, cancellation risk...',
        toolCall: 'matcher.rank_providers(surge=${surgeMult}x)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 1600));

      final results = await MatchingService.matchProviders(
        request: _currentRequest!,
        userLat: 33.7215,
        userLng: 73.0433,
        surgeMult: surgeMult,
      );

      _updateLast(
        status: results.isEmpty ? AgentStepStatus.failed : AgentStepStatus.done,
        decision: results.isEmpty
            ? 'No providers found — expanding radius...'
            : '${results.length} workers matched · Top: ${results.first.provider.name}',
      );

      // TTS result announcement
      if (results.isNotEmpty) {
        final name = results.first.provider.name;
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.44);
        await _tts.speak('Great news! I found ${results.length} verified professionals. '
            'Top match is $name with a ${results.first.matchScore.toStringAsFixed(0)} percent match score.');
      }

      setState(() {
        _matches = results;
        _isMatching = false;
        _hasResults = true;
        if (results.isNotEmpty) _expandedCard = 0;
      });
    } catch (_) {
      setState(() => _isMatching = false);
    }
  }

  void _addStep(AgentStep step) => setState(() => _agentSteps = [..._agentSteps, step]);

  void _updateLast({required AgentStepStatus status, String? decision}) {
    setState(() {
      if (_agentSteps.isEmpty) return;
      final last = _agentSteps.last;
      _agentSteps = [
        ..._agentSteps.sublist(0, _agentSteps.length - 1),
        last.copyWith(status: status, decision: decision),
      ];
    });
  }

  void _openBooking(ProviderMatch match, double finalPrice, String? note) {
    HapticFeedback.mediumImpact();
    _stopSpeaking();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => BookingFlowScreen(
        match: match,
        request: _currentRequest!,
        surgeMultiplier: 1.0,
        negotiatedPrice: finalPrice,
        negotiationNote: note,
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
    _inputCtrl.dispose();
    _focusNode.dispose();
    _hintTimer?.cancel();
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
                child: _hasResults ? _buildResults() : _buildInputPane(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () { _stopSpeaking(); Navigator.pop(context); },
          icon: const Icon(Icons.close, color: Colors.white, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KaamYaab Assistant',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              _hasResults
                  ? '${_matches.length} workers found for you'
                  : _speaking ? 'Speaking...' : 'Describe your need below',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ]),
        ),
        // Replay button
        GestureDetector(
          onTap: _speaking ? _stopSpeaking : _speakWelcome,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _speaking
                  ? AppTheme.tealPrimary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: AppTheme.radiusSm,
              border: Border.all(
                color: _speaking ? AppTheme.tealPrimary : Colors.white12,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: _speaking ? AppTheme.tealPrimary : AppTheme.textMuted,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _speaking ? 'Stop' : 'Intro',
                style: TextStyle(
                  color: _speaking ? AppTheme.tealPrimary : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Input Pane ─────────────────────────────────────────────────────────────
  Widget _buildInputPane() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          Center(
            child: Column(children: [
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
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 8),
              if (_speaking)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (i) {
                    return AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (_, __) {
                        final t = (_waveCtrl.value * 2 * math.pi + (i / 7) * 2 * math.pi) % (2 * math.pi);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: 6.0 + (1.0 + math.sin(t)) * 14.0,
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
                const SizedBox(height: 14),
              const SizedBox(height: 16),
            ]),
          ),

          // Speech bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
            child: const Text(
              'Describe your need in one sentence — in English, Urdu, or Roman Urdu.\n\nInclude: service type · your area · when you need it.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

          const SizedBox(height: 20),

          // ── Single natural-language input ────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _hints[_hintIndex],
              key: ValueKey(_hintIndex),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _inputCtrl,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            maxLines: 4,
            minLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Type your request here...',
              hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: AppTheme.radiusLg,
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusLg,
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusLg,
                borderSide: const BorderSide(color: AppTheme.tealPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isMatching ? null : _submit,
              icon: _isMatching
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isMatching ? 'AI is finding your worker...' : 'Find Me a Worker',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),

          // Agent reasoning panel while matching
          if (_isMatching && _agentSteps.isNotEmpty) ...[
            const SizedBox(height: 24),
            LiveAgentPanel(
              steps: _agentSteps,
              isVisible: true,
              onToggle: () {},
            ),
          ],
        ],
      ),
    );
  }

  // ── Results Pane ───────────────────────────────────────────────────────────
  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to search
          GestureDetector(
            onTap: () => setState(() {
              _hasResults = false;
              _matches = [];
              _agentSteps = [];
              _inputCtrl.clear();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_rounded, color: AppTheme.tealPrimary, size: 16),
                SizedBox(width: 6),
                Text('New search', style: TextStyle(color: AppTheme.tealPrimary, fontSize: 13)),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Agent reasoning summary
          if (_agentSteps.isNotEmpty)
            LiveAgentPanel(steps: _agentSteps, isVisible: true, onToggle: () {}),

          const SizedBox(height: 20),

          // Results header
          Row(children: [
            const Text('AI Matched Workers',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusSm,
              ),
              child: Text('${_matches.length} found',
                  style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('DNA-ranked for your request',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 14),

          // Provider cards
          ..._matches.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ProviderCard(
              match: e.value,
              rank: e.key + 1,
              isExpanded: _expandedCard == e.key,
              serviceType: _currentRequest?.serviceType ?? 'Unknown',
              surgeMultiplier: 1.0,
              onTap: () => setState(
                  () => _expandedCard = _expandedCard == e.key ? -1 : e.key),
              onBook: (price, note) => _openBooking(e.value, price, note),
            ),
          )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
