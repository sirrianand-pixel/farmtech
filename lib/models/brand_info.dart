class BrandInfo {
  final String name;
  final String manufacturer;
  final String? formulation;
  final String? packageSize;
  final String? approximatePrice;
  final String? imageUrl;
  final String? notes;

  const BrandInfo({
    required this.name,
    required this.manufacturer,
    this.formulation,
    this.packageSize,
    this.approximatePrice,
    this.imageUrl,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'manufacturer': manufacturer,
      'formulation': formulation,
      'packageSize': packageSize,
      'approximatePrice': approximatePrice,
      'imageUrl': imageUrl,
      'notes': notes,
    };
  }

  factory BrandInfo.fromMap(Map<String, dynamic> map) {
    return BrandInfo(
      name: map['name']?.toString() ?? '',
      manufacturer: map['manufacturer']?.toString() ?? 'Generic / Multi-manufacturer',
      formulation: map['formulation']?.toString(),
      packageSize: map['packageSize']?.toString() ?? map['package_size']?.toString(),
      approximatePrice: map['approximatePrice']?.toString() ?? map['approx_price']?.toString(),
      imageUrl: map['imageUrl']?.toString() ?? map['image_url']?.toString(),
      notes: map['notes']?.toString(),
    );
  }

  @override
  String toString() => '$name ($manufacturer)';
}
