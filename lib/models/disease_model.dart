import 'brand_info.dart';

class DiseaseModel {
  final String id;
  final String name;
  final String? scientificName;
  final String crop;
  final String symptoms;
  final String description;
  final String activeIngredient; // CIBRC approved, e.g. "Mancozeb 75% WP"
  final String dosageInfo; // Safe dosage, e.g. "2g per Litre water"
  final String cibrcGuidelines; // Official CIBRC classification & registration notice
  final String icarGuidelines; // ICAR safe application & IPM protocol
  final String? waitingPeriod; // Pre-Harvest Interval (PHI), e.g. "14-21 days"
  final BrandInfo primaryBrand;
  final List<BrandInfo> alternativeBrands;
  final List<String> treatmentSteps;
  final List<String> preventionTips;
  final List<String> fertilizers;
  final String severity; // Mild, Moderate, Severe, Healthy
  final String cause; // Fungal, Bacterial, Viral, Insect Pest, etc.
  final String confidence;
  final String? imageUrl;

  const DiseaseModel({
    required this.id,
    required this.name,
    this.scientificName,
    required this.crop,
    required this.symptoms,
    required this.description,
    required this.activeIngredient,
    required this.dosageInfo,
    required this.cibrcGuidelines,
    required this.icarGuidelines,
    this.waitingPeriod,
    required this.primaryBrand,
    required this.alternativeBrands,
    this.treatmentSteps = const [],
    this.preventionTips = const [],
    this.fertilizers = const [],
    this.severity = 'Moderate',
    this.cause = 'Fungal',
    this.confidence = 'High',
    this.imageUrl,
  });

  bool get isHealthy =>
      name.toLowerCase().contains('health') ||
      severity.toLowerCase().contains('health') ||
      cause.toLowerCase().contains('health');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'scientificName': scientificName,
      'crop': crop,
      'symptoms': symptoms,
      'description': description,
      'activeIngredient': activeIngredient,
      'dosageInfo': dosageInfo,
      'cibrcGuidelines': cibrcGuidelines,
      'icarGuidelines': icarGuidelines,
      'waitingPeriod': waitingPeriod,
      'primaryBrand': primaryBrand.toMap(),
      'alternativeBrands': alternativeBrands.map((b) => b.toMap()).toList(),
      'treatmentSteps': treatmentSteps,
      'preventionTips': preventionTips,
      'fertilizers': fertilizers,
      'severity': severity,
      'cause': cause,
      'confidence': confidence,
      'imageUrl': imageUrl,
    };
  }

  factory DiseaseModel.fromMap(Map<String, dynamic> map, {String? defaultId}) {
    final primaryBrandMap = map['primaryBrand'] is Map<String, dynamic>
        ? map['primaryBrand'] as Map<String, dynamic>
        : (map['primary_brand'] is Map<String, dynamic>
            ? map['primary_brand'] as Map<String, dynamic>
            : null);

    final rawAlternatives = map['alternativeBrands'] ?? map['alternative_brands'] ?? [];
    final List<BrandInfo> alternatives = [];
    if (rawAlternatives is List) {
      for (final item in rawAlternatives) {
        if (item is Map<String, dynamic>) {
          alternatives.add(BrandInfo.fromMap(item));
        } else if (item is Map) {
          alternatives.add(BrandInfo.fromMap(item.cast<String, dynamic>()));
        }
      }
    }

    final rawSteps = map['treatmentSteps'] ?? map['treatment'] ?? [];
    final List<String> steps = rawSteps is List
        ? rawSteps.map((e) => e.toString()).toList()
        : [];

    final rawTips = map['preventionTips'] ?? map['prevention'] ?? [];
    final List<String> tips = rawTips is List
        ? rawTips.map((e) => e.toString()).toList()
        : (rawTips is String && rawTips.isNotEmpty ? [rawTips] : []);

    final rawFertilizers = map['fertilizers'] ?? [];
    final List<String> ferts = rawFertilizers is List
        ? rawFertilizers.map((e) => e.toString()).toList()
        : [];

    return DiseaseModel(
      id: map['id']?.toString() ?? defaultId ?? 'disease_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? map['disease']?.toString() ?? 'Unknown Crop Condition',
      scientificName: map['scientificName']?.toString() ?? map['scientific_name']?.toString(),
      crop: map['crop']?.toString() ?? 'Field Crop',
      symptoms: map['symptoms']?.toString() ?? 'No specific symptoms described.',
      description: map['description']?.toString() ?? map['cause_details']?.toString() ?? map['symptoms']?.toString() ?? '',
      activeIngredient: map['activeIngredient']?.toString() ??
          map['active_ingredient']?.toString() ??
          'CIBRC Approved Technical Fungicide / Bactericide',
      dosageInfo: map['dosageInfo']?.toString() ??
          map['dosage_info']?.toString() ??
          '2 g / Litre of water (ICAR Recommended safe dosage)',
      cibrcGuidelines: map['cibrcGuidelines']?.toString() ??
          map['cibrc_guidelines']?.toString() ??
          'Approved under Section 9(3) of The Insecticides Act, 1968 for labeled crop application.',
      icarGuidelines: map['icarGuidelines']?.toString() ??
          map['icar_guidelines']?.toString() ??
          'Spray in calm morning hours (6-9 AM) or evening. Ensure uniform foliar coverage.',
      waitingPeriod: map['waitingPeriod']?.toString() ?? map['waiting_period']?.toString() ?? '10 - 14 Days (PHI)',
      primaryBrand: primaryBrandMap != null
          ? BrandInfo.fromMap(primaryBrandMap)
          : const BrandInfo(
              name: 'Recommended ICAR/CIBRC Formulation',
              manufacturer: 'Licensed Agro-chemical Manufacturer',
            ),
      alternativeBrands: alternatives,
      treatmentSteps: steps,
      preventionTips: tips,
      fertilizers: ferts,
      severity: map['severity']?.toString() ?? 'Moderate',
      cause: map['cause']?.toString() ?? 'Fungal',
      confidence: map['confidence']?.toString() ?? 'High',
      imageUrl: map['imageUrl']?.toString() ?? map['image_url']?.toString(),
    );
  }
}
