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
      final response = await AiService.chat(
        userMessage: userMessage,
        cohereHistory: _chatHistory.toCohereFormat(),
        userArea: area,
        userLanguage: _lang.isUrdu ? 'urdu' : 'english',
      );

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
      await _chatHistory.addMessage('CHATBOT', "Bhai, thora sa masla aa raha hai. Dubara batayein?");
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _performSearch(Map<String, dynamic> params) async {
    final loc = await LocationService().getCurrentLocation();
    final defaultArea = loc.isSuccess ? loc.data!.city : 'Unknown';
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

    // Matching
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
      surgeMult: _surgeMultiplier,
    );

    if (mounted) {
      setState(() {
        _matches = results;
        if (results.isNotEmpty) _expandedCard = 0;
      });
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

                    // AI Loading Indicator
                    if (_isAILoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: Row(children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary)),
                            SizedBox(width: 12),
                            Text('Agent is thinking...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ]),
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
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
                          child: Text('Best matches for you:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
