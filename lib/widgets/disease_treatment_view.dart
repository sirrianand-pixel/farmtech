import 'package:flutter/material.dart';
import '../models/disease_model.dart';
import '../models/agricultural_product.dart';
import '../services/product_service.dart';
import 'brand_recommendation_card.dart';
import 'dealer_directory_sheet.dart';

class DiseaseTreatmentView extends StatelessWidget {
  final DiseaseModel disease;
  final VoidCallback? onOpenStoreDirectory;

  const DiseaseTreatmentView({
    super.key,
    required this.disease,
    this.onOpenStoreDirectory,
  });

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return const Color(0xFFC62828);
      case 'moderate':
        return const Color(0xFFEF6C00);
      case 'mild':
        return const Color(0xFFF9A825);
      case 'healthy':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = disease.isHealthy;
    final color = _severityColor(disease.severity);
    // Legacy recommendations are intentionally hidden unless a catalogue entry
    // supplies an exact, verified package image. This prevents unsourced brand,
    // concentration, dosage and PHI claims from reaching farmers.
    if (disease.primaryBrand.imageUrl == null) {
      return _buildSafetyFirstResult(context, color, isHealthy);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Disease Overview Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isHealthy
                  ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
                  : [const Color(0xFF311B92), const Color(0xFF6A1B9A)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (isHealthy ? Colors.green : Colors.purple).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      isHealthy ? '🌿' : '⚠️',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          disease.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (disease.scientificName != null && disease.scientificName!.isNotEmpty)
                          Text(
                            disease.scientificName!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Target Crop: ${disease.crop}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Badge(disease.confidence, Colors.white.withValues(alpha: 0.2), Colors.white),
                  _Badge(disease.cause, Colors.white.withValues(alpha: 0.2), Colors.white),
                  _Badge(disease.severity, color.withValues(alpha: 0.9), Colors.white),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Healthy state notice
        if (isHealthy) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Text('🌱', style: TextStyle(fontSize: 26)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your plant is healthy! Continue regular balanced irrigation and schedule preventative scouting.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // ── Symptoms Card ──
          _CardContainer(
            icon: Icons.search_rounded,
            iconColor: Colors.orange.shade800,
            title: 'Observed Symptoms',
            child: Text(
              disease.symptoms,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),

          // ── Description / Etiology ──
          if (disease.description.isNotEmpty && disease.description != disease.symptoms) ...[
            _CardContainer(
              icon: Icons.info_outline_rounded,
              iconColor: Colors.blue.shade800,
              title: 'Disease Description & Spread',
              child: Text(
                disease.description,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── 2. Approved Chemical Treatment (CIBRC / ICAR Guidelines) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8F5E9),
                  Colors.green.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Government Approved Treatment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            'Central Insecticides Board & ICAR Guidelines',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Active Ingredient
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CIBRC APPROVED ACTIVE INGREDIENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disease.activeIngredient,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        disease.cibrcGuidelines,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Safe Dosage
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.medication_liquid_rounded, color: Color(0xFF2E7D32), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ICAR RECOMMENDED SAFE DOSAGE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              disease.dosageInfo,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (disease.waitingPeriod != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 13, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Waiting Period (PHI): ${disease.waitingPeriod}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFB71C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ICAR safe application tip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        disease.icarGuidelines,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Brand Recommendations ──
          BrandRecommendationCard(
            primaryBrand: disease.primaryBrand,
            alternativeBrands: disease.alternativeBrands,
            activeIngredient: disease.activeIngredient,
          ),
          const SizedBox(height: 14),

          // ── 4. Nearby Store Directory Quick Launcher Card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buy ${disease.primaryBrand.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Locate certified local dealers, call or navigate',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onOpenStoreDirectory ?? () => DealerDirectorySheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Find Shops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Treatment Steps ──
          if (disease.treatmentSteps.isNotEmpty) ...[
            _CardContainer(
              icon: Icons.checklist_rounded,
              iconColor: const Color(0xFF1565C0),
              title: 'Recommended Action Steps',
              child: Column(
                children: disease.treatmentSteps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Fertilizers & Plant Immunity ──
          if (disease.fertilizers.isNotEmpty) ...[
            _CardContainer(
              icon: Icons.eco_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Fertilizers & Nutrient Support',
              child: Column(
                children: disease.fertilizers.map((f) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text('🌿 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Prevention Tips ──
          if (disease.preventionTips.isNotEmpty) ...[
            _CardContainer(
              icon: Icons.healing_rounded,
              iconColor: Colors.teal.shade800,
              title: 'Prevention & Integrated Pest Management (IPM)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: disease.preventionTips.map((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSafetyFirstResult(BuildContext context, Color color, bool isHealthy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(disease.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text('Crop: ${disease.crop} • AI confidence: ${disease.confidence}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            const Text('AI prediction only — confirm with an agricultural officer before treatment.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        if (!isHealthy) _CardContainer(
          icon: Icons.visibility_outlined,
          iconColor: Colors.orange.shade800,
          title: 'Visible symptoms / symptoms to confirm',
          child: Text(disease.symptoms, style: const TextStyle(fontSize: 13, height: 1.45)),
        ),
        if (!isHealthy) const SizedBox(height: 12),
        _VerifiedProducts(crop: disease.crop, disease: disease.name),
        const SizedBox(height: 12),
        if (disease.preventionTips.isNotEmpty) _CardContainer(
          icon: Icons.eco_outlined,
          iconColor: const Color(0xFF2E7D32),
          title: 'Prevention and observation',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: disease.preventionTips.take(4).map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4), child: Text('• $tip', style: const TextStyle(fontSize: 12, height: 1.35)),
          )).toList()),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onOpenStoreDirectory ?? () => DealerDirectorySheet.show(context),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Find nearby agricultural stores'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

class _VerifiedProducts extends StatelessWidget {
  final String crop;
  final String disease;
  const _VerifiedProducts({required this.crop, required this.disease});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgriculturalProduct>>(
      stream: ProductService.instance.verifiedFor(crop: crop, disease: disease),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _CardContainer(
            icon: Icons.verified_outlined,
            iconColor: Color(0xFF1565C0),
            title: 'Verified product recommendations',
            child: Text('Checking the source-verified product catalogue…'),
          );
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const _CardContainer(
            icon: Icons.verified_outlined,
            iconColor: Color(0xFF1565C0),
            title: 'Verified product recommendations',
            child: Text('No source-verified product record is available yet. FarmTech will show only products with an official manufacturer label, exact packaging photo and verified crop-use source.'),
          );
        }
        return _CardContainer(
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFF1565C0),
          title: 'Verified product recommendations',
          child: Column(
            children: products.map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(product.productImageUrl!, width: 62, height: 62, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const SizedBox(width: 62, height: 62, child: Icon(Icons.image_not_supported_outlined))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${product.brand} — ${product.productName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${product.category} • ${product.formulation}', style: const TextStyle(fontSize: 11)),
                  Text(product.manufacturer, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text('Source checked: ${product.lastVerified}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ])),
              ]),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _CardContainer extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _CardContainer({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _Badge(this.label, this.bgColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
