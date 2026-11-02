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

  // A sentinel, never a real district. A denied location must not silently send
  // a farmer to stores in another state.
  static const defaultLocation = UserLocation(
    latitude: 0,
    longitude: 0,
    district: 'Location unavailable',
    state: '',
    isGps: false,
  );

  /// Preset agricultural districts that users can switch between
  static const List<UserLocation> presetDistricts = [
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
      latitude: 16.3067,
      longitude: 80.4365,
      district: 'Guntur',
      state: 'Andhra Pradesh',
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return UserLocation(
          latitude: defaultLocation.latitude,
          longitude: defaultLocation.longitude,
          district: defaultLocation.district,
          state: defaultLocation.state,
          isGps: false,
          errorMessage: 'Location services are disabled. Choose a district to search.',
        );
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
            errorMessage: 'Location permission was denied. Choose a district to search.',
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
          errorMessage: 'Location permission was permanently denied. Choose a district to search.',
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
        // Fallback to last known position
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        return defaultLocation;
      }

      final nearest = findNearestPresetDistrict(pos.latitude, pos.longitude);

      return UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        district: nearest?.district ?? 'Local District',
        state: nearest?.state ?? 'India',
        isGps: true,
      );
    } catch (e) {
      return UserLocation(
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        district: defaultLocation.district,
        state: defaultLocation.state,
        isGps: false,
        errorMessage: 'GPS error: $e',
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
