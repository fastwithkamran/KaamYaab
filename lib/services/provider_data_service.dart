import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/provider_model.dart';

/// Firestore-backed provider data service.
class ProviderDataService {
  ProviderDataService._();
  static final ProviderDataService _instance = ProviderDataService._();
  factory ProviderDataService() => _instance;

  static const String providersCollection = 'providers';

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  Future<List<ServiceProvider>> loadProviders() async {
    if (!_isFirebaseReady) return const [];

    final snapshot = await FirebaseFirestore.instance
        .collection(providersCollection)
        .get();

    final providers = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id']
          : doc.id;
      return ServiceProvider.fromJson(data);
    }).toList();

    providers.sort((a, b) => a.id.compareTo(b.id));
    return providers;
  }

  /// Seeds providers collection from bundled mock JSON asset.
  ///
  /// Guard: checks the live collection count first. If documents already exist
  /// the seed is skipped entirely — this prevents accidental data overwrite on
  /// every app launch / hot restart.
  ///
  /// Pass [force] = true only from a manual admin action when a full re-seed is
  /// intentionally required (e.g. after a schema migration).
  Future<void> seedProvidersFromMockAsset({bool force = false}) async {
    if (!_isFirebaseReady) return;

    // ── Existence guard ────────────────────────────────────────────────────
    if (!force) {
      final existing = await FirebaseFirestore.instance
          .collection(providersCollection)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'ProviderDataService: seed skipped — '
            'collection already contains documents. '
            'Pass force: true to override.',
          );
        }
        return;
      }
    }

    // ── Load asset ────────────────────────────────────────────────────────
    final raw = await rootBundle.loadString('assets/data/providers_mock.json');
    final jsonRoot = jsonDecode(raw);
    if (jsonRoot is! Map<String, dynamic>) {
      throw const FormatException(
          'Invalid providers JSON: top-level object expected.');
    }

    final providersRaw = jsonRoot['providers'];
    if (providersRaw is! List) {
      throw const FormatException(
          'Invalid providers JSON: "providers" list missing.');
    }

    final list = providersRaw.map<Map<String, dynamic>>((e) {
      if (e is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid providers JSON: every provider must be an object.',
        );
      }
      return e;
    }).toList();

    // ── Batch write ───────────────────────────────────────────────────────
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection(providersCollection);

    for (final item in list) {
      final provider = ServiceProvider.fromJson(item);
      batch.set(col.doc(provider.id), provider.toJson());
    }

    try {
      await batch.commit();
      if (kDebugMode) {
        debugPrint(
            'ProviderDataService: seeded ${list.length} providers successfully.');
      }
    } on FirebaseException catch (e) {
      throw Exception(
          'seedProvidersFromMockAsset: Firestore batch failed — ${e.message}');
    }
  }
}