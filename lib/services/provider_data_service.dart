import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

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

}