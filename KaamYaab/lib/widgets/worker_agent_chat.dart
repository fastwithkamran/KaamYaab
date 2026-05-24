import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/chat_history_service.dart';
import '../models/user_model.dart';

enum AgentInputMode { voice, text }

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet entry point — used by WorkerHomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class WorkerAgentChatBottomSheet extends StatelessWidget {
  final AgentInputMode initialMode;
  const WorkerAgentChatBottomSheet({
    super.key,
    this.initialMode = AgentInputMode.voice,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: WorkerAgentChatScreen(
          scrollController: controller,
          initialMode: initialMode,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core chat screen
// ─────────────────────────────────────────────────────────────────────────────
class WorkerAgentChatScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final AgentInputMode initialMode;

  const WorkerAgentChatScreen({
    super.key,
    this.scrollController,
    this.initialMode = AgentInputMode.voice,
  });

  @override
  State<WorkerAgentChatScreen> createState() => _WorkerAgentChatScreenState();
}

class _WorkerAgentChatScreenState extends State<WorkerAgentChatScreen>
    with TickerProviderStateMixin {
  // ── services
  late FlutterTts _tts;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _chatHistory = ChatHistoryService();

  // ── UI state
  late AnimationController _pulseCtrl;
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _isListening = false;
  bool _isAILoading = false;
  bool _profileSaved = false;
  late AgentInputMode _mode;

  // ── onboarding state
  // Valid states: greeting | asking_service | asking_skills | asking_experience |
  //               asking_rates | asking_availability | asking_bio | confirming | idle
  String _agentState = 'greeting';
  final Map<String, dynamic> _collectedProfile = {};

  // ── chat messages
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _chatHistory.init();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initTts();
    _initSpeech();

    // FIX: add a listener so the send button re-renders (active ↔ inactive)
    // whenever the text field changes. The original had no listener here,
    // so the button never changed colour reactively.
    _inputCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startGreeting());
  }

  // ── TTS / STT init ──────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() {});
    _tts.setCancelHandler(() {});
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
    if (mounted) setState(() {});
  }

  // ── Greeting ────────────────────────────────────────────────────────────────
  Future<void> _startGreeting() async {
    final user = AuthService().currentUser;

    if (user != null && user.isProfileComplete) {
      // Profile already complete — show summary so worker can review/update
      final summary = _buildProfileSummaryText(user);
      _addAgentMessage(
        "Welcome back, ${user.name.split(' ').first} bhai! 👋\n\n"
        "Aapka profile already complete hai:\n\n$summary\n\n"
        "Koi cheez update karni ho toh batayein (jaise rates ya availability), "
        "warna cross button dabayein!",
      );
      setState(() {
        _agentState = 'idle';
        _profileSaved = true;
      });
      return;
    }

    // New worker or incomplete profile — start onboarding from scratch
    setState(() {
      _agentState = 'greeting';
      _isAILoading = true;
    });
    try {
      final result = await AiService.processWorkerChat(
        message: 'START_ONBOARDING',
        chatHistory: [],
        currentState: 'greeting',
        partialProfile: _collectedProfile,
      );
      _handleAgentResponse(result, isGreeting: true);
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  // ── Toggle voice input ──────────────────────────────────────────────────────
  void _toggleListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() => _inputCtrl.text = val.recognizedWords);
            if (val.finalResult) {
              setState(() => _isListening = false);
              _submit();
            }
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: 'en_US',
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ── Submit user message ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
    await _tts.stop();
    _inputCtrl.clear();

    _addUserMessage(input);
    await _chatHistory.addMessage('USER', input);

    setState(() => _isAILoading = true);
    try {
      final result = await AiService.processWorkerChat(
        message: input,
        chatHistory: _chatHistory.toCohereFormat(),
        currentState: _agentState,
        partialProfile: _collectedProfile,
      );
      _handleAgentResponse(result);
    } catch (e) {
      debugPrint('Worker agent error: $e');
      _addAgentMessage('Bhai, thora network issue hai. Dobara try karein please.');
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  // ── Process agent response ──────────────────────────────────────────────────
  void _handleAgentResponse(
    Map<String, dynamic> result, {
    bool isGreeting = false,
  }) {
    final reply = result['reply'] as String? ?? '';
    final nextState = result['next_state'] as String? ?? _agentState;
    final shouldCommit = result['should_commit'] as bool? ?? false;
    final rawExtracted = result['extracted_data'];
    final Map<String, dynamic> extracted = rawExtracted is Map
        ? Map<String, dynamic>.from(rawExtracted)
        : {};

    extracted.forEach((k, v) {
      if (v != null) _collectedProfile[k] = v;
    });

    if (mounted) setState(() => _agentState = nextState);

    _addAgentMessage(reply);
    _chatHistory.addMessage('CHATBOT', reply);
    _tts.speak(reply);

    if (_collectedProfile.isNotEmpty) _savePartialProfile(_collectedProfile);
    if (shouldCommit) _commitFullProfile();
  }

  // ── Partial (real-time) profile save ───────────────────────────────────────
  Future<void> _savePartialProfile(Map<String, dynamic> data) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final updated = user.copyWith(
        serviceCategory: data['category'] as String? ?? user.serviceCategory,
        subRole: data['sub_role'] as String? ?? user.subRole,
        skills: data['skills'] != null
            ? List<String>.from(data['skills'] as List)
            : user.skills,
        baseRatePkr: (data['base_rate_pkr'] as num?)?.toDouble() ?? user.baseRatePkr,
        minRatePkr: (data['min_rate_pkr'] as num?)?.toDouble() ?? user.minRatePkr,
        maxRatePkr: (data['max_rate_pkr'] as num?)?.toDouble() ?? user.maxRatePkr,
        negotiationStyle: data['negotiation_style'] as String? ?? user.negotiationStyle,
        experienceYears: (data['experience_years'] as num?)?.toInt() ?? user.experienceYears,
        bio: data['bio'] as String? ?? user.bio,
        availabilityRules: data['availability_rules'] != null
            ? List<String>.from(data['availability_rules'] as List)
            : user.availabilityRules,
      );

      await AuthService().updateUserProfile(updated);
      debugPrint('Partial profile saved: ${data.keys.toList()}');
    } catch (e) {
      debugPrint('Partial save error: $e');
    }
  }

  // ── Full commit ─────────────────────────────────────────────────────────────
  Future<void> _commitFullProfile() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final updated = user.copyWith(
        serviceCategory: _collectedProfile['category'] as String? ?? user.serviceCategory,
        subRole: _collectedProfile['sub_role'] as String? ?? user.subRole,
        skills: _collectedProfile['skills'] != null
            ? List<String>.from(_collectedProfile['skills'] as List)
            : user.skills,
        baseRatePkr: (_collectedProfile['base_rate_pkr'] as num?)?.toDouble() ?? user.baseRatePkr,
        minRatePkr: (_collectedProfile['min_rate_pkr'] as num?)?.toDouble() ?? user.minRatePkr,
        maxRatePkr: (_collectedProfile['max_rate_pkr'] as num?)?.toDouble() ?? user.maxRatePkr,
        negotiationStyle: _collectedProfile['negotiation_style'] as String? ?? user.negotiationStyle,
        experienceYears: (_collectedProfile['experience_years'] as num?)?.toInt() ?? user.experienceYears,
        bio: _collectedProfile['bio'] as String? ?? user.bio,
        availabilityRules: _collectedProfile['availability_rules'] != null
            ? List<String>.from(_collectedProfile['availability_rules'] as List)
            : user.availabilityRules,
      );

      await AuthService().updateUserProfile(updated);
      debugPrint('Full profile committed to Firestore');

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _agentState = 'idle';
          _profileSaved = true;
        });
        // Show a confirmation message then close
        _addAgentMessage(
          'Bohat acha bhai! 🎉 Aapka profile save ho gaya hai.\n\n'
          'Ab aap job requests receive karna shuru karein ge. '
          'KaamYaab par aapka khushamadeed!',
        );
        // Auto-dismiss after reading the success message
        Future.delayed(const Duration(milliseconds: 2800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      debugPrint('Full profile commit error: $e');
      if (mounted) {
        _addAgentMessage(
          'Bhai, profile save karte waqt masla ho gaya. Dobara try karein please.',
        );
      }
    }
  }

  // ── Chat message helpers ────────────────────────────────────────────────────
  void _addAgentMessage(String text) {
    if (mounted) setState(() => _messages.add(_ChatMessage(text: text, isUser: false)));
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    if (mounted) setState(() => _messages.add(_ChatMessage(text: text, isUser: true)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Profile summary (returning workers) ────────────────────────────────────
  String _buildProfileSummaryText(AppUser user) {
    final lines = <String>[];
    if (user.serviceCategory != null) lines.add('Category: ${user.serviceCategory}');
    if (user.subRole != null) lines.add('Specialty: ${user.subRole}');
    if (user.skills != null && user.skills!.isNotEmpty) {
      lines.add('Skills: ${user.skills!.join(', ')}');
    }
    if (user.baseRatePkr != null) lines.add('Base Rate: Rs.${user.baseRatePkr!.toInt()}/hr');
    if (user.minRatePkr != null) lines.add('Min Rate: Rs.${user.minRatePkr!.toInt()}/hr');
    if (user.maxRatePkr != null) lines.add('Max Rate: Rs.${user.maxRatePkr!.toInt()}/hr');
    if (user.negotiationStyle != null) lines.add('Negotiation: ${user.negotiationStyle}');
    if (user.experienceYears != null) lines.add('Experience: ${user.experienceYears} yrs');
    if (user.availabilityRules != null && user.availabilityRules!.isNotEmpty) {
      lines.add('Available: ${user.availabilityRules!.join(', ')}');
    }
    return lines.join('\n');
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _pulseCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            _buildHeader(),
            if (_profileSaved) _buildSuccessBanner(),
            Expanded(child: _buildMessageList()),
            if (_isAILoading) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'KaamYaab Profile Assistant',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                _agentState == 'idle'
                    ? '✓ Profile Complete'
                    : _agentState == 'confirming'
                        ? 'Confirming your details...'
                        : _agentState == 'asking_rates'
                            ? 'Step 5/7 — Pay & Rates'
                            : _agentState == 'asking_experience'
                                ? 'Step 4/7 — Experience'
                                : _agentState == 'asking_skills'
                                    ? 'Step 3/7 — Skills'
                                    : _agentState == 'asking_availability'
                                        ? 'Step 6/7 — Availability'
                                        : _agentState == 'asking_bio'
                                            ? 'Step 7/7 — About You'
                                            : 'Step 2/7 — Service Type',
                style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11),
              ),
            ]),
          ),
          // Voice ↔ Text mode toggle
          GestureDetector(
            onTap: () => setState(() => _mode = _mode == AgentInputMode.voice
                ? AgentInputMode.text
                : AgentInputMode.voice),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: Colors.white12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _mode == AgentInputMode.voice ? Icons.mic : Icons.keyboard,
                  color: AppTheme.textMuted,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _mode == AgentInputMode.voice ? 'Voice' : 'Text',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Success banner ──────────────────────────────────────────────────────────
  Widget _buildSuccessBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.greenSuccess.withValues(alpha: 0.12),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.greenSuccess.withValues(alpha: 0.3)),
      ),
      child: const Row(children: [
        Icon(Icons.check_circle_outline, color: AppTheme.greenSuccess, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Profile saved! You will now receive job requests.',
            style: TextStyle(
              color: AppTheme.greenSuccess,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  // ── Message list ────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_messages.isEmpty && _isAILoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.tealPrimary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser
                ? AppTheme.tealPrimary.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? AppTheme.tealLight : AppTheme.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  // ── Typing indicator ────────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(200),
            const SizedBox(width: 4),
            _dot(400),
          ]),
        ),
      ),
    );
  }

  // FIX 1: the original `_dot(int delayMs)` accepted a delay parameter but
  // never used it — all three dots shared the same `_pulseCtrl.value` and
  // animated in lock-step. The fix shifts each dot's phase by its delay
  // relative to the animation period so they actually stagger.
  //
  // FIX 2: the original AnimatedBuilder used `(_, _)` — two parameters both
  // named `_`. This is invalid in Dart (duplicate parameter names); the second
  // ignored parameter must be a different identifier, conventionally `__`.
  Widget _dot(int delayMs) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final phase = ((_pulseCtrl.value + delayMs / 900.0) % 1.0);
        final brightness = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
        return Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.tealPrimary.withValues(alpha: 0.3 + 0.7 * brightness),
          ),
        );
      },
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: _mode == AgentInputMode.voice ? _buildVoiceBar() : _buildTextBar(),
    );
  }

  // FIX: extracted the shared text field into `_sharedTextField()` to avoid
  // duplicating the exact same InputDecoration/style in both voice and text bars.
  Widget _sharedTextField({required String hint, int maxLines = 1}) {
    return TextField(
      controller: _inputCtrl,
      focusNode: _focusNode,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 16 : 24),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  /// Send button — active only when there's text.
  Widget _sendButton() {
    final hasText = _inputCtrl.text.isNotEmpty;
    return GestureDetector(
      onTap: hasText ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasText ? AppTheme.tealPrimary : AppTheme.tealPrimary.withValues(alpha: 0.3),
        ),
        child: Icon(
          Icons.send_rounded,
          color: hasText ? Colors.white : Colors.white38,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildVoiceBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _sharedTextField(hint: 'Ya yahan likhein...')),
        const SizedBox(width: 10),
        // Mic button
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) => Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? AppTheme.redAlert.withValues(alpha: 0.15)
                    : AppTheme.purpleAgent.withValues(alpha: 0.2),
                border: Border.all(
                  color: _isListening ? AppTheme.redAlert : AppTheme.purpleAgent,
                  width: 2,
                ),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: AppTheme.redAlert.withValues(alpha: 0.4 * _pulseCtrl.value),
                          blurRadius: 16,
                          spreadRadius: 4 * _pulseCtrl.value,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? AppTheme.redAlert : AppTheme.purpleAgent,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sendButton(),
      ],
    );
  }

  Widget _buildTextBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _sharedTextField(hint: 'Apna jawab likhein...', maxLines: 3)),
        const SizedBox(width: 10),
        _sendButton(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple chat message model
// ─────────────────────────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}