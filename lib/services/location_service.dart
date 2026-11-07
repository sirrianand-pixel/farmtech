import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final String district;
  final String state;
  final bool isGps;
  final String? errorMessage;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.state,
    this.isGps = true,
    this.errorMessage,
  });

  @override
  String toString() => '$district, $state ($latitude, $longitude)';
}

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  /// Default agricultural hub for AP & TS farming (Kurnool, Andhra Pradesh)
  static const defaultLocation = UserLocation(
    latitude: 15.8281,
    longitude: 78.0373,
    district: 'Kurnool',
    state: 'Andhra Pradesh',
    isGps: false,
  );

  /// Preset agricultural districts that users can switch between
  static const List<UserLocation> presetDistricts = [
    UserLocation(
      latitude: 15.8281,
      longitude: 78.0373,
      district: 'Kurnool',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 14.6819,
      longitude: 77.6006,
      district: 'Anantapur',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 16.3067,
      longitude: 80.4365,
      district: 'Guntur',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 14.4674,
      longitude: 78.8242,
      district: 'Kadapa',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 13.2172,
      longitude: 79.1003,
      district: 'Chittoor',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 16.5062,
      longitude: 80.6480,
      district: 'Krishna / Vijayawada',
      state: 'Andhra Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 17.9689,
      longitude: 79.5941,
      district: 'Warangal',
      state: 'Telangana',
      isGps: false,
    ),
    UserLocation(
      latitude: 17.3850,
      longitude: 78.4867,
      district: 'Hyderabad',
      state: 'Telangana',
      isGps: false,
    ),
    UserLocation(
      latitude: 18.6725,
      longitude: 78.0941,
      district: 'Nizamabad',
      state: 'Telangana',
      isGps: false,
    ),
    UserLocation(
      latitude: 18.4386,
      longitude: 79.1288,
      district: 'Karimnagar',
      state: 'Telangana',
      isGps: false,
    ),
    UserLocation(
      latitude: 17.2473,
      longitude: 80.1514,
      district: 'Khammam',
      state: 'Telangana',
      isGps: false,
    ),
    UserLocation(
      latitude: 18.5204,
      longitude: 73.8567,
      district: 'Pune',
      state: 'Maharashtra',
      isGps: false,
    ),
    UserLocation(
      latitude: 19.9975,
      longitude: 73.7898,
      district: 'Nashik',
      state: 'Maharashtra',
      isGps: false,
    ),
    UserLocation(
      latitude: 30.9010,
      longitude: 75.8573,
      district: 'Ludhiana',
      state: 'Punjab',
      isGps: false,
    ),
    UserLocation(
      latitude: 11.0168,
      longitude: 76.9558,
      district: 'Coimbatore',
      state: 'Tamil Nadu',
      isGps: false,
    ),
    UserLocation(
      latitude: 12.9716,
      longitude: 77.5946,
      district: 'Bengaluru Rural',
      state: 'Karnataka',
      isGps: false,
    ),
    UserLocation(
      latitude: 25.3176,
      longitude: 82.9739,
      district: 'Varanasi',
      state: 'Uttar Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 22.7196,
      longitude: 75.8577,
      district: 'Indore',
      state: 'Madhya Pradesh',
      isGps: false,
    ),
    UserLocation(
      latitude: 21.1702,
      longitude: 72.8311,
      district: 'Surat',
      state: 'Gujarat',
      isGps: false,
    ),
    UserLocation(
      latitude: 29.9695,
      longitude: 76.8783,
      district: 'Karnal',
      state: 'Haryana',
      isGps: false,
    ),
  ];

  /// Request permission and fetch user's GPS coordinates
  Future<UserLocation> getCurrentLocation() async {
    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return UserLocation(
            latitude: defaultLocation.latitude,
            longitude: defaultLocation.longitude,
            district: defaultLocation.district,
            state: defaultLocation.state,
            isGps: false,
            errorMessage: 'Location service disabled. Using ${defaultLocation.district}.',
          );
        }
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return UserLocation(
            latitude: defaultLocation.latitude,
            longitude: defaultLocation.longitude,
            district: defaultLocation.district,
            state: defaultLocation.state,
            isGps: false,
            errorMessage: 'Location permission denied. Using ${defaultLocation.district}.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return UserLocation(
          latitude: defaultLocation.latitude,
          longitude: defaultLocation.longitude,
          district: defaultLocation.district,
          state: defaultLocation.state,
          isGps: false,
          errorMessage: 'Location permission permanently denied. Using ${defaultLocation.district}.',
        );
      }

      // Try fetching current GPS position
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 7),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        return defaultLocation;
      }

      final nearest = findNearestPresetDistrict(pos.latitude, pos.longitude);

      return UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        district: nearest?.district ?? 'Kurnool',
        state: nearest?.state ?? 'Andhra Pradesh',
        isGps: true,
      );
    } catch (_) {
      // Gracefully fall back to Kurnool without throwing MissingPluginException
      return UserLocation(
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        district: defaultLocation.district,
        state: defaultLocation.state,
        isGps: false,
        errorMessage: 'Using default location (${defaultLocation.district}).',
      );
    }
  }

  /// Identifies the nearest agricultural district based on coordinates
  UserLocation? findNearestPresetDistrict(double lat, double lng) {
    UserLocation? closest;
    double minDistance = double.infinity;

    for (final preset in presetDistricts) {
      final dist = Geolocator.distanceBetween(
        lat,
        lng,
        preset.latitude,
        preset.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closest = preset;
      }
    }
    return closest;
  }
}
