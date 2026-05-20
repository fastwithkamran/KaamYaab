import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/mock_data.dart';
import 'worker_detail_screen.dart';

class WorkersBrowseScreen extends StatefulWidget {
  final String? initialCategory;
  const WorkersBrowseScreen({super.key, this.initialCategory});

  @override
  State<WorkersBrowseScreen> createState() => _WorkersBrowseScreenState();
}

class _WorkersBrowseScreenState extends State<WorkersBrowseScreen> {
  List<AppUser> _allWorkers = [];
  List<AppUser> _filtered = [];
  bool _loading = true;
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'rating'; // 'rating' | 'price_low' | 'price_high' | 'jobs'
  bool _availableOnly = false;

  // Mock section filter
  String _mockCategory = 'All';
  static const _mockCategories = ['All', 'Plumbing', 'Electrical', 'AC Repair', 'Cleaning', 'Carpentry'];

  List<MockWorker> get _filteredMock {
    if (_mockCategory == 'All') return mockWorkersList;
    return mockWorkersList.where((w) => w.category == _mockCategory).toList();
  }

  static const _categories = [
    'All', 'Plumber', 'Electrician', 'AC Technician', 'Carpenter',
    'Painter', 'Cleaner', 'Driver', 'Security Guard', 'Cook', 'Mason',
  ];

  static const _categoryIcons = {
    'All': '🔍',
    'Plumber': '🔧',
    'Electrician': '⚡',
    'AC Technician': '❄️',
    'Carpenter': '🪚',
    'Painter': '🎨',
    'Cleaner': '🧹',
    'Driver': '🚗',
    'Security Guard': '🛡️',
    'Cook': '👨‍🍳',
    'Mason': '🧱',
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _loading = true);
    final workers = await AuthService().getAllWorkers();
    if (!mounted) return;
    setState(() {
      _allWorkers = workers;
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    var result = List<AppUser>.from(_allWorkers);

    // Category filter
    if (_selectedCategory != null && _selectedCategory != 'All') {
      result = result.where((w) => w.serviceCategory == _selectedCategory).toList();
    }

    // Availability filter
    if (_availableOnly) {
      result = result.where((w) => w.isAvailable).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((w) =>
        w.name.toLowerCase().contains(q) ||
        (w.serviceCategory?.toLowerCase().contains(q) ?? false) ||
        (w.subRole?.toLowerCase().contains(q) ?? false) ||
        (w.skills?.any((s) => s.toLowerCase().contains(q)) ?? false) ||
        w.city.toLowerCase().contains(q)
      ).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
      case 'price_low':
        result.sort((a, b) => (a.baseRatePkr ?? 0).compareTo(b.baseRatePkr ?? 0));
      case 'price_high':
        result.sort((a, b) => (b.baseRatePkr ?? 0).compareTo(a.baseRatePkr ?? 0));
      case 'jobs':
        result.sort((a, b) => b.totalJobs.compareTo(a.totalJobs));
    }

    setState(() => _filtered = result);
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
              _buildCategoryBar(),
              _buildSortAndFilter(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary))
                    : CustomScrollView(
                        slivers: [
                          // ── Live registered workers grid ──
                          if (_filtered.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _WorkerCard(
                                    worker: _filtered[i],
                                    index: i,
                                    onTap: () => _openWorker(_filtered[i]),
                                  ),
                                  childCount: _filtered.length,
                                ),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.68,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(child: _buildEmpty()),

                          // ── Mock Workers Section ──
                          SliverToBoxAdapter(child: _buildMockSection()),

                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header with search ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Browse Workers', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('Find trusted professionals near you', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
            ),
            IconButton(
              onPressed: _loadWorkers,
              icon: const Icon(Icons.refresh, color: AppTheme.tealPrimary, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          // Search bar
          TextField(
            onChanged: (v) { _searchQuery = v; _applyFilters(); },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, skill, city...',
              hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(borderRadius: AppTheme.radiusMd, borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Horizontal category chips ─────────────────────────────────────────────
  Widget _buildCategoryBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () { setState(() => _selectedCategory = cat); _applyFilters(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.tealPrimary : Colors.white.withValues(alpha: 0.07),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: selected ? AppTheme.tealPrimary : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_categoryIcons[cat] ?? '🔧', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(cat, style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Sort and availability toggle ──────────────────────────────────────────
  Widget _buildSortAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Text('${_filtered.length} workers found',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const Spacer(),
        // Available toggle
        GestureDetector(
          onTap: () { setState(() => _availableOnly = !_availableOnly); _applyFilters(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _availableOnly ? AppTheme.greenSuccess.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: AppTheme.radiusSm,
              border: Border.all(
                color: _availableOnly ? AppTheme.greenSuccess : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(
                color: _availableOnly ? AppTheme.greenSuccess : AppTheme.textMuted,
                shape: BoxShape.circle,
              )),
              const SizedBox(width: 5),
              Text('Available', style: TextStyle(
                color: _availableOnly ? AppTheme.greenSuccess : AppTheme.textMuted, fontSize: 11,
              )),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // Sort dropdown
        PopupMenuButton<String>(
          color: AppTheme.cardDark,
          onSelected: (v) { setState(() => _sortBy = v); _applyFilters(); },
          itemBuilder: (_) => [
            _menuItem('rating', '⭐ Top Rated'),
            _menuItem('jobs', '💼 Most Jobs'),
            _menuItem('price_low', '💰 Price: Low→High'),
            _menuItem('price_high', '💰 Price: High→Low'),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: AppTheme.radiusSm,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sort, color: AppTheme.textMuted, size: 14),
              SizedBox(width: 4),
              Text('Sort', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label) =>
      PopupMenuItem(value: value, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)));

  // ── Mock Workers Section ─────────────────────────────────────────────────
  Widget _buildMockSection() {
    final mocks = _filteredMock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.radiusSm,
                ),
                child: const Text('📍 KARACHI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Demo Service Providers', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('50 pre-loaded workers — zero network latency', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ]),
              ),
              Text('${mocks.length} found', style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _mockCategories[i];
              final sel = _mockCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _mockCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.tealPrimary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(
                      color: sel ? AppTheme.tealPrimary : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(cat, style: TextStyle(
                    color: sel ? AppTheme.tealPrimary : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  )),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Mock workers list
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: mocks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _WorkerCard(
                worker: AppUser(
                  uid: mocks[i].id,
                  name: mocks[i].providerName,
                  phone: '',
                  cnic: '',
                  city: 'Karachi',
                  area: mocks[i].location,
                  role: UserRole.worker,
                  createdAt: DateTime.now(),
                  serviceCategory: mocks[i].category,
                  subRole: mocks[i].title,
                  baseRatePkr: mocks[i].price.toDouble(),
                  isAvailable: mocks[i].isAvailable,
                  rating: mocks[i].rating,
                ),
                index: i,
                onTap: () {},
              )
              .animate()
              .fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms)
              .slideX(begin: 0.05),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔍', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text('No workers found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Try changing your filters or search term',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        TextButton(onPressed: () { setState(() { _selectedCategory = 'All'; _searchQuery = ''; _availableOnly = false; }); _applyFilters(); },
            child: const Text('Clear Filters', style: TextStyle(color: AppTheme.tealPrimary))),
      ]),
    );
  }

  void _openWorker(AppUser worker) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkerDetailScreen(worker: worker),
    ));
  }
}

// ── Worker card ──────────────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  final AppUser worker;
  final int index;
  final VoidCallback onTap;
  const _WorkerCard({required this.worker, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image / avatar area
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  _buildProfileImage(),
                  // Availability badge
                  Positioned(top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: worker.isAvailable
                            ? AppTheme.greenSuccess.withValues(alpha: 0.9)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(worker.isAvailable ? '● Online' : '● Offline',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  // Rating badge
                  Positioned(bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star, color: AppTheme.goldAccent, size: 12),
                        const SizedBox(width: 3),
                        Text(worker.rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(worker.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(worker.subRole ?? worker.serviceCategory ?? '',
                      style: const TextStyle(color: AppTheme.tealPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on, color: AppTheme.textMuted, size: 11),
                    const SizedBox(width: 2),
                    Expanded(child: Text('${worker.area}, ${worker.city}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const Spacer(),
                  Row(children: [
                    Text(worker.rateDisplay,
                        style: const TextStyle(color: AppTheme.goldAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${worker.totalJobs} jobs',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: index * 50), duration: 350.ms)
           .slideY(begin: 0.1, duration: 350.ms),
    );
  }

  Widget _buildProfileImage() {
    if (worker.hasProfileImage) {
      try {
        final bytes = base64Decode(worker.profileImageBase64!);
        return Image.memory(bytes, height: 130, width: double.infinity, fit: BoxFit.cover);
      } catch (_) {}
    }
    // Gradient avatar fallback
    final colors = _avatarColors[worker.serviceCategory] ?? [AppTheme.tealDark, AppTheme.tealPrimary];
    return Container(
      height: 130, width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_categoryEmoji[worker.serviceCategory] ?? '👷', style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 4),
          Text(worker.name.split(' ').map((e) => e[0]).take(2).join(),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  static const _categoryEmoji = {
    'Plumber': '🔧', 'Electrician': '⚡', 'AC Technician': '❄️',
    'Carpenter': '🪚', 'Painter': '🎨', 'Cleaner': '🧹',
    'Driver': '🚗', 'Security Guard': '🛡️', 'Cook': '👨‍🍳', 'Mason': '🧱',
  };

  static final _avatarColors = {
    'Plumber': [const Color(0xFF1E3A5F), const Color(0xFF3B82F6)],
    'Electrician': [const Color(0xFF4A1E0A), const Color(0xFFF59E0B)],
    'AC Technician': [const Color(0xFF0A3A4A), const Color(0xFF00BFA5)],
    'Carpenter': [const Color(0xFF3A2A0A), const Color(0xFFB45309)],
    'Painter': [const Color(0xFF2A0A3A), const Color(0xFF8B5CF6)],
    'Cleaner': [const Color(0xFF0A3A1E), const Color(0xFF22C55E)],
    'Driver': [const Color(0xFF1A1A3A), const Color(0xFF6366F1)],
    'Security Guard': [const Color(0xFF3A0A0A), const Color(0xFFEF4444)],
  };
}
