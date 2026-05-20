import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/language_service.dart';
import '../services/chat_history_service.dart';
import '../services/location_service.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../widgets/provider_card.dart';
import 'booking_flow_screen.dart';

class VoiceBookingAgent extends StatefulWidget {
  final String? initialService;
  const VoiceBookingAgent({super.key, this.initialService});

  @override
  State<VoiceBookingAgent> createState() => _VoiceBookingAgentState();
}

class _VoiceBookingAgentState extends State<VoiceBookingAgent> with TickerProviderStateMixin {
  late FlutterTts _tts;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _chatHistory = ChatHistoryService();
  
  late AnimationController _pulseCtrl;

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _speaking = false;
  bool _isListening = false;
  bool _isAILoading = false;
  List<ProviderMatch> _matches = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;

  @override
  void initState() {
    super.initState();
    LocationService().getCurrentLocation();
    _chatHistory.init();
    if (widget.initialService != null) {
      _inputCtrl.text = widget.initialService!;
    }

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initTts();
    _initSpeech();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() { if (mounted) setState(() => _speaking = true); });
    _tts.setCompletionHandler(() { if (mounted) setState(() => _speaking = false); });
    _tts.setCancelHandler(() { if (mounted) setState(() => _speaking = false); });
    
    final isUrdu = LanguageService().isUrdu;
    final welcome = isUrdu 
        ? 'Salam! Main aapki kia madad kar sakta hoon?' 
        : 'Salam! How can I help you today?';
    await _tts.speak(welcome);
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() { _inputCtrl.text = val.recognizedWords; });
            if (val.finalResult) {
              setState(() => _isListening = false);
              _submit();
            }
          },
          localeId: LanguageService().isUrdu ? 'ur_PK' : 'en_US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _submit() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
    await _tts.stop();

    setState(() => _isAILoading = true);
    await _chatHistory.addMessage('USER', input);
    
    try {
      final loc = await LocationService().getCurrentLocation();
      final defaultArea = loc.isSuccess ? loc.data!.city : 'Unknown';
      final response = await AiService.chat(
        userMessage: input,
        cohereHistory: _chatHistory.toCohereFormat(),
        userArea: _currentRequest?.area ?? defaultArea,
        userLanguage: LanguageService().isUrdu ? 'urdu' : 'english',
      );

      final reply = response['reply'] as String;
      final action = response['action'] as String;
      final searchParams = response['search_params'] as Map<String, dynamic>?;

      await _chatHistory.addMessage('CHATBOT', reply);
      await _tts.speak(reply);

      if (action == 'SEARCH' && searchParams != null) {
        await _performSearch(searchParams);
      }
    } catch (e) {
      debugPrint('Voice Chat Error: $e');
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _performSearch(Map<String, dynamic> params) async {
    final loc = await LocationService().getCurrentLocation();
    final defaultArea = loc.isSuccess ? loc.data!.city : 'Unknown';
    final service = params['service'] as String? ?? 'General';
    final area = params['area'] as String? ?? defaultArea;
    
    _currentRequest = ServiceRequest(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      rawInput: "Voice search for $service",
      serviceType: service,
      location: defaultArea,
      area: area,
      urgency: params['urgency'] ?? 'medium',
      preferredTime: 'flexible',
      preferredDate: 'today',
      budgetSensitivity: 0.5,
      confidence: 1.0,
      language: 'mixed',
      createdAt: DateTime.now(),
      status: 'pending',
    );

    final locResult = await LocationService().getCurrentLocation();
    if (!locResult.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your live location is not enabled. Please enable it to continue.'),
            backgroundColor: AppTheme.redAlert,
          ),
        );
      }
      return;
    }
    
    final userLat = locResult.data!.latitude;
    final userLng = locResult.data!.longitude;

    final results = await MatchingService.matchProviders(
      request: _currentRequest!,
      userLat: userLat,
      userLng: userLng,
      surgeMult: 1.0,
    );

    if (mounted) {
      setState(() {
        _matches = results;
        if (results.isNotEmpty) _expandedCard = 0;
      });
      if (results.isNotEmpty) {
        final resText = LanguageService().isUrdu 
            ? "Bhai, mujhe aap ke liye behtreen workers mil gaye hain. Neeche check karein."
            : "Bhai, I found the best workers for you. Check them out below.";
        await _tts.speak(resText);
      }
    }
  }

  void _openBooking(ProviderMatch match, double finalPrice, String? note) {
    _tts.stop();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingFlowScreen(
        match: match,
        request: _currentRequest!,
        surgeMultiplier: 1.0,
        negotiatedPrice: finalPrice,
        negotiationNote: note,
      ),
    ));
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _pulseCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = LanguageService().isUrdu;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isUrdu ? 'کامیاب آواز' : 'KaamYaab Voice', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Visualizer
                    GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, _) => Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening 
                                ? AppTheme.redAlert.withValues(alpha: 0.1) 
                                : (_speaking ? AppTheme.tealPrimary.withValues(alpha: 0.2) : AppTheme.tealPrimary.withValues(alpha: 0.1)),
                            border: Border.all(
                              color: _isListening ? AppTheme.redAlert : AppTheme.tealPrimary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? AppTheme.redAlert : AppTheme.tealPrimary).withValues(alpha: 0.3 * _pulseCtrl.value),
                                blurRadius: 30,
                                spreadRadius: 10 * _pulseCtrl.value,
                              )
                            ],
                          ),
                          child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _isListening ? (isUrdu ? 'Main sun raha hoon...' : 'Listening...') : (isUrdu ? 'Bolne ke liye tap karein' : 'Tap to speak'),
                      style: TextStyle(color: _isListening ? AppTheme.redAlert : AppTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 40),
                    
                    // Transcript
                    if (_inputCtrl.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _inputCtrl.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 30),
                    if (_isAILoading)
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary)),
                        SizedBox(width: 12),
                        Text('Bhai soch raha hai...', style: TextStyle(color: AppTheme.textMuted)),
                      ]),

                    // Results
                    if (_matches.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: Colors.white12),
                      ),
                      ..._matches.asMap().entries.map((e) => ProviderCard(
                        match: e.value, rank: e.key + 1, isExpanded: _expandedCard == e.key,
                        serviceType: _currentRequest?.serviceType ?? 'Unknown',
                        surgeMultiplier: 1.0,
                        onTap: () => setState(() => _expandedCard = _expandedCard == e.key ? -1 : e.key),
                        onBook: (p, n) => _openBooking(e.value, p, n),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            
            // Manual Input Fallback
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: isUrdu ? 'Ya yahan likhein...' : 'Or type here...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.tealPrimary),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
