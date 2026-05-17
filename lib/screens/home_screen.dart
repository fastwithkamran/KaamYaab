import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/agent_model.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/language_service.dart';
import '../widgets/provider_card.dart';
import '../widgets/surge_alert_card.dart';
import '../widgets/shimmer_card.dart';
import 'booking_flow_screen.dart';
import 'voice_booking_agent.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  final _lang = LanguageService();

  bool _isSearching = false;
  bool _showSurge = false;
  bool _showShimmer = false;
  List<AgentStep> _agentSteps = [];
  List<ProviderMatch> _matches = [];
  int _expandedCard = -1;
  ServiceRequest? _currentRequest;

  double _surgeMultiplier = 1.6;
  int _surgeRequests = 7;

  late AnimationController _fabCtrl;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fabAnim = CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _showClarificationDialog(String question) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Row(children: [
          Text('🧠 ', style: TextStyle(fontSize: 20)),
          Text('Need Clarification',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ]),
        content: Text(question,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppTheme.tealPrimary)),
          ),
        ],
      ),
    );
  }

  void _openBooking(ProviderMatch match, double finalPrice, String? note) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => BookingFlowScreen(
          match: match,
          request: _currentRequest!,
          surgeMultiplier: _surgeMultiplier,
          negotiatedPrice: finalPrice,
          negotiationNote: note,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _clearSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _matches = [];
      _agentSteps.clear();
      _showSurge = false;
      _currentRequest = null;
      _expandedCard = -1;
    });
    _fabCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      floatingActionButton: ScaleTransition(
        scale: _fabAnim,
        child: FloatingActionButton.extended(
          onPressed: _clearSearch,
          backgroundColor: AppTheme.tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('New Search', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              // — App Bar —————————————————————————————————————————————————
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTheme.timeGreeting(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.primaryGradient.createShader(bounds),
                            child: const Text(
                              'KaamYaab',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Language toggle EN / اردو
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await _lang.setUrdu(!_lang.isUrdu);
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                            borderRadius: AppTheme.radiusMd,
                            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Text('EN', style: TextStyle(color: !_lang.isUrdu ? AppTheme.tealPrimary : AppTheme.textMuted, fontWeight: !_lang.isUrdu ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('|', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
                              Text('UR', style: TextStyle(color: _lang.isUrdu ? AppTheme.tealPrimary : AppTheme.textMuted, fontWeight: _lang.isUrdu ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // AI status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.agentGradient,
                          borderRadius: AppTheme.radiusMd,
                        ),
                        child: const Row(children: [
                          Text('🤖', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text('AI Active',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),

              // Hero: Voice AI CTA
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lang.isUrdu ? 'آپ کو کیا چاہیے؟' : 'What do you need?',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lang.isUrdu
                            ? 'آواز سے بکنگ کریں — AI آپ کا بہترین کارکن تلاش کرے گا'
                            : 'Hire instantly — AI finds your perfect worker',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      // Main Voice AI button
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VoiceBookingAgent())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppTheme.purpleAgent.withValues(alpha: 0.35),
                              AppTheme.blueInfo.withValues(alpha: 0.2),
                            ]),
                            borderRadius: AppTheme.radiusLg,
                            border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.purpleAgent.withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.purpleAgent.withValues(alpha: 0.3),
                                  border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.5)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_search_rounded, size: 28, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lang.isUrdu ? 'آواز سے بکنگ کریں' : 'Hire a Pro',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _lang.isUrdu
                                          ? 'بولیں — AI سمجھے گا'
                                          : 'Tap and speak your need',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.purpleAgent.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
              ),

              // ── Surge Alert ─────────────────────────────────────────────
              if (_showSurge)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: SurgeAlertCard(
                      area: _currentRequest?.area ?? 'G-13',
                      service: _currentRequest?.serviceType ?? 'Service',
                      multiplier: _surgeMultiplier,
                      activeRequests: _surgeRequests,
                      availableProviders: 3,
                      onBookNow: () {
                        if (_matches.isNotEmpty) _openBooking(_matches.first, _matches.first.quotePkr, null);
                      },
                      onDismiss: () => setState(() => _showSurge = false),
                    ),
                  ),
                ),

              // — Shimmer loading ————————————————————————————————————————
              if (_showShimmer)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: const ShimmerSearchState(),
                  ),
                ),

              // — Results Header —————————————————————————————————————————
              if (_matches.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Ranked Matches',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            borderRadius: AppTheme.radiusSm,
                          ),
                          child: Text(
                            '${_matches.length} providers',
                            style: const TextStyle(
                              color: AppTheme.tealPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Row(children: [
                          Text('DNA ranked', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          SizedBox(width: 3),
                          Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 14),
                        ]),
                      ],
                    ),
                  ),
                ),

              // — Provider Cards —————————————————————————————————————————
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final match = _matches[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ProviderCard(
                        match: match,
                        rank: i + 1,
                        isExpanded: _expandedCard == i,
                        serviceType: _currentRequest?.serviceType ?? 'Unknown',
                        surgeMultiplier: _surgeMultiplier,
                        onTap: () => setState(
                            () => _expandedCard = _expandedCard == i ? -1 : i),
                        onBook: (finalPrice, note) => _openBooking(match, finalPrice, note),
                      ),
                    );
                  },
                  childCount: _matches.length,
                ),
              ),

              // — Empty state ————————————————————————————————————————————
              if (_matches.isEmpty && !_isSearching && _agentSteps.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.tealPrimary.withValues(alpha: 0.08),
                            border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.15)),
                          ),
                          child: const Center(
                            child: Icon(Icons.search_rounded, size: 36, color: AppTheme.tealPrimary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Describe your service need',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Urdu, Roman Urdu ya English mein\nlikhein — AI samjhega',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Service Chip ──────────────────────────────────────────────────────────
class _QuickChip extends StatefulWidget {
  final String label;
  final int index;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.index, required this.onTap});

  static const _icons = {
    'AC Repair': 'AC',
    'Plumbing': '🔧',
    'Electrical': '⚡',
    'Tutoring': '📚',
    'Cleaning': '🧹',
  };

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.tealPrimary.withValues(alpha: 0.15)
              : AppTheme.cardDark,
          borderRadius: AppTheme.radiusMd,
          border: Border.all(
            color: _pressed
                ? AppTheme.tealPrimary.withValues(alpha: 0.4)
                : AppTheme.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_QuickChip._icons[widget.label] ?? '🔨',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: _pressed ? AppTheme.tealPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: _pressed ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: widget.index * 60))
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.1),
    );
  }
}

// ── Browse Workers Banner ────────────────────────────────────────────────────
class _BrowseWorkersBanner extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback onVoiceBook;
  final void Function(String category) onCategoryTap;

  const _BrowseWorkersBanner({
    required this.onBrowse,
    required this.onVoiceBook,
    required this.onCategoryTap,
  });

  static const _cats = [
    ('🔧', 'Plumber'),
    ('⚡', 'Electrician'),
    ('❄️', 'AC Technician'),
    ('🪚', 'Carpenter'),
    ('🎨', 'Painter'),
    ('🧹', 'Cleaner'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(children: [
          const Text('👷 Browse Workers',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onBrowse,
            child: const Text('See All →',
                style: TextStyle(color: AppTheme.tealPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Tap a category or browse all professionals',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 14),

        // Category tiles row
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _cats.asMap().entries.map((e) {
              final idx = e.key;
              final emoji = e.value.$1;
              final cat = e.value.$2;
              return GestureDetector(
                onTap: () => onCategoryTap(cat),
                child: Container(
                  width: 78,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 5),
                    Text(cat, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        textAlign: TextAlign.center, maxLines: 2),
                  ]),
                ).animate()
                  .fadeIn(delay: Duration(milliseconds: idx * 60), duration: 300.ms)
                  .slideY(begin: 0.1),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Voice booking CTA
        GestureDetector(
          onTap: onVoiceBook,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.purpleAgent.withValues(alpha: 0.2),
                AppTheme.blueInfo.withValues(alpha: 0.1),
              ]),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.purpleAgent.withValues(alpha: 0.35)),
            ),
            child: const Row(children: [
              Text('🎙️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hire a Pro', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Let our assistant find the perfect worker for you', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              Icon(Icons.chevron_right, color: AppTheme.purpleAgent, size: 20),
            ]),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ),
      ],
    );
  }
}
