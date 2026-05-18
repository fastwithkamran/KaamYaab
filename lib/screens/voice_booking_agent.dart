import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/language_service.dart';
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
  double _surgeMult = 1.0; // stored so _openBooking can pass the correct value

  List<ProviderMatch> _matches = [];
  List<AgentStep> _agentSteps = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;

  static const _welcomeEn =
      'Welcome to KaamYaab — Pakistan\'s first AI-powered service marketplace. '
      'Simply describe what you need in one sentence — in English, Urdu, or Roman Urdu. '
      'Tell us the service, your area, and when you need it.';

  static const _welcomeUr =
      'کامیاب میں خوش آمدید۔ '
      'پاکستان کا پہلا AI سے چلنے والا سروس مارکیٹ پلیس۔ '
      'بس ایک جملے میں بتائیں کہ آپ کو کیا چاہیے — اردو میں، رومن اردو میں، یا انگریزی میں۔';

  static const _hints = [
    'e.g. "Plumber chahiye G-13 mein kal subah, budget 1500"',
    'e.g. "AC repair urgently in F-10, available today"',
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

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isMatching) {
        setState(() { _hintIndex = (_hintIndex + 1) % _hints.length; });
      }
    });
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() { if (mounted) setState(() => _speaking = true); });
    _tts.setCompletionHandler(() { if (mounted) setState(() => _speaking = false); });
    _tts.setCancelHandler(() { if (mounted) setState(() => _speaking = false); });
    await Future.delayed(const Duration(milliseconds: 700));
    _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    await _tts.stop();
    final isUrdu = LanguageService().isUrdu;
    if (isUrdu) {
      await _tts.setLanguage('ur-PK');
      await _tts.setSpeechRate(0.38);
      await _tts.speak(_welcomeUr);
    } else {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.44);
      await _tts.speak(_welcomeEn);
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _submit() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
    await _stopSpeaking();
    await _runAiPipeline(input);
  }

  Future<void> _runAiPipeline(String raw) async {
    final isUrdu = LanguageService().isUrdu;
    setState(() {
      _isMatching = true;
      _hasResults = false;
      _agentSteps = [];
      _matches = [];
    });

    try {
      _addStep(AgentStep(
        agentName: AgentIdentity.intent,
        task: isUrdu ? 'درخواست کا تجزیہ' : 'Multi-layered intent analysis',
        reasoning: isUrdu ? 'زبان کی شناخت اور خدمت نکالی جا رہی ہے...' : 'Analyzing user nuance and slang...',
        toolCall: 'cohere.chat(message=input)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 1000));

      final intentResult = await AiService.extractIntent(raw);
      final serviceType = intentResult['service_type'] as String? ?? 'General';
      final area       = intentResult['area']         as String? ?? 'G-13';
      final urgency    = intentResult['urgency']       as String? ?? 'medium';

      _updateLast(
        status: AgentStepStatus.done,
        decision: isUrdu ? 'نتیجہ: $serviceType ($area)' : 'Result: $serviceType in $area',
      );

      _addStep(AgentStep(
        agentName: AgentIdentity.matching,
        task: isUrdu ? 'AI انتخاب' : 'Agentic Selection',
        reasoning: isUrdu ? 'بہترین کارکن کا انتخاب کیا جا رہا ہے...' : 'Evaluating provider DNA and pricing...',
        toolCall: 'cohere.rank_providers(intent, providers)',
        status: AgentStepStatus.thinking,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 1500));

      final hasSurge = (urgency == 'high' || urgency == 'emergency') && (serviceType == 'AC Repair' || serviceType == 'Electrical');
      final surgeMult = hasSurge ? (urgency == 'emergency' ? 2.1 : 1.6) : 1.0;
      _surgeMult = surgeMult; // persist so _openBooking can read it

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
        confidence: (intentResult['confidence'] as num?)?.toDouble() ?? 0.8,
        language: intentResult['language'] as String? ?? 'mixed',
        createdAt: DateTime.now(),
        status: 'pending',
        jobComplexity: intentResult['job_complexity'] as String? ?? 'basic',
      );

      final results = await MatchingService.matchProviders(
        request: _currentRequest!,
        userLat: 33.7215,
        userLng: 73.0433,
        surgeMult: surgeMult,
        isUrdu: isUrdu,
      );

      _updateLast(
        status: results.isEmpty ? AgentStepStatus.failed : AgentStepStatus.done,
        decision: results.isEmpty ? (isUrdu ? 'کوئی کارکن نہیں ملا۔' : 'No providers found.') : (isUrdu ? 'بہترین میچ ملا۔' : 'Top match found.'),
      );

      if (results.isNotEmpty) {
        final name = results.first.provider.name;
        if (isUrdu) {
          await _tts.setLanguage('ur-PK');
          await _tts.setSpeechRate(0.38);
          await _tts.speak('مجھے آپ کے لیے بہترین کارکن مل گئے ہیں۔ ٹاپ میچ $name ہیں۔');
        } else {
          await _tts.setLanguage('en-US');
          await _tts.setSpeechRate(0.44);
          await _tts.speak('I have found the best professionals. Top match is $name.');
        }
      }

      if (mounted) {
        setState(() {
          _matches = results;
          _isMatching = false;
          _hasResults = true;
          if (results.isNotEmpty) _expandedCard = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMatching = false);
    }
  }

  void _addStep(AgentStep step) {
    if (mounted) setState(() => _agentSteps = [..._agentSteps, step]);
  }

  void _updateLast({required AgentStepStatus status, String? decision}) {
    if (mounted) {
      setState(() {
        if (_agentSteps.isEmpty) return;
        final last = _agentSteps.last;
        _agentSteps = [..._agentSteps.sublist(0, _agentSteps.length - 1), last.copyWith(status: status, decision: decision)];
      });
    }
  }

  void _openBooking(ProviderMatch match, double finalPrice, String? note) {
    _stopSpeaking();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingFlowScreen(
        match: match,
        request: _currentRequest!,
        surgeMultiplier: _surgeMult, // BUG-004 FIX: use actual calculated surge
        negotiatedPrice: finalPrice,
        negotiationNote: note,
      ),
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
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _hasResults ? _buildResults() : _buildInputPane()),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isUrdu = LanguageService().isUrdu;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isUrdu ? 'کامیاب اسسٹنٹ' : 'KaamYaab Assistant', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(_speaking ? (isUrdu ? 'بول رہا ہے...' : 'Speaking...') : (isUrdu ? 'اپنی ضرورت بتائیں' : 'Describe your need'), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _buildInputPane() {
    final isUrdu = LanguageService().isUrdu;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _speaking ? AppTheme.tealPrimary.withValues(alpha: 0.2) : AppTheme.cardDark,
              border: Border.all(color: _speaking ? AppTheme.tealPrimary : Colors.white12),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 24),
        Text(isUrdu ? 'میں آپ کی کیسے مدد کر سکتا ہوں؟' : 'How can I help you today?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        TextField(
          controller: _inputCtrl,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: isUrdu ? 'اپنی درخواست یہاں لکھیں...' : 'Type your request here...',
            filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: AppTheme.radiusMd),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isMatching ? null : _submit,
            child: Text(isUrdu ? 'تلاش کریں' : 'Find Worker'),
          ),
        ),
        if (_isMatching) ...[
          const SizedBox(height: 24),
          LiveAgentPanel(steps: _agentSteps, isVisible: true, onToggle: () {}),
        ],
      ]),
    );
  }

  Widget _buildResults() {
    final isUrdu = LanguageService().isUrdu;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextButton.icon(onPressed: () => setState(() => _hasResults = false), icon: const Icon(Icons.arrow_back), label: Text(isUrdu ? 'نئی تلاش' : 'New Search')),
        const SizedBox(height: 16),
        if (_agentSteps.isNotEmpty) LiveAgentPanel(steps: _agentSteps, isVisible: true, onToggle: () {}),
        const SizedBox(height: 24),
        ..._matches.asMap().entries.map((e) => ProviderCard(
          match: e.value, rank: e.key + 1, isExpanded: _expandedCard == e.key,
          serviceType: _currentRequest?.serviceType ?? 'Unknown',
          surgeMultiplier: 1.0,
          onTap: () => setState(() => _expandedCard = _expandedCard == e.key ? -1 : e.key),
          onBook: (p, n) => _openBooking(e.value, p, n),
        )),
      ],
    );
  }
}
