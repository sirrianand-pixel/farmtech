import 'dart:math' as math;

class DealerModel {
  final String id;
  final String name; // Shop / Store name
  final String proprietorName; // Proprietor name
  final String phone; // Primary contact number
  final String? alternatePhone;
  final String address; // Full address
  final String district;
  final String state;
  final double latitude;
  final double longitude;
  final double? distanceKm; // Distance calculated from user GPS
  final double? rating;
  final String? openHours;
  final List<String> products; // e.g. ["Pesticides", "Fertilizers", "Bio-control", "Seeds"]
  final bool isVerified; // State Agri Dept / CIBRC licensed
  final String? licenseNumber;
  final String source;
  final String verificationStatus;
  final String? lastVerified;

  const DealerModel({
    required this.id,
    required this.name,
    required this.proprietorName,
    required this.phone,
    this.alternatePhone,
    required this.address,
    required this.district,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.rating,
    this.openHours,
    this.products = const [],
    this.isVerified = false,
    this.licenseNumber,
    this.source = 'unknown',
    this.verificationStatus = 'unverified',
    this.lastVerified,
  });

  DealerModel copyWith({
    String? id,
    String? name,
    String? proprietorName,
    String? phone,
    String? alternatePhone,
    String? address,
    String? district,
    String? state,
    double? latitude,
    double? longitude,
    double? distanceKm,
    double? rating,
    String? openHours,
    List<String>? products,
    bool? isVerified,
    String? licenseNumber,
    String? source,
    String? verificationStatus,
    String? lastVerified,
  }) {
    return DealerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      proprietorName: proprietorName ?? this.proprietorName,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      address: address ?? this.address,
      district: district ?? this.district,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating ?? this.rating,
      openHours: openHours ?? this.openHours,
      products: products ?? this.products,
      isVerified: isVerified ?? this.isVerified,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      source: source ?? this.source,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  String get formattedDistance {
    if (distanceKm == null) return '';
    if (distanceKm! < 1.0) {
      return '${(distanceKm! * 1000).round()} m away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'proprietorName': proprietorName,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'address': address,
      'district': district,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'openHours': openHours,
      'products': products,
      'isVerified': isVerified,
      'licenseNumber': licenseNumber,
      'source': source,
      'verification_status': verificationStatus,
      'last_verified': lastVerified,
    };
  }

  factory DealerModel.fromMap(Map<String, dynamic> map, {String? defaultId}) {
    final rawProds = map['products'] ?? map['categories'] ?? [];
    final List<String> prods = rawProds is List
        ? rawProds.map((e) => e.toString()).toList()
        : const [];

    final lat = (map['latitude'] is num)
        ? (map['latitude'] as num).toDouble()
        : (double.tryParse(map['latitude']?.toString() ?? '') ?? 0.0);
    final lng = (map['longitude'] is num)
        ? (map['longitude'] as num).toDouble()
        : (double.tryParse(map['longitude']?.toString() ?? '') ?? 0.0);

    return DealerModel(
      id: map['id']?.toString() ?? defaultId ?? '',
      name: map['name']?.toString() ?? map['shop_name']?.toString() ?? 'Agricultural store',
      proprietorName: map['proprietorName']?.toString() ??
          map['proprietor_name']?.toString() ??
          map['owner']?.toString() ??
          '',
      phone: map['phone']?.toString() ?? map['contact']?.toString() ?? map['nationalPhoneNumber']?.toString() ?? '',
      alternatePhone: map['alternatePhone']?.toString() ?? map['alternate_phone']?.toString(),
      address: map['address']?.toString() ?? map['formattedAddress']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      distanceKm: (map['distanceKm'] is num)
          ? (map['distanceKm'] as num).toDouble()
          : (double.tryParse(map['distanceKm']?.toString() ?? '')),
      rating: (map['rating'] is num)
          ? (map['rating'] as num).toDouble()
          : double.tryParse(map['rating']?.toString() ?? ''),
      openHours: map['openHours']?.toString() ?? map['open_hours']?.toString(),
      products: prods,
      isVerified: map['isVerified'] == true || map['is_verified'] == true || map['verified'] == true,
      licenseNumber: map['licenseNumber']?.toString() ?? map['license_number']?.toString(),
      source: map['source']?.toString() ?? 'unknown',
      verificationStatus: map['verification_status']?.toString() ?? (map['isVerified'] == true ? 'verified' : 'unverified'),
      lastVerified: map['last_verified']?.toString(),
    );
  }

  /// Calculates geodesic distance using the Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);
}
