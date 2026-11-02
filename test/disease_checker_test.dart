import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farmtech/models/brand_info.dart';
import 'package:farmtech/models/disease_model.dart';
import 'package:farmtech/models/dealer_model.dart';
import 'package:farmtech/services/disease_service.dart';
import 'package:farmtech/widgets/brand_recommendation_card.dart';
import 'package:farmtech/widgets/disease_treatment_view.dart';

void main() {
  group('Disease Checker Data Models', () {
    test('BrandInfo model serialization and deserialization', () {
      const brand = BrandInfo(
        name: 'Dithane M-45',
        manufacturer: 'Indofil Industries',
        formulation: '75% WP',
        packageSize: '1kg',
        approximatePrice: '₹350 / kg',
        notes: 'Protective Mancozeb fungicide',
      );

      final map = brand.toMap();
      expect(map['name'], 'Dithane M-45');
      expect(map['manufacturer'], 'Indofil Industries');
      expect(map['formulation'], '75% WP');

      final reconstructed = BrandInfo.fromMap(map);
      expect(reconstructed.name, brand.name);
      expect(reconstructed.manufacturer, brand.manufacturer);
      expect(reconstructed.approximatePrice, brand.approximatePrice);
    });

    test('DiseaseModel serialization and CIBRC / ICAR guidelines', () {
      final disease = DiseaseModel(
        id: 'test_disease',
        name: 'Early Blight',
        crop: 'Tomato',
        symptoms: 'Concentric ring spots on leaves',
        description: 'Fungal infection caused by Alternaria solani',
        activeIngredient: 'Mancozeb 75% WP',
        dosageInfo: '2g per Litre of water',
        cibrcGuidelines: 'Approved under Section 9(3) of Insecticides Act',
        icarGuidelines: 'Spray during morning hours',
        waitingPeriod: '7-10 Days PHI',
        primaryBrand: const BrandInfo(
          name: 'Dithane M-45',
          manufacturer: 'Indofil',
        ),
        alternativeBrands: const [
          BrandInfo(name: 'Indofil M-45', manufacturer: 'Indofil'),
          BrandInfo(name: 'Saaf', manufacturer: 'UPL'),
          BrandInfo(name: 'Kavach', manufacturer: 'Syngenta'),
        ],
        treatmentSteps: ['Spray Mancozeb @ 2g/L', 'Prune lower leaves'],
        fertilizers: ['Calcium Nitrate @ 5g/L'],
        severity: 'Moderate',
        cause: 'Fungal',
      );

      expect(disease.isHealthy, false);
      expect(disease.activeIngredient, 'Mancozeb 75% WP');
      expect(disease.dosageInfo, '2g per Litre of water');
      expect(disease.primaryBrand.name, 'Dithane M-45');
      expect(disease.alternativeBrands.length, 3);

      final map = disease.toMap();
      final reconstructed = DiseaseModel.fromMap(map);
      expect(reconstructed.id, 'test_disease');
      expect(reconstructed.name, 'Early Blight');
      expect(reconstructed.alternativeBrands.length, 3);
      expect(reconstructed.alternativeBrands[1].name, 'Saaf');
    });

    test('DealerModel calculates accurate Haversine geodesic distance', () {
      // Pune Market Yard coordinates (18.4965, 73.8687)
      // Saswad coordinates (~18.3444, 74.0305) -> distance is approx 24-25 km
      final dist = DealerModel.calculateDistance(18.4965, 73.8687, 18.3444, 74.0305);
      expect(dist, greaterThan(20.0));
      expect(dist, lessThan(30.0));

      const dealer = DealerModel(
        id: 'dealer_1',
        name: 'Kisan Krishi Kendra',
        proprietorName: 'Rameshwar Patil',
        phone: '+919822014589',
        address: 'APMC Market Yard',
        district: 'Pune',
        state: 'Maharashtra',
        latitude: 18.4965,
        longitude: 73.8687,
        distanceKm: 2.34,
      );

      expect(dealer.formattedDistance, '2.3 km away');

      final closeDealer = dealer.copyWith(distanceKm: 0.65);
      expect(closeDealer.formattedDistance, '650 m away');
    });
  });

  group('DiseaseService Repository', () {
    test('Contains ICAR / CIBRC approved crop diseases with brand recommendations', () {
      final service = DiseaseService.instance;
      final diseases = service.getAllDiseases();

      expect(diseases.length, greaterThanOrEqualTo(8));

      // Check Tomato Early Blight
      final tomato = service.findDiseaseById('tomato_early_blight');
      expect(tomato, isNotNull);
      expect(tomato!.crop, 'Tomato');
      expect(tomato.activeIngredient.contains('Mancozeb'), true);
      expect(tomato.primaryBrand.name, contains('Dithane'));
      expect(tomato.alternativeBrands.any((b) => b.name == 'Saaf' || b.name == 'Indofil M-45'), true);

      // Check Rice Blast
      final blast = service.findDiseaseById('rice_blast');
      expect(blast, isNotNull);
      expect(blast!.activeIngredient.contains('Tricyclazole'), true);
      expect(blast.primaryBrand.name, contains('Beam'));

      // Check Cotton Leaf Curl
      final cotton = service.findDiseaseById('cotton_whitefly_leaf_curl');
      expect(cotton, isNotNull);
      expect(cotton!.activeIngredient.contains('Diafenthiuron'), true);
    });

    test('enrichResult enriches raw AI detection results with CIBRC active ingredient and brands', () {
      final service = DiseaseService.instance;

      final rawAi = {
        'crop': 'Tomato',
        'disease': 'Early Blight',
        'confidence': 'High',
        'cause': 'Fungal',
        'severity': 'Moderate',
        'symptoms': 'Leaf target spots',
      };

      final enriched = service.enrichResult(rawAi);
      expect(enriched.crop, 'Tomato');
      expect(enriched.activeIngredient, contains('Mancozeb'));
      expect(enriched.primaryBrand.name, contains('Dithane'));
      expect(enriched.alternativeBrands.isNotEmpty, true);
    });
  });

  group('Disease Checker UI Widgets', () {
    testWidgets('BrandRecommendationCard renders primary and alternative brands', (tester) async {
      const primary = BrandInfo(
        name: 'Dithane M-45',
        manufacturer: 'Indofil Industries',
        formulation: '75% WP',
        approximatePrice: '₹350 / kg',
      );

      const alts = [
        BrandInfo(name: 'Indofil M-45', manufacturer: 'Indofil Industries'),
        BrandInfo(name: 'Saaf', manufacturer: 'UPL Limited'),
        BrandInfo(name: 'Kavach', manufacturer: 'Syngenta'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BrandRecommendationCard(
                primaryBrand: primary,
                alternativeBrands: alts,
                activeIngredient: 'Mancozeb 75% WP',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Commercial Brand Recommendations'), findsOneWidget);
      expect(find.textContaining('Mancozeb 75% WP'), findsWidgets);
      expect(find.text('PRIMARY BRAND'), findsOneWidget);
      expect(find.text('Dithane M-45'), findsOneWidget);
      expect(find.text('Manufacturer: Indofil Industries'), findsOneWidget);
      expect(find.text('Alternative Commercial Brands'), findsOneWidget);
      expect(find.text('Indofil M-45'), findsOneWidget);
      expect(find.text('Saaf'), findsOneWidget);
    });

    testWidgets('DiseaseTreatmentView renders full overview, dosage, and store directory button', (tester) async {
      final disease = DiseaseService.instance.findDiseaseById('rice_blast')!;
      bool storeOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiseaseTreatmentView(
                disease: disease,
                onOpenStoreDirectory: () => storeOpened = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(disease.name), findsOneWidget);
      expect(find.textContaining('AI prediction only'), findsOneWidget);
      expect(find.text('Verified product recommendations'), findsOneWidget);
      expect(find.text('Find nearby agricultural stores'), findsOneWidget);

      await tester.ensureVisible(find.text('Find nearby agricultural stores'));
      await tester.tap(find.text('Find nearby agricultural stores'));
      expect(storeOpened, true);
    });
  });
}
