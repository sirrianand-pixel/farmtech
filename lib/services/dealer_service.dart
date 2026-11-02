import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/dealer_model.dart';

/// Uses first-party records first, then the server-side Places proxy. The app
/// never receives a Google Maps server key and never calls Places directly.
class DealerService {
  static final DealerService instance = DealerService._();
  DealerService._();

  static const _collection = 'agro_stores';
  static const _defaultEndpoint =
      'https://asia-south1-farmtech-4dcb0.cloudfunctions.net';
  static const _cacheLifetime = Duration(minutes: 5);
  final Map<String, _CachedSearch> _cache = {};

  String get _endpoint {
    const configured = String.fromEnvironment('AGRO_STORE_API_URL');
    return configured.isEmpty
        ? _defaultEndpoint
        : configured.replaceAll(RegExp(r'/+$'), '');
  }

  Future<List<DealerModel>> getDealers({
    required double latitude,
    required double longitude,
    double maxRadiusKm = 15,
    String? preferredDistrict,
  }) async {
    if (maxRadiusKm < 1 || maxRadiusKm > 100) {
      throw ArgumentError.value(maxRadiusKm, 'maxRadiusKm', 'must be 1–100 km');
    }
    final key = '${latitude.toStringAsFixed(2)}:${longitude.toStringAsFixed(2)}:${maxRadiusKm.toInt()}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.createdAt) < _cacheLifetime) {
      return cached.items;
    }

    final verified = await _loadVerifiedRecords(latitude, longitude, maxRadiusKm);
    final discovered = await _searchPlaces(latitude, longitude, maxRadiusKm);
    final merged = _dedupeAndSort([...verified, ...discovered]);
    _cache[key] = _CachedSearch(DateTime.now(), merged);
    return merged;
  }

  Future<List<DealerModel>> _loadVerifiedRecords(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('verification_status', isEqualTo: 'verified')
          .limit(150)
          .get()
          .timeout(const Duration(seconds: 6));
      return snap.docs
          .map((doc) => DealerModel.fromMap(doc.data(), defaultId: doc.id))
          .where((store) => store.latitude != 0 && store.longitude != 0)
          .map((store) => store.copyWith(distanceKm: DealerModel.calculateDistance(
                latitude, longitude, store.latitude, store.longitude)))
          .where((store) => store.distanceKm! <= radiusKm)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DealerModel>> _searchPlaces(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_endpoint/nearbyAgroStores'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'latitude': latitude, 'longitude': longitude, 'radiusKm': radiusKm}),
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['stores'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => DealerModel.fromMap(item.cast<String, dynamic>()))
          .map((store) => store.copyWith(distanceKm: DealerModel.calculateDistance(
                latitude, longitude, store.latitude, store.longitude)))
          .where((store) => store.distanceKm! <= radiusKm)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<DealerModel> _dedupeAndSort(List<DealerModel> stores) {
    final unique = <String, DealerModel>{};
    for (final store in stores) {
      final key = store.id.isNotEmpty
          ? store.id
          : '${store.name.toLowerCase()}-${store.latitude.toStringAsFixed(4)}-${store.longitude.toStringAsFixed(4)}';
      final current = unique[key];
      if (current == null || (!current.isVerified && store.isVerified)) unique[key] = store;
    }
    final items = unique.values.toList()
      ..sort((a, b) => (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    return items;
  }

  /// Fetches contact fields only after a farmer explicitly asks to call.
  Future<DealerModel> loadContactDetails(DealerModel store) async {
    // OpenStreetMap and Firestore stores already contain direct contact/metadata.
    return store;
  }

  Future<bool> callDealer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return false;
    return launchUrl(Uri.parse('tel:$clean'), mode: LaunchMode.externalApplication);
  }

  Future<bool> getDirections(DealerModel store) => launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}&travelmode=driving'),
        mode: LaunchMode.externalApplication,
      );
}

class _CachedSearch {
  final DateTime createdAt;
  final List<DealerModel> items;
  const _CachedSearch(this.createdAt, this.items);
}
