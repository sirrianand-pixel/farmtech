class AgriculturalProduct {
  final String id;
  final String brand;
  final String productName;
  final String manufacturer;
  final String category;
  final String activeIngredient;
  final String formulation;
  final List<String> applicableCrops;
  final List<String> targetDiseases;
  final String? productImageUrl;
  final String manufacturerUrl;
  final String labelSource;
  final String verificationStatus;
  final String lastVerified;
  final List<String> packSizes;

  const AgriculturalProduct({
    required this.id,
    required this.brand,
    required this.productName,
    required this.manufacturer,
    required this.category,
    required this.activeIngredient,
    required this.formulation,
    required this.applicableCrops,
    required this.targetDiseases,
    required this.productImageUrl,
    required this.manufacturerUrl,
    required this.labelSource,
    required this.verificationStatus,
    required this.lastVerified,
    required this.packSizes,
  });

  factory AgriculturalProduct.fromMap(Map<String, dynamic> data, String id) {
    List<String> strings(String key) => (data[key] as List? ?? const []).map((e) => e.toString()).toList();
    return AgriculturalProduct(
      id: id,
      brand: data['brand']?.toString() ?? '',
      productName: data['product_name']?.toString() ?? '',
      manufacturer: data['manufacturer']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      activeIngredient: data['active_ingredient']?.toString() ?? '',
      formulation: data['formulation']?.toString() ?? '',
      applicableCrops: strings('applicable_crops'),
      targetDiseases: strings('target_diseases'),
      productImageUrl: data['product_image_url']?.toString(),
      manufacturerUrl: data['manufacturer_url']?.toString() ?? '',
      labelSource: data['label_source']?.toString() ?? '',
      verificationStatus: data['verification_status']?.toString() ?? '',
      lastVerified: data['last_verified']?.toString() ?? '',
      packSizes: strings('pack_sizes'),
    );
  }
}
