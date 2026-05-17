import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/location_service.dart';

enum AgentInputMode { voice, text }
enum OnboardingState { notStarted, askingService, askingAvailability, completed }

class WorkerAgentChatBottomSheet extends StatefulWidget {
  final AgentInputMode initialMode;
  const WorkerAgentChatBottomSheet({super.key, this.initialMode = AgentInputMode.voice});

  @override
  State<WorkerAgentChatBottomSheet> createState() => _WorkerAgentChatBottomSheetState();
}

class _WorkerAgentChatBottomSheetState extends State<WorkerAgentChatBottomSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AgentInputMode _currentMode;
  bool _isListening = false;
  String _voiceText = '';
  final List<_ChatMessage> _chatLog = [];
  bool _isProcessing = false;
  OnboardingState _onboardingState = OnboardingState.notStarted;
  final bool _isUrdu = LanguageService().isUrdu;

  late AnimationController _micPulseCtrl;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;

    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initSpeech();
    _sendAgentGreeting();
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

  void _sendAgentGreeting() {
    final user = AuthService().currentUser;
    final name = user?.name.split(' ').first ?? 'there';
<<<<<<< HEAD
    final category = user?.serviceCategory;
=======
>>>>>>> cbb51c88c7537750323fa764b26eeb3f9ab41613
    final rules = user?.availabilityRules ?? [];

    String greeting;
    String ttsGreeting;
    final isUrdu = LanguageService().isUrdu;

    if (category == 'Unassigned' || category == null) {
      _onboardingState = OnboardingState.askingService;
      greeting = _t(
        "Salam $name! 👋 Welcome. Tell me, what services do you offer? (e.g. Plumbing, Electrician)",
        "اسلام علیکم $name! 👋 خوش آمدید۔ مجھے بتائیں، آپ کیا خدمت فراہم کرتے ہیں؟ (مثلاً پلمبر، بجلی کا کام)"
      );
      ttsGreeting = isUrdu 
        ? "سلام $name! کامیاب میں خوش آمدید۔ براہ کرم مجھے بتائیں کہ آپ کس قسم کی خدمت فراہم کرتے ہیں؟ آپ اردو یا انگریزی میں بول سکتے ہیں۔"
        : "Salam $name! Welcome to KaamYaab. Please tell me what kind of work you do? You can speak in Urdu or English.";
    } else if (rules.isEmpty) {
      _onboardingState = OnboardingState.askingAvailability;
      greeting = _t(
        "Salam $name! 👋 Tell me when you're available for service?",
        "اسلام علیکم $name! 👋 مجھے بتائیں کہ آپ کس وقت خدمت کے لیے دستیاب ہیں؟"
      );
      ttsGreeting = isUrdu
        ? "براہ کرم مجھے اپنے کام کے اوقات یا دن بتائیں جب آپ دستیاب ہوں۔"
        : "Salam $name! Please tell me your working hours or days when you are available.";
    } else {
      _onboardingState = OnboardingState.completed;
      greeting = _t(
        "Welcome back $name! Your schedule is set. Want to change anything?",
        "خوش آمدید $name! آپ کا شیڈول سیٹ ہے۔ کیا آپ کچھ تبدیل کرنا چاہتے ہیں؟"
      );
      ttsGreeting = "Welcome back $name! Your schedule is active. If you want to change your timing, just tell me.";
    }

    _addAgentMessage(greeting);
    _speak(ttsGreeting);
  }

  void _initSpeech() async {
    bool available = await _speech.initialize();
    if (mounted) {
      setState(() {
        if (available && _currentMode == AgentInputMode.voice) {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted && !_isListening) _toggleListening();
          });
        }
      });
    }
  }

  void _speak(String text, {bool? isUrdu}) async {
    final useUrdu = isUrdu ?? LanguageService().isUrdu;
    if (useUrdu) {
      await _tts.setLanguage('ur-PK');
      await _tts.setSpeechRate(0.38);
    } else {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
    }
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  void _addAgentMessage(String text) {
    setState(() => _chatLog.add(_ChatMessage(text: text, isAgent: true)));
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() => _chatLog.add(_ChatMessage(text: text, isAgent: false)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() { _isListening = true; _voiceText = ''; });
        _micPulseCtrl.repeat(reverse: true);
        _speech.listen(onResult: (val) => setState(() => _voiceText = val.recognizedWords));
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _isListening = false);
      _micPulseCtrl.stop(); _micPulseCtrl.reset();
      _speech.stop();
      if (_voiceText.isNotEmpty) _processInput(_voiceText);
    }
  }

  Future<void> _processInput(String userInput) async {
    if (userInput.isEmpty) return;
    _addUserMessage(userInput);
    setState(() => _isProcessing = true);

    final user = AuthService().currentUser;
    final isUrdu = LanguageService().isUrdu;
    if (user != null) {
      try {
        if (_onboardingState == OnboardingState.askingService) {
          final result = await AiService.extractWorkerService(userInput);
          final category = result['category'] as String;
          final skills = (result['skills'] as List).map((e) => e.toString()).toList();
          await AuthService().updateWorkerService(category, skills);
          
          _onboardingState = OnboardingState.askingAvailability;
          final resp = _t("Great! You are set as a $category. Now, what are your working hours?", 
                          "بہترین! آپ کو $category کے طور پر سیٹ کر دیا گیا ہے۔ اب بتائیں، آپ کے کام کے اوقات کیا ہیں؟");
          _addAgentMessage(resp);
          _speak(isUrdu 
            ? "بہترین! میں نے آپ کا زمرہ سیٹ کر دیا ہے۔ اب براہ کرم مجھے اپنے کام کے اوقات بتائیں۔"
            : "Great! I have set your category. Now please tell me your working hours.");
        } else {
          final updatedRules = await AiService.processWorkerSettings(userInput, user.availabilityRules ?? []);
          await AuthService().setAvailabilityRules(updatedRules);
          await _saveWorkerLocation();

          _onboardingState = OnboardingState.completed;
          final resp = _t("All set! ✅ Your schedule is updated. I will notify you of new jobs nearby.", 
                          "سب ٹھیک ہے! ✅ آپ کا شیڈول اپ ڈیٹ ہو گیا ہے۔ میں آپ کو قریبی نئے کاموں کے بارے میں مطلع کروں گا۔");
          _addAgentMessage(resp);
          _speak(isUrdu
            ? "سب ٹھیک ہے! آپ کا شیڈول اپ ڈیٹ ہو گیا ہے۔ جب آپ کے قریب کوئی کام ہوگا تو ہم آپ کو مطلع کریں گے۔"
            : "All done! Your schedule is updated. We will let you know when there is a job near you.");
        }
      } catch (e) {
        _addAgentMessage(isUrdu ? "معذرت، میں سمجھ نہیں سکا۔ براہ کرم دوبارہ کوشش کریں۔" : "Sorry, I didn't get that. Please try again.");
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _saveWorkerLocation() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc.isSuccess && loc.data != null) {
        await LocationService().saveUserLocation(AuthService().currentUser!.uid, loc.data!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _speech.stop(); _tts.stop();
    _textController.dispose(); _focusNode.dispose();
    _scrollController.dispose(); _micPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          
          Flexible(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: AppTheme.radiusLg),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatLog.length + (_isProcessing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _chatLog.length) return _buildTypingIndicator();
                  return _buildMessageBubble(_chatLog[index]);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_isListening)
            Text(_voiceText.isEmpty ? "Listening... آپ بولیں" : _voiceText,
                 style: const TextStyle(color: AppTheme.purpleLight, fontSize: 16, fontWeight: FontWeight.w600)),
          
          const SizedBox(height: 16),

          _buildMainAction(),
          
          const SizedBox(height: 12),
          Text(_isListening ? "Tap to Stop" : "Tap to Speak", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMainAction() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _micPulseCtrl,
        builder: (context, child) => Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening ? AppTheme.redAlert : AppTheme.purpleAgent,
            boxShadow: [
              BoxShadow(
                color: (_isListening ? AppTheme.redAlert : AppTheme.purpleAgent).withValues(alpha: 0.4),
                blurRadius: 20 + 10 * _micPulseCtrl.value, spreadRadius: 2 + 4 * _micPulseCtrl.value,
              )
            ],
          ),
          child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: msg.isAgent ? AppTheme.purpleAgent.withValues(alpha: 0.15) : AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (msg.isAgent ? AppTheme.purpleAgent : AppTheme.tealPrimary).withValues(alpha: 0.2)),
              ),
              child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.purpleLight)),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAgent;
  const _ChatMessage({required this.text, required this.isAgent});
}
