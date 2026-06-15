import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/language_service.dart';
import '../services/chat_history_service.dart';
import '../services/location_service.dart';
import '../widgets/provider_card.dart';
import '../widgets/surge_alert_card.dart';
import 'booking_flow_screen.dart';
import 'voice_booking_agent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _chatCtrl = TextEditingController();
  final FocusNode _chatFocus = FocusNode();
  final _lang = LanguageService();
  final _chatHistory = ChatHistoryService();

  bool _isAILoading = false;
  List<ProviderMatch> _matches = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;

  double _surgeMultiplier = 1.0;
  int _surgeRequests = 0;
  bool _showSurge = false;

  @override
  void initState() {
    super.initState();
    LocationService().getCurrentLocation();
    _chatHistory.init().then((_) {
      if (mounted) {
        if (_chatHistory.history.isEmpty) {
          _chatHistory.addMessage('CHATBOT', _lang.isUrdu 
              ? 'سلام! میں آپ کا کامیاب اسسٹنٹ ہوں۔ میں آپ کے لیے پلمبر، الیکٹریشن یا کوئی بھی دوسرا کارکن ڈھونڈ سکتا ہوں۔ بتائیں، میں آپ کی کیا مدد کر سکتا ہوں؟'
              : 'Salam! I\'m your KaamYaab assistant. I can help you find a plumber, electrician, or any other worker. How can I help you today?');
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _chatCtrl.dispose();
    _chatFocus.dispose();
    super.dispose();
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

  /// Safely parses the AI response map — never throws, always returns valid strings.
  Map<String, dynamic> _parseResponse(Map<String, dynamic> response) {
    // Layer 1: direct key access with null-safe fallbacks
    String reply = '';
    String action = 'CHAT';
    Map<String, dynamic>? searchParams;

    try {
      final rawReply = response['reply'];
      final rawAction = response['action'];

      if (rawReply is String && rawReply.isNotEmpty) {
        reply = rawReply;
      } else if (rawReply != null) {
        reply = rawReply.toString();
      }

      if (rawAction is String && rawAction.isNotEmpty) {
        action = rawAction.toUpperCase();
      } else if (rawAction != null) {
        action = rawAction.toString().toUpperCase();
      }

      final rawParams = response['search_params'];
      if (rawParams is Map<String, dynamic>) {
        searchParams = rawParams;
      } else if (rawParams is Map) {
        searchParams = Map<String, dynamic>.from(rawParams);
      }
    } catch (e) {
      debugPrint('Response parse error: $e');
    }

    // Final fallback if reply is still empty
    if (reply.isEmpty) {
      reply = _lang.isUrdu
          ? 'Maafi chahta hoon, mujhe samajh nahi aaya. Dobara poochein?'
          : 'Sorry, I did not understand that. Could you rephrase?';
    }

    return {'reply': reply, 'action': action, 'search_params': searchParams};
  }

  Future<void> _handleChat(String input) async {
    if (input.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    final userMessage = input.trim();
    _chatCtrl.clear();
    _chatFocus.unfocus();

    await _chatHistory.addMessage('USER', userMessage);
    setState(() => _isAILoading = true);
    _scrollToBottom();

    try {
      final loc = await LocationService().getCurrentLocation();
      final defaultArea = loc.isSuccess ? loc.data!.city : 'Unknown';
      final area = _currentRequest?.area ?? defaultArea;
      final rawResponse = await AiService.chat(
        userMessage: userMessage,
        cohereHistory: _chatHistory.toCohereFormat(),
        userArea: area,
        userLanguage: _lang.isUrdu ? 'urdu' : 'english',
      );

      // ✅ Safe parsing — never throws on malformed Cohere response
      final response = _parseResponse(rawResponse);
      final reply = response['reply'] as String;
      final action = response['action'] as String;
      final searchParams = response['search_params'] as Map<String, dynamic>?;

      await _chatHistory.addMessage('CHATBOT', reply);
      _scrollToBottom();

      if (action == 'SEARCH' && searchParams != null) {
        await _performSearch(searchParams);
      }
    } catch (e) {
      debugPrint('Chat Error: $e');
      await _chatHistory.addMessage('CHATBOT',
          _lang.isUrdu
              ? 'Bhai, thora sa masla aa raha hai. Dubara batayein?'
              : 'Sorry, something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _performSearch(Map<String, dynamic> params) async {
    // Single location fetch — result is cached for 5 min so calling it twice
    // was wasteful. Use this one result for both the area label and coordinates.
    final locResult = await LocationService().getCurrentLocation();
    final defaultArea = locResult.isSuccess ? locResult.data!.city : 'Unknown';
    final service = params['service'] as String? ?? 'General';
    final area = params['area'] as String? ?? defaultArea;
    final urgency = params['urgency'] as String? ?? 'medium';

    setState(() {
      _matches = [];
      _showSurge = false;
    });

    // Create a temporary request object for the matching service
    _currentRequest = ServiceRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      rawInput: "Search for $service in $area",
      serviceType: service,
      location: defaultArea,
      area: area,
      urgency: urgency,
      preferredTime: 'flexible',
      preferredDate: 'today',
      budgetSensitivity: 0.5,
      confidence: 1.0,
      language: 'mixed',
      createdAt: DateTime.now(),
      status: 'pending',
    );

    // Dynamic surge
    if (urgency == 'emergency' || urgency == 'high') {
      _surgeMultiplier = urgency == 'emergency' ? 1.8 : 1.4;
      _surgeRequests = urgency == 'emergency' ? 12 : 5;
      _showSurge = true;
      HapticFeedback.heavyImpact();
    } else {
      _surgeMultiplier = 1.0;
    }

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
      surgeMult: _surgeMultiplier,
    );

    if (mounted) {
      setState(() {
        _matches = results;
        if (results.isNotEmpty) _expandedCard = 0;
      });

      // ── No worker found: inform user via chat ────────────────────────────
      if (results.isEmpty) {
        final service = _currentRequest?.serviceType ?? 'this service';
        final area = _currentRequest?.area ?? 'your area';
        _chatHistory.addMessage(
          'CHATBOT',
          _lang.isUrdu
              ? '❌ معذرت! "$service" کے لیے "$area" میں ابھی کوئی کارکن دستیاب نہیں ہے۔ براہ کرم علاقہ تبدیل کریں یا بعد میں دوبارہ کوشش کریں۔'
              : '❌ No workers found for "$service" in "$area" right now. Try a different area, broaden your service type, or check back later.',
        );
        setState(() {});
      }

      _scrollToBottom();
    }
  }

  void _openBooking(ProviderMatch match, double finalPrice, String? note) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          match: match,
          request: _currentRequest!,
          surgeMultiplier: _surgeMultiplier,
          negotiatedPrice: finalPrice,
          negotiationNote: note,
        ),
      ),
    );
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
              // --- Custom App Bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTheme.timeGreeting(),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        ShaderMask(
                          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                          child: const Text(
                            'KaamYaab',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Language toggle
                    GestureDetector(
                      onTap: () async {
                        await _lang.setUrdu(!_lang.isUrdu);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radiusMd,
                          border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.5)),
                        ),
                        child: Text(_lang.isUrdu ? 'English' : 'اردو', style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Main Chat & Results Scroll Area ---
              Expanded(
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    // Chat Bubbles
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final msg = _chatHistory.history[i];
                            final isUser = msg['role'] == 'USER';
                            return _ChatBubble(message: msg['message']!, isUser: isUser);
                          },
                          childCount: _chatHistory.history.length,
                        ),
                      ),
                    ),

                    // AI Agentic Loading Phases
                    if (_isAILoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: _AgentSearchingWidget(),
                        ),
                      ),

                    // Surge Alert
                    if (_showSurge && _matches.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        sliver: SliverToBoxAdapter(
                          child: SurgeAlertCard(
                            area: _currentRequest?.area ?? 'G-13',
                            service: _currentRequest?.serviceType ?? 'Service',
                            multiplier: _surgeMultiplier,
                            activeRequests: _surgeRequests,
                            availableProviders: _matches.length,
                            onBookNow: () => _openBooking(_matches.first, _matches.first.quotePkr, null),
                            onDismiss: () => setState(() => _showSurge = false),
                          ),
                        ),
                      ),

                    // Search Results
                    if (_matches.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: _WorkersFoundBanner(
                            count: _matches.length,
                            serviceType: _currentRequest?.serviceType ?? 'Service',
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final match = _matches[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: ProviderCard(
                                match: match,
                                rank: i + 1,
                                isExpanded: _expandedCard == i,
                                serviceType: _currentRequest?.serviceType ?? 'Unknown',
                                surgeMultiplier: _surgeMultiplier,
                                onTap: () => setState(() => _expandedCard = _expandedCard == i ? -1 : i),
                                onBook: (price, note) => _openBooking(match, price, note),
                              ),
                            );
                          },
                          childCount: _matches.length,
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),

              // --- Persistent Chat Input Bar ---
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: AppTheme.tealPrimary),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceBookingAgent())),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _chatCtrl,
                          focusNode: _chatFocus,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _lang.isUrdu ? 'یہاں لکھیں...' : 'Type here...',
                            hintStyle: const TextStyle(color: AppTheme.textMuted),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _handleChat,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _handleChat(_chatCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.tealPrimary),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _AgentSearchingWidget — animated cycling phase display during AI search
// ─────────────────────────────────────────────────────────────────────────────
class _AgentSearchingWidget extends StatefulWidget {
  const _AgentSearchingWidget();
  @override
  State<_AgentSearchingWidget> createState() => _AgentSearchingWidgetState();
}

class _AgentSearchingWidgetState extends State<_AgentSearchingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phaseIndex = 0;
  static const _phases = [
    ('🔍', 'Scanning nearby workers...'),
    ('⚡', 'Matching by skill & rating...'),
    ('📊', 'Ranking by DNA Score...'),
    ('✅', 'Verifying availability...'),
  ];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _phaseIndex = (_phaseIndex + 1) % _phases.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phases[_phaseIndex];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(
            color: AppTheme.tealPrimary.withValues(alpha: 0.2 + 0.15 * _ctrl.value),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.tealPrimary.withValues(alpha: 0.06 * _ctrl.value),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.tealPrimary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.tealPrimary.withValues(alpha: 0.3 + 0.2 * _ctrl.value),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(phase.$1, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  phase.$2,
                  key: ValueKey(_phaseIndex),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 3),
              const Text('KaamYaab Agent is working...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.tealPrimary.withValues(alpha: 0.7),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkersFoundBanner — animated teal reveal card after AI finds workers
// ─────────────────────────────────────────────────────────────────────────────
class _WorkersFoundBanner extends StatelessWidget {
  final int count;
  final String serviceType;
  const _WorkersFoundBanner({required this.count, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.tealPrimary.withValues(alpha: 0.18),
            AppTheme.tealDark.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tealPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
          ),
          child: const Center(child: Text('🎯', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: '$count ',
                    style: const TextStyle(color: AppTheme.tealPrimary),
                  ),
                  const TextSpan(
                    text: 'verified workers found',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'AI ranked best $serviceType specialists near you',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.tealPrimary.withValues(alpha: 0.2),
            borderRadius: AppTheme.radiusSm,
            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.tealPrimary, size: 12),
            SizedBox(width: 4),
            Text('AI', style: TextStyle(
                color: AppTheme.tealPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }
}


class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  const _ChatBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) const Padding(padding: EdgeInsets.only(right: 8), child: Text('🤖', style: TextStyle(fontSize: 16))),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.tealPrimary.withValues(alpha: 0.15) : AppTheme.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
                border: Border.all(color: (isUser ? AppTheme.tealPrimary : Colors.white).withValues(alpha: 0.1)),
              ),
              child: Text(message, style: TextStyle(color: isUser ? Colors.white : AppTheme.textSecondary, fontSize: 14, height: 1.4)),
            ),
          ),
          if (isUser) const Padding(padding: EdgeInsets.only(left: 8), child: CircleAvatar(radius: 12, backgroundColor: AppTheme.tealPrimary, child: Icon(Icons.person, size: 14, color: Colors.white))),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: isUser ? 0.05 : -0.05);
  }
}