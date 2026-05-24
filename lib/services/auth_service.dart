import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Auth service — Firestore is the source of truth.
/// SharedPreferences is a local cache for offline / fast startup only.
class AuthService {
  static const _usersKey = 'kaamyaab_users';
  static const _currentUserKey = 'kaamyaab_current_user';
  static const _bannedKey = 'kaamyaab_banned';

  // ── Singleton ─────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;
  AuthService._();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ── Firestore helper ──────────────────────────────────────────────────────
  static bool get _hasFirestore => Firebase.apps.isNotEmpty;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users');

  // ── Initialise ────────────────────────────────────────────────────────────
  /// Loads the session from SharedPreferences, then silently syncs from
  /// Firestore so local cache always reflects the latest server data.
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

    // Silently re-sync from Firestore so local cache is always fresh.
    if (_currentUser != null && _hasFirestore) {
      try {
        final doc = await _col.doc(_currentUser!.uid).get();
        if (doc.exists) {
          final fresh = AppUser.fromJson(doc.data()!);
          _currentUser = fresh;
          await prefs.setString(_currentUserKey, jsonEncode(fresh.toJson()));
          // Also update the users list cache
          final allUsers = await _loadAllUsers(prefs);
          final idx = allUsers.indexWhere((u) => u.uid == fresh.uid);
          if (idx >= 0) {
            allUsers[idx] = fresh;
          } else {
            allUsers.add(fresh);
          }
          await _saveAllUsers(prefs, allUsers);
        }
      } catch (e) {
        // Non-fatal — local cache is still usable
        debugPrint('AuthService.init: Firestore sync failed — $e');
      }
    }
  }

  // ── Get user by phone ─────────────────────────────────────────────────────
  /// Queries Firestore first (authoritative), falls back to local cache.
  /// This ensures users who cleared app data but still have a Firestore
  /// document are found correctly.
  Future<AppUser?> getUserByPhone(String phone) async {
    // 1. Try Firestore first (source of truth)
    if (_hasFirestore) {
      try {
        final query = await _col
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final fetchedUser = AppUser.fromJson(query.docs.first.data());
          // Update local cache
          final prefs = await SharedPreferences.getInstance();
          final allUsers = await _loadAllUsers(prefs);
          final idx = allUsers.indexWhere((u) => u.uid == fetchedUser.uid);
          if (idx >= 0) {
            allUsers[idx] = fetchedUser;
          } else {
            allUsers.add(fetchedUser);
          }
          await _saveAllUsers(prefs, allUsers);
          return fetchedUser;
        }
      } catch (e) {
        debugPrint('AuthService.getUserByPhone: Firestore error — $e');
      }
    }

    // 2. Fall back to local cache (offline mode)
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final localMatch = allUsers.where((u) => u.phone == phone).toList();
    return localMatch.isNotEmpty ? localMatch.first : null;
  }

  // ── Register ──────────────────────────────────────────────────────────────
  /// Registers a new user. Writes to Firestore first (required), then caches
  /// locally. Returns an error if Firestore write fails so the user knows
  /// their account was not created.
  Future<AuthResult> register(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();

    // Check for duplicate (Firestore first)
    final existing = await getUserByPhone(user.phone);
    if (existing != null) {
      return AuthResult.error('This phone number is already registered.');
    }

    final uid = user.uid.isEmpty
        ? 'USR-${DateTime.now().millisecondsSinceEpoch}'
        : user.uid;
    final newUser = user.copyWith(
      uid: uid,
      isAvailable: true,
      rating: 0.0,
      totalJobs: 0,
    );

    // 1. Write to Firestore (mandatory — this is the source of truth)
    if (_hasFirestore) {
      try {
        await _col.doc(newUser.uid).set(newUser.toJson());
        debugPrint('AuthService.register: user written to Firestore — ${newUser.uid}');
      } catch (e) {
        debugPrint('AuthService.register: Firestore write FAILED — $e');
        return AuthResult.error(
          'Could not save your account. Please check your internet connection and try again.',
        );
      }
    }

    // 2. Cache locally
    final allUsers = await _loadAllUsers(prefs);
    allUsers.add(newUser);
    await _saveAllUsers(prefs, allUsers);

    _currentUser = newUser;
    await prefs.setString(_currentUserKey, jsonEncode(newUser.toJson()));
    return AuthResult.success(newUser);
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  /// Phone-based login. OTP verification is handled upstream.
  /// Queries Firestore first to get the latest user data, then caches locally.
  Future<AuthResult> login(String phone) async {
    final prefs = await SharedPreferences.getInstance();

    // Look up user — Firestore first (handles cleared-data case)
    final user = await getUserByPhone(phone);

    if (user == null) {
      return AuthResult.error('No account found with this phone number.');
    }

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

  // ── Refresh current user from Firestore ───────────────────────────────────
  /// Re-fetches the signed-in user's document from Firestore and updates both
  /// in-memory state and SharedPreferences. Call after login or profile update.
  Future<void> refreshUserFromFirestore() async {
    if (_currentUser == null || !_hasFirestore) return;
    try {
      final doc = await _col.doc(_currentUser!.uid).get();
      if (doc.exists) {
        final fresh = AppUser.fromJson(doc.data()!);
        _currentUser = fresh;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, jsonEncode(fresh.toJson()));

        final allUsers = await _loadAllUsers(prefs);
        final idx = allUsers.indexWhere((u) => u.uid == fresh.uid);
        if (idx >= 0) {
          allUsers[idx] = fresh;
        } else {
          allUsers.add(fresh);
        }
        await _saveAllUsers(prefs, allUsers);
        debugPrint('AuthService.refreshUserFromFirestore: synced ${fresh.uid}');
      }
    } catch (e) {
      debugPrint('AuthService.refreshUserFromFirestore: failed — $e');
    }
  }

  // ── Refresh (local only) ──────────────────────────────────────────────────
  /// Re-reads the current user from local SharedPreferences cache.
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    // Prefer Firestore refresh if available
    if (_hasFirestore) {
      await refreshUserFromFirestore();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final updated = allUsers.where((u) => u.uid == _currentUser!.uid).toList();
    if (updated.isNotEmpty) {
      _currentUser = updated.first;
    }
  }

  // ── Worker rating ─────────────────────────────────────────────────────────
  Future<void> updateWorkerRating({
    required String workerUid,
    required double newRating,
    required int newTotalJobs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == workerUid);
    if (idx < 0) return;
    allUsers[idx] = allUsers[idx].copyWith(
      rating: newRating,
      totalJobs: newTotalJobs,
    );
    await _saveAllUsers(prefs, allUsers);

    if (_hasFirestore) {
      try {
        await _col.doc(workerUid).update({
          'rating': newRating,
          'total_jobs': newTotalJobs,
        });
      } catch (_) {}
    }

    if (_currentUser?.uid == workerUid) {
      _currentUser = allUsers[idx];
      await prefs.setString(
          _currentUserKey, jsonEncode(allUsers[idx].toJson()));
    }
  }

  // ── Worker lookup ─────────────────────────────────────────────────────────
  Future<AppUser?> findWorkerByPhone(String phone) async {
    // Try Firestore first
    if (_hasFirestore) {
      try {
        final query = await _col
            .where('phone', isEqualTo: phone)
            .where('role', isEqualTo: 'worker')
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return AppUser.fromJson(query.docs.first.data());
        }
      } catch (_) {}
    }
    // Local fallback
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
    final user = await getUserByPhone(phone);
    return user != null;
  }

  // ── All users ─────────────────────────────────────────────────────────────
  Future<List<AppUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadAllUsers(prefs);
  }

  Future<List<AppUser>> getAllWorkers({String? city, String? category}) async {
    // Try Firestore for live worker data
    if (_hasFirestore) {
      try {
        Query<Map<String, dynamic>> query =
            _col.where('role', isEqualTo: 'worker');
        if (city != null && city.isNotEmpty) {
          query = query.where('city', isEqualTo: city);
        }
        if (category != null && category != 'All' && category.isNotEmpty) {
          query = query.where('service_category', isEqualTo: category);
        }
        final snap = await query.get();
        if (snap.docs.isNotEmpty) {
          final workers =
              snap.docs.map((d) => AppUser.fromJson(d.data())).toList();
          // Update local cache with fetched workers
          final prefs = await SharedPreferences.getInstance();
          final allUsers = await _loadAllUsers(prefs);
          for (final w in workers) {
            final idx = allUsers.indexWhere((u) => u.uid == w.uid);
            if (idx >= 0) {
              allUsers[idx] = w;
            } else {
              allUsers.add(w);
            }
          }
          await _saveAllUsers(prefs, allUsers);
          return workers;
        }
      } catch (e) {
        debugPrint('AuthService.getAllWorkers: Firestore error — $e');
      }
    }

    // Fall back to local cache
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    return allUsers.where((u) {
      if (!u.isWorker) {
        return false;
      }
      if (city != null && u.city != city) {
        return false;
      }
      if (category != null &&
          category != 'All' &&
          u.serviceCategory != category) {
        return false;
      }
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

      if (_hasFirestore) {
        try {
          await _col
              .doc(_currentUser!.uid)
              .update({'is_available': available});
        } catch (_) {}
      }
    }
  }

  Future<void> updateWorkerService(
      String category, List<String> skills) async {
    if (_currentUser == null || !_currentUser!.isWorker) return;
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx >= 0) {
      allUsers[idx] =
          allUsers[idx].copyWith(serviceCategory: category, skills: skills);
      _currentUser = allUsers[idx];
      await _saveAllUsers(prefs, allUsers);
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toJson()));

      if (_hasFirestore) {
        try {
          await _col.doc(_currentUser!.uid).update({
            'service_category': category,
            'skills': skills,
          });
        } catch (_) {}
      }
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

      if (_hasFirestore) {
        try {
          await _col
              .doc(_currentUser!.uid)
              .update({'availability_rules': rules});
        } catch (_) {}
      }
    }
  }

  // ── Update profile ────────────────────────────────────────────────────────
  /// Updates the user profile in Firestore first, then syncs to local cache.
  Future<void> updateUserProfile(AppUser updatedUser) async {
    // 1. Firestore first
    if (_hasFirestore) {
      try {
        await _col.doc(updatedUser.uid).set(updatedUser.toJson());
        debugPrint(
            'AuthService.updateUserProfile: Firestore updated — ${updatedUser.uid}');
      } catch (e) {
        debugPrint('AuthService.updateUserProfile: Firestore error — $e');
        // Continue to update local cache even if Firestore fails
      }
    }

    // 2. Update local cache
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await _loadAllUsers(prefs);
    final idx = allUsers.indexWhere((u) => u.uid == updatedUser.uid);
    if (idx >= 0) {
      allUsers[idx] = updatedUser;
      await _saveAllUsers(prefs, allUsers);
    } else {
      allUsers.add(updatedUser);
      await _saveAllUsers(prefs, allUsers);
    }

    if (_currentUser?.uid == updatedUser.uid) {
      _currentUser = updatedUser;
      await prefs.setString(_currentUserKey, jsonEncode(updatedUser.toJson()));
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
    if (_hasFirestore) {
      try {
        await _col.doc(uid).update({'is_banned': true});
      } catch (_) {}
    }
  }

  Future<void> unbanUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final banned = await _loadBannedUids(prefs);
    banned.remove(uid);
    await prefs.setString(_bannedKey, jsonEncode(banned));
    if (_hasFirestore) {
      try {
        await _col.doc(uid).update({'is_banned': false});
      } catch (_) {}
    }
  }

  Future<bool> isUserBanned(String uid) async {
    // Check Firestore first for ban status
    if (_hasFirestore) {
      try {
        final doc = await _col.doc(uid).get();
        if (doc.exists) {
          return doc.data()?['is_banned'] == true;
        }
      } catch (_) {}
    }
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
    if (_currentUser?.uid == uid) {
      await prefs.remove(_currentUserKey);
      _currentUser = null;
    }

    if (_hasFirestore) {
      try {
        await _col.doc(uid).delete();
      } catch (_) {}
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<List<AppUser>> _loadAllUsers(SharedPreferences prefs) async {
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList();
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

  Future<void> _saveAllUsers(
      SharedPreferences prefs, List<AppUser> users) async {
    await prefs.setString(
        _usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
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