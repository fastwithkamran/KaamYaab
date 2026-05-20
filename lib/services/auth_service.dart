import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/runtime_config.dart';

/// Auth service — uses SharedPreferences as a local store for Hackathon Pitch.
class AuthService {
  static const _usersKey = 'kaamyaab_users';
  static const _currentUserKey = 'kaamyaab_current_user';
  static const _bannedKey = 'kaamyaab_banned';

  // ── Singleton ─────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  // Named getter required by main.dart: AuthService.instance.init()
  static AuthService get instance => _instance;
  AuthService._();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Returns true if the current user is the Super Admin.
  bool get isAdmin =>
      _currentUser != null &&
      _currentUser!.phone == RuntimeConfig.superAdminPhone;

  // ── Initialise (call in main) ─────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_currentUserKey);
    if (json != null) {
      try {
        _currentUser =
            AppUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (_) {
        await prefs.remove(_currentUserKey);
      }
    }
  }

  Future<AuthResult> register(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);

    if (allUsers.any((u) => u.phone == user.phone)) {
      return AuthResult.error('This phone number is already registered.');
    }

    final newUser = user.copyWith(
      isAvailable: true,
      rating: 0.0,
      totalJobs: 0,
    );

    allUsers.add(newUser);
    await _saveAllUsers(prefs, allUsers);

    _currentUser = newUser;
    await prefs.setString(_currentUserKey, jsonEncode(newUser.toJson()));
    return AuthResult.success(newUser);
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<AuthResult> login(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);

    final matched = allUsers.where((u) => u.phone == phone).toList();
    if (matched.isEmpty) {
      return AuthResult.error('No account found with this phone number.');
    }

    final user = matched.first;
    final banned = await _loadBannedUids(prefs);
    if (banned.contains(user.uid)) {
      return AuthResult.error('Your account has been suspended.');
    }

    _currentUser = user;
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    return AuthResult.success(user);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    _currentUser = null;
  }

  Future<void> signOut() => logout();

  // ── Worker lookup (phone validation for booking) ───────────────────────────
  Future<AppUser?> findWorkerByPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    try {
      return allUsers.firstWhere((u) => u.phone == phone && u.isWorker);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isWorkerPhoneRegistered(String phone) async {
    final worker = await findWorkerByPhone(phone);
    return worker != null;
  }

  Future<bool> isPhoneRegistered(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    return allUsers.any((u) => u.phone == phone);
  }

  // ── All users (for admin panel) ───────────────────────────────────────────
  Future<List<AppUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadAllUsers(prefs);
  }

  Future<List<AppUser>> getAllWorkers({String? city, String? category}) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    return allUsers.where((u) {
      if (!u.isWorker) return false;
      if (city != null && u.city != city) return false;
      if (category != null && category != 'All' && u.serviceCategory != category) return false;
      return true;
    }).toList();
  }

  // ── Worker availability ───────────────────────────────────────────────────
  Future<void> setWorkerAvailability(bool available) async {
    if (_currentUser == null || !_currentUser!.isWorker) return;
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx >= 0) {
      allUsers[idx] = allUsers[idx].copyWith(isAvailable: available);
      _currentUser = allUsers[idx];
      await _saveAllUsers(prefs, allUsers);
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  Future<void> updateWorkerService(String category, List<String> skills) async {
    if (_currentUser == null || !_currentUser!.isWorker) return;
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx >= 0) {
      allUsers[idx] = allUsers[idx].copyWith(serviceCategory: category, skills: skills);
      _currentUser = allUsers[idx];
      await _saveAllUsers(prefs, allUsers);
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  Future<void> setAvailabilityRules(List<String> rules) async {
    if (_currentUser == null || !_currentUser!.isWorker) return;
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx >= 0) {
      allUsers[idx] = allUsers[idx].copyWith(availabilityRules: rules);
      _currentUser = allUsers[idx];
      await _saveAllUsers(prefs, allUsers);
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  // ── Admin: Ban / Unban / Delete ───────────────────────────────────────────
  Future<void> banUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final banned = await _loadBannedUids(prefs);
    if (!banned.contains(uid)) {
      banned.add(uid);
      await prefs.setString(_bannedKey, jsonEncode(banned));
    }
  }

  Future<void> unbanUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final banned = await _loadBannedUids(prefs);
    banned.remove(uid);
    await prefs.setString(_bannedKey, jsonEncode(banned));
  }

  Future<bool> isUserBanned(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final banned = await _loadBannedUids(prefs);
    return banned.contains(uid);
  }

  Future<List<String>> getBannedUids() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadBannedUids(prefs);
  }

  Future<void> deleteUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final updated = allUsers.where((u) => u.uid != uid).toList();
    await _saveAllUsers(prefs, updated);
    await unbanUser(uid);
  }

  // ── Hackathon Seeding Logic ───────────────────────────────────────────────
  Future<void> seedDemoData() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadAllUsers(prefs);
    
    // Remove old demos if any, so we start fresh
    existing.removeWhere((u) => u.uid.startsWith('demo_'));

    final demos = [
      AppUser(uid: 'demo_plumber_1', name: 'Tariq Mehmood', phone: '03001234501',
        cnic: '1111111111111', city: 'Lahore', area: 'DHA Phase 5', role: UserRole.worker,
        createdAt: DateTime.now(), serviceCategory: 'Plumber',
        subRole: 'Emergency Plumber', skills: ['Pipe Fitting', 'Leak Repair', 'Bathroom Fitting'],
        baseRatePkr: 600, experienceYears: 8, isAvailable: true, rating: 4.8, totalJobs: 312,
        bio: '8 years experience in all types of plumbing. Available 24/7 for emergencies.'),
      AppUser(uid: 'demo_elec_1', name: 'Asif Raza', phone: '03001234502',
        cnic: '2222222222222', city: 'Karachi', area: 'Gulshan', role: UserRole.worker,
        createdAt: DateTime.now(), serviceCategory: 'Electrician',
        subRole: 'Solar Installer', skills: ['Solar Panels', 'Inverter/UPS', 'Wiring', 'CCTV'],
        baseRatePkr: 800, experienceYears: 6, isAvailable: true, rating: 4.6, totalJobs: 187,
        bio: 'Expert in solar installation and power backup systems. Government certified.'),
      AppUser(uid: 'demo_ac_1', name: 'Usman Ali', phone: '03001234503',
        cnic: '3333333333333', city: 'Karachi', area: 'DHA', role: UserRole.worker,
        createdAt: DateTime.now(), serviceCategory: 'AC Technician',
        subRole: 'Split AC Specialist', skills: ['AC Installation', 'Gas Filling', 'AC Service', 'Compressor Repair'],
        baseRatePkr: 1200, experienceYears: 5, isAvailable: true, rating: 4.9, totalJobs: 428,
        bio: 'Top-rated AC technician in Karachi. Same-day service available.'),
      AppUser(uid: 'demo_carp_1', name: 'Nadeem Akhtar', phone: '03001234504',
        cnic: '4444444444444', city: 'Lahore', area: 'Johar Town', role: UserRole.worker,
        createdAt: DateTime.now(), serviceCategory: 'Carpenter',
        subRole: 'Furniture Maker', skills: ['Furniture Repair', 'Kitchen Cabinets', 'Custom Work', 'Polishing'],
        baseRatePkr: 700, experienceYears: 12, isAvailable: false, rating: 4.7, totalJobs: 503,
        bio: 'Master carpenter with 12 years specializing in custom furniture and kitchen design.'),
      AppUser(uid: 'demo_paint_1', name: 'Kamran Shah', phone: '03001234505',
        cnic: '5555555555555', city: 'Karachi', area: 'DHA', role: UserRole.worker,
        createdAt: DateTime.now(), serviceCategory: 'Painter',
        subRole: 'Texture Paint Expert', skills: ['Interior', 'Texture Paint', 'Waterproofing', 'Wood Polish'],
        baseRatePkr: 500, experienceYears: 7, isAvailable: true, rating: 4.5, totalJobs: 241,
        bio: 'Specializes in premium texture finishes and waterproofing. Own equipment.'),
    ];

    existing.addAll(demos);
    await _saveAllUsers(prefs, existing);
    // Note: plaintext password storage removed (was security anti-pattern).
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<List<AppUser>> _loadAllUsers(SharedPreferences prefs) async {
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadBannedUids(SharedPreferences prefs) async {
    final raw = prefs.getString(_bannedKey);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAllUsers(SharedPreferences prefs, List<AppUser> users) async {
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
  }
}

class AuthResult {
  final AppUser? user;
  final String? errorMessage;
  bool get isSuccess => user != null;

  const AuthResult._({this.user, this.errorMessage});
  factory AuthResult.success(AppUser user) => AuthResult._(user: user);
  factory AuthResult.error(String msg) => AuthResult._(errorMessage: msg);
}