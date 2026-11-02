import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agricultural_product.dart';

class ProductService {
  static final instance = ProductService._();
  ProductService._();

  Stream<List<AgriculturalProduct>> verifiedFor({required String crop, required String disease}) {
    try {
      return FirebaseFirestore.instance
          .collection('agricultural_products')
          .where('verification_status', isEqualTo: 'verified')
          .limit(50)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => AgriculturalProduct.fromMap(doc.data(), doc.id))
              .where((product) => product.productImageUrl != null && product.productImageUrl!.isNotEmpty)
              .where((product) => _matches(product, crop, disease))
              .take(3)
              .toList());
    } catch (_) {
      return Stream.value(const []);
    }
  }

  bool _matches(AgriculturalProduct product, String crop, String disease) {
    final cropValue = crop.toLowerCase();
    final diseaseValue = disease.toLowerCase();
    return product.applicableCrops.any((value) => cropValue.contains(value.toLowerCase()) || value.toLowerCase().contains(cropValue)) &&
        product.targetDiseases.any((value) => diseaseValue.contains(value.toLowerCase()) || value.toLowerCase().contains(diseaseValue));
  }
}
