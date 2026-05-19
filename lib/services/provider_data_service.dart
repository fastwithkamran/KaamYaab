import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

    final snapshot =
        await FirebaseFirestore.instance.collection(providersCollection).get();

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

  /// Seeds providers collection from bundled mock JSON dataset.
  Future<void> seedProvidersFromMockAsset() async {
    if (!_isFirebaseReady) return;

    final raw = await rootBundle.loadString('assets/data/providers_mock.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['providers'] as List<dynamic>).cast<Map<String, dynamic>>();

    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection(providersCollection);

    for (final item in list) {
      final provider = ServiceProvider.fromJson(item);
      batch.set(col.doc(provider.id), provider.toJson());
    }

    await batch.commit();
  }
}
