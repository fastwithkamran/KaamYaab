import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

enum AgentInputMode { voice, text }

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
  bool _speechAvailable = false;

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

  void _sendAgentGreeting() {
    final user = AuthService().currentUser;
    final name = user?.name?.split(' ').first ?? 'there';
    final rules = user?.availabilityRules ?? [];

    String greeting;
    if (rules.isEmpty) {
      greeting = "Salam $name! 👋 I'm your KaamYaab Agent. Tell me when you're available — "
          "for example: 'Monday to Friday, 9 AM to 5 PM' or 'Sundays are off'.";
    } else {
      greeting = "Welcome back $name! Your current availability:\n"
          "${rules.map((r) => '  ✓ $r').join('\n')}\n\n"
          "Want to update your schedule? Just tell me the changes.";
    }

    _addAgentMessage(greeting);

    if (_currentMode == AgentInputMode.voice) {
      _speak(greeting);
    }
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );
    if (mounted) {
      setState(() {
        _speechAvailable = available;
        if (!available && _currentMode == AgentInputMode.voice) {
          _currentMode = AgentInputMode.text;
        }
      });
    }
  }

  void _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.5);
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

  // ── Voice Input ─────────────────────────────────────────────────────────────
  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isListening = true;
          _voiceText = '';
        });
        _micPulseCtrl.repeat(reverse: true);
        _speech.listen(
          onResult: (val) => setState(() {
            _voiceText = val.recognizedWords;
          }),
        );
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _isListening = false);
      _micPulseCtrl.stop();
      _micPulseCtrl.reset();
      _speech.stop();
      if (_voiceText.isNotEmpty) {
        _processInput(_voiceText);
      }
    }
  }

  // ── Text Input ──────────────────────────────────────────────────────────────
  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _textController.clear();
    _processInput(text);
  }

  // ── Process Input (shared) ──────────────────────────────────────────────────
  Future<void> _processInput(String userInput) async {
    if (userInput.isEmpty) return;

    _addUserMessage(userInput);
    setState(() => _isProcessing = true);

    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final updatedRules = await GeminiService.processWorkerSettings(
          userInput,
          user.availabilityRules ?? [],
        );

        await AuthService().setAvailabilityRules(updatedRules);

        // Auto-detect and save location
        await _saveWorkerLocation();

        final rulesDisplay = updatedRules.map((r) => '  ✓ $r').join('\n');
        final response = "Got it! ✅ I've updated your availability:\n\n"
            "$rulesDisplay\n\n"
            "Customers looking for a ${user.serviceCategory ?? 'technician'} "
            "near you will now see you as available. Want to make any other changes?";

        _addAgentMessage(response);
        if (_currentMode == AgentInputMode.voice) {
          _speak("Got it! I've updated your availability. Customers near you will now see you as available.");
        }
      } catch (e) {
        _addAgentMessage("Sorry, I had trouble processing that. Could you try again? 🤔");
        if (_currentMode == AgentInputMode.voice) {
          _speak("Sorry, I had trouble processing that. Could you try again?");
        }
      }
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _saveWorkerLocation() async {
    try {
      final locResult = await LocationService().getCurrentLocation();
      if (locResult.isSuccess && locResult.data != null) {
        final user = AuthService().currentUser;
        if (user != null) {
          // Save location to LocationService cache for matching engine
          await LocationService().saveUserLocation(user.uid, locResult.data!);
        }
      }
    } catch (_) {
      // Location is optional — don't fail the availability update
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _micPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title + Mode Toggle ───────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.agentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'KaamYaab Agent',
                  style: TextStyle(
                    color: AppTheme.purpleLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeTab(Icons.mic_rounded, AgentInputMode.voice),
                    _modeTab(Icons.chat_rounded, AgentInputMode.text),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Chat Log ──────────────────────────────────────────
          Flexible(
            child: Container(
              constraints: const BoxConstraints(minHeight: 200, maxHeight: 350),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: AppTheme.radiusMd,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatLog.length + (_isProcessing ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatLog.length && _isProcessing) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_chatLog[index]);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Voice status ──────────────────────────────────────
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.purpleAgent.withValues(alpha: 0.12),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _micPulseCtrl,
                    builder: (_, __) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.redAlert.withValues(alpha: 0.5 + 0.5 * _micPulseCtrl.value),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _voiceText.isEmpty ? 'Listening... speak now' : _voiceText,
                      style: TextStyle(
                        color: _voiceText.isEmpty ? AppTheme.textMuted : Colors.white,
                        fontSize: 13,
                        fontStyle: _voiceText.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Input Area ────────────────────────────────────────
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _modeTab(IconData icon, AgentInputMode mode) {
    final isActive = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        if (!_speechAvailable && mode == AgentInputMode.voice) return;
        HapticFeedback.selectionClick();
        setState(() => _currentMode = mode);
        if (mode == AgentInputMode.text) {
          _focusNode.requestFocus();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.purpleAgent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: AppTheme.radiusSm,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppTheme.purpleLight : AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: msg.isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isAgent) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.agentGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13))),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isAgent
                    ? AppTheme.purpleAgent.withValues(alpha: 0.15)
                    : AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(msg.isAgent ? 4 : 14),
                  bottomRight: Radius.circular(msg.isAgent ? 14 : 4),
                ),
                border: Border.all(
                  color: msg.isAgent
                      ? AppTheme.purpleAgent.withValues(alpha: 0.2)
                      : AppTheme.tealPrimary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
            ),
          ),
          if (!msg.isAgent) const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.agentGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.purpleAgent.withValues(alpha: 0.15),
              borderRadius: AppTheme.radiusMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (_, val, child) {
                    return Opacity(
                      opacity: 0.3 + 0.7 * ((val + i / 3) % 1.0),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      color: AppTheme.purpleLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    if (_currentMode == AgentInputMode.voice) {
      return Column(
        children: [
          GestureDetector(
            onTap: _isProcessing ? null : _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppTheme.redAlert : AppTheme.purpleAgent,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppTheme.redAlert : AppTheme.purpleAgent)
                        .withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening ? 'Tap to stop' : 'Tap to speak',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      );
    }

    // Text input mode
    return Row(
      children: [
        // Mic button (secondary)
        if (_speechAvailable)
          GestureDetector(
            onTap: () {
              setState(() => _currentMode = AgentInputMode.voice);
              _toggleListening();
            },
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAgent.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.mic_rounded, color: AppTheme.purpleLight, size: 20),
            ),
          ),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
              decoration: InputDecoration(
                hintText: 'e.g. "Mon-Fri, 9 AM to 5 PM"',
                hintStyle: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send button
        GestureDetector(
          onTap: _isProcessing ? null : _sendTextMessage,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: _isProcessing ? null : AppTheme.primaryGradient,
              color: _isProcessing ? AppTheme.textMuted.withValues(alpha: 0.2) : null,
              shape: BoxShape.circle,
              boxShadow: _isProcessing ? [] : AppTheme.tealGlow,
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppTheme.tealPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAgent;
  const _ChatMessage({required this.text, required this.isAgent});
}
