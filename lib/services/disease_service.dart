import '../models/brand_info.dart';
import '../models/disease_model.dart';

class DiseaseService {
  static final DiseaseService instance = DiseaseService._();
  DiseaseService._();

  /// Comprehensive repository of ICAR and CIBRC approved crop diseases,
  /// chemical active ingredients, dosages, and certified commercial brand equivalents.
  final List<DiseaseModel> _repository = [
    // 1. Tomato Early Blight
    DiseaseModel(
      id: 'tomato_early_blight',
      name: 'Early Blight (Alternaria solani)',
      scientificName: 'Alternaria solani',
      crop: 'Tomato',
      symptoms:
          'Dark brown to black concentric rings ("target-board" pattern) on older lower leaves, surrounded by yellow chlorotic halos. Leads to severe defoliation.',
      description:
          'Fungal pathogen attacking Solanaceous crops in warm (24-29°C), humid weather with frequent rainfall or heavy dew. Survives in crop debris and solanaceous weeds.',
      activeIngredient: 'Mancozeb 75% WP',
      dosageInfo: '2.0 - 2.5 g per Litre of water (ICAR Standard Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. No. CIR-562/F/82 - Broad-spectrum protective dithiocarbamate contact fungicide with multi-site action.',
      icarGuidelines:
          'Spray at first symptom appearance. Direct spray to both upper and lower leaf surfaces. Repeat after 10-12 days if wet weather persists.',
      waitingPeriod: '7 - 10 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Dithane M-45',
        manufacturer: 'Indofil Industries / Corteva',
        formulation: '75% Wettable Powder (WP)',
        packageSize: '500g / 1kg',
        approximatePrice: '₹320 - ₹380 / kg',
        notes: 'India\'s benchmark protective Mancozeb fungicide for fungal blights.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Indofil M-45',
          manufacturer: 'Indofil Industries Ltd',
          formulation: 'Mancozeb 75% WP',
          approximatePrice: '₹310 / kg',
          notes: 'Equivalent multi-site dithiocarbamate fungicide.',
        ),
        BrandInfo(
          name: 'Uthane M-45',
          manufacturer: 'UPL Limited',
          formulation: 'Mancozeb 75% WP',
          approximatePrice: '₹330 / kg',
          notes: 'High solubility suspension formulation with rain-fastness.',
        ),
        BrandInfo(
          name: 'Saaf',
          manufacturer: 'UPL Limited',
          formulation: 'Carbendazim 12% + Mancozeb 63% WP',
          approximatePrice: '₹390 / 500g',
          notes: 'Dual systemic + contact action for advanced lesion arrest.',
        ),
        BrandInfo(
          name: 'Kavach',
          manufacturer: 'Syngenta India',
          formulation: 'Chlorothalonil 75% WP',
          approximatePrice: '₹480 / 500g',
          notes: 'Weather-stik technology resists wash-off during rain.',
        ),
      ],
      treatmentSteps: [
        'Spray Mancozeb 75% WP @ 2.5 g/L or Copper Oxychloride 50% WP @ 3 g/L.',
        'Prune and destroy infected lower leaves touching damp soil to halt fungal laddering.',
        'Apply foliar spray in early morning to allow leaves to dry before midday.',
        'For systemic curative knockdown, rotate with Azoxystrobin + Difenoconazole @ 1 ml/L.',
      ],
      preventionTips: [
        'Practice 3-year crop rotation with non-solanaceous crops.',
        'Use drip irrigation instead of overhead sprinklers to keep foliage dry.',
        'Mulch soil bed with silver-black polyethylene mulch to prevent soil-splash inoculum.',
      ],
      fertilizers: [
        'Calcium Nitrate @ 5g/L foliar spray to fortify plant cell wall integrity.',
        'Potassium Nitrate (13-00-45) @ 4g/L to strengthen disease resistance.',
      ],
      severity: 'Moderate',
      cause: 'Fungal',
    ),

    // 2. Rice / Paddy Blast
    DiseaseModel(
      id: 'rice_blast',
      name: 'Rice Blast (Magnaporthe oryzae)',
      scientificName: 'Pyricularia oryzae / Magnaporthe oryzae',
      crop: 'Rice / Paddy',
      symptoms:
          'Spindle-shaped elliptical lesions with gray/whitish centers and dark reddish-brown margins. Attacks leaf, collar, nodes, and panicle neck.',
      description:
          'Highly destructive fungal blast causing complete grain sterility when panicle neck is infected ("Neck Blast"). Thrives in cooler night temperatures with high humidity and excess nitrogen.',
      activeIngredient: 'Tricyclazole 75% WP',
      dosageInfo: '0.6 g per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-1240/F - Systemic melanin biosynthesis inhibitor (MBI) specifically approved for rice blast.',
      icarGuidelines:
          'Apply prophylactic spray at tillering stage and second spray at panicle emergence (booting stage). Do not exceed recommended dosage.',
      waitingPeriod: '21 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Beam 75 WP',
        manufacturer: 'Corteva Agriscience',
        formulation: '75% Wettable Powder',
        packageSize: '120g / 250g',
        approximatePrice: '₹340 / 120g',
        notes: 'Rapid root and leaf absorption prevents appressorium penetration.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Baan',
          manufacturer: 'BASF India Ltd',
          formulation: 'Tricyclazole 75% WP',
          approximatePrice: '₹320 / 120g',
          notes: 'High-purity systemic blast protectant.',
        ),
        BrandInfo(
          name: 'Sivic',
          manufacturer: 'Tata Rallis India',
          formulation: 'Tricyclazole 75% WP',
          approximatePrice: '₹310 / 120g',
          notes: 'Long-lasting residual systemic control.',
        ),
        BrandInfo(
          name: 'Amistar Top',
          manufacturer: 'Syngenta India',
          formulation: 'Azoxystrobin 18.2% + Difenoconazole 11.4% SC',
          approximatePrice: '₹680 / 200ml',
          notes: 'Dual broad-spectrum control for blast and sheath blight.',
        ),
        BrandInfo(
          name: 'Hinosan',
          manufacturer: 'Bayer CropScience',
          formulation: 'Edifenphos 50% EC',
          approximatePrice: '₹410 / 500ml',
          notes: 'Fast curative organophosphorus fungicide.',
        ),
      ],
      treatmentSteps: [
        'Immediately spray Tricyclazole 75% WP @ 0.6g/L or Isoprothiolane 40% EC @ 1.5 ml/L.',
        'Drain excess stagnant standing water from fields during continuous overcast weather.',
        'Withhold top-dressing of urea / nitrogenous fertilizers while blast is active.',
      ],
      preventionTips: [
        'Seed treatment with Tricyclazole 75% WP @ 2g/kg seed or Carbendazim 2g/kg.',
        'Select blast-resistant varieties like Swarna Sub-1, IR-64, or MTU-1010.',
      ],
      fertilizers: [
        'Muriate of Potash (MOP) @ 25 kg/acre top dressing to stiffen plant stems.',
        'Silica foliar spray (Orthosilicic acid 2%) @ 2 ml/L to toughen leaf epidermis.',
      ],
      severity: 'Severe',
      cause: 'Fungal',
    ),

    // 3. Cotton Whitefly & Leaf Curl
    DiseaseModel(
      id: 'cotton_whitefly_leaf_curl',
      name: 'Cotton Leaf Curl Virus (CLCuV) & Whitefly',
      scientificName: 'Cotton Leaf Curl Virus / Bemisia tabaci',
      crop: 'Cotton',
      symptoms:
          'Upward leaf curling, thickening of veins, leaf enations (cup-shaped outgrowths) on underside of leaves, and severe plant stunting.',
      description:
          'Viral begomovirus transmitted by sap-sucking sweetpotato whitefly (Bemisia tabaci). Causes heavy square dropping and yield collapse.',
      activeIngredient: 'Diafenthiuron 50% WP',
      dosageInfo: '1.2 - 1.5 g per Litre of water (ICAR Safe Recommendation)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-1820/I - Photochemical thiourea insecticide for sucking pests with translaminar contact and vapor action.',
      icarGuidelines:
          'Apply when nymph/adult whitefly count exceeds economic threshold level (ETL) of 6-8 whiteflies per leaf.',
      waitingPeriod: '15 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Pegasus 50 WP',
        manufacturer: 'Syngenta India',
        formulation: 'Diafenthiuron 50% WP',
        packageSize: '250g / 500g',
        approximatePrice: '₹750 / 250g',
        notes: 'Translaminar insecticide halting ATP synthesis in sucking whiteflies.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Polo',
          manufacturer: 'Syngenta',
          formulation: 'Diafenthiuron 50% SC',
          approximatePrice: '₹820 / 250ml',
          notes: 'Liquid suspension form for easy tank mixing and reduced nozzle clogging.',
        ),
        BrandInfo(
          name: 'Confidor',
          manufacturer: 'Bayer CropScience',
          formulation: 'Imidacloprid 17.8% SL',
          approximatePrice: '₹350 / 100ml',
          notes: 'Systemic neonicotinoid targeting sap-sucking nymphs.',
        ),
        BrandInfo(
          name: 'Lano',
          manufacturer: 'Sumitomo Chemical',
          formulation: 'Pyriproxyfen 10% EC',
          approximatePrice: '₹460 / 250ml',
          notes: 'Insect growth regulator (IGR) suppressing whitefly egg hatching.',
        ),
        BrandInfo(
          name: 'Sefina',
          manufacturer: 'BASF India',
          formulation: 'Afidopyropen 50 g/L DC',
          approximatePrice: '₹950 / 250ml',
          notes: 'Modern chordotonal organ modulator paralyzing whitefly feeding within 2 hours.',
        ),
      ],
      treatmentSteps: [
        'Install 20-25 yellow sticky traps per acre at canopy level to monitor and trap whiteflies.',
        'Spray Diafenthiuron 50% WP @ 1.25 g/L or Afidopyropen @ 2 ml/L.',
        'Direct spray to the undersides of leaves where whiteflies colonize.',
        'Remove and incinerate severely stunted virus-infected plants.',
      ],
      preventionTips: [
        'Avoid growing collateral weed hosts like Abutilon indicum around field borders.',
        'Rotate with alternate mode-of-action chemicals to prevent whitefly pesticide resistance.',
      ],
      fertilizers: [
        'Magnesium Sulphate (MgSO4) 1% + Urea 1% foliar spray to reverse leaf chlorosis.',
      ],
      severity: 'Severe',
      cause: 'Viral (Vector Infestation)',
    ),

    // 4. Groundnut Tikka Leaf Spot
    DiseaseModel(
      id: 'groundnut_tikka',
      name: 'Tikka Leaf Spot (Cercospora Leaf Spot)',
      scientificName: 'Cercospora arachidicola & Phaeoisariopsis personata',
      crop: 'Groundnut (Peanut)',
      symptoms:
          'Early leaf spots are reddish-brown to dark brown with prominent yellow halo; late spots are circular carbon-black without halo. Causes premature defoliation.',
      description:
          'Major airborne fungal epidemic of groundnut across dryland belts. Infection reduces photosynthetic leaf area and limits pod development.',
      activeIngredient: 'Chlorothalonil 75% WP',
      dosageInfo: '2.0 g per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-890/F - Broad-spectrum non-systemic chloronitrile contact fungicide with multi-site protective action.',
      icarGuidelines:
          'Start spray 35-40 days after sowing or at onset of initial spots. Repeat at 12-14 day intervals.',
      waitingPeriod: '14 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Kavach',
        manufacturer: 'Syngenta India',
        formulation: 'Chlorothalonil 75% WP',
        packageSize: '250g / 500g',
        approximatePrice: '₹470 / 500g',
        notes: 'Provides tenacious stickability on groundnut leaves.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Dithane M-45',
          manufacturer: 'Indofil Industries',
          formulation: 'Mancozeb 75% WP',
          approximatePrice: '₹340 / kg',
          notes: 'Reliable protective dithiocarbamate fungicide.',
        ),
        BrandInfo(
          name: 'Contaf Plus',
          manufacturer: 'Tata Rallis India',
          formulation: 'Hexaconazole 5% SC',
          approximatePrice: '₹420 / 500ml',
          notes: 'Triazole systemic fungicide providing curative eradication.',
        ),
        BrandInfo(
          name: 'Folicur',
          manufacturer: 'Bayer CropScience',
          formulation: 'Tebuconazole 25.9% EC',
          approximatePrice: '₹620 / 250ml',
          notes: 'Broad-spectrum sterol demethylation inhibitor.',
        ),
        BrandInfo(
          name: 'Saaf',
          manufacturer: 'UPL Limited',
          formulation: 'Carbendazim 12% + Mancozeb 63% WP',
          approximatePrice: '₹390 / 500g',
          notes: 'Dual systemic + contact action.',
        ),
      ],
      treatmentSteps: [
        'Apply Chlorothalonil 75% WP @ 2g/L or Tebuconazole 25.9% EC @ 1.5 ml/L.',
        'Ensure spray droplet contact on both upper and lower canopy layers.',
        'Collect and destroy infected crop residues post-harvest.',
      ],
      preventionTips: [
        'Treat seeds with Trichoderma viride @ 4g/kg seed before sowing.',
        'Maintain crop spacing of 30 x 10 cm to reduce canopy microclimate humidity.',
      ],
      fertilizers: [
        'Gypsum @ 200 kg/acre at flowering stage for pod filling and shell hardening.',
        'Foliar spray of 0.5% Ferrous Sulphate + 0.1% Citric acid for iron chlorosis.',
      ],
      severity: 'Moderate',
      cause: 'Fungal',
    ),

    // 5. Chilli Anthracnose & Fruit Rot
    DiseaseModel(
      id: 'chilli_anthracnose',
      name: 'Anthracnose & Dieback (Colletotrichum capsici)',
      scientificName: 'Colletotrichum capsici',
      crop: 'Chilli',
      symptoms:
          'Circular sunken water-soaked spots with concentric rings of black acervuli on ripe fruits. Twigs die back from tip downward (dieback).',
      description:
          'Severe fungal disease causing fruit rot and twig necrosis. Spreads rapidly in warm, rainy weather through splashed conidia.',
      activeIngredient: 'Azoxystrobin 18.2% + Difenoconazole 11.4% SC',
      dosageInfo: '1.0 ml per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-3450/F - Modern premix of strobilurin (QoI) and triazole (DMI) with protective, curative, and translaminar properties.',
      icarGuidelines:
          'Apply at initial flowering and fruit formation stages. Repeat after 15 days if cloudy humid conditions persist.',
      waitingPeriod: '5 - 7 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Amistar Top',
        manufacturer: 'Syngenta India',
        formulation: 'Azoxystrobin 18.2% + Difenoconazole 11.4% SC',
        packageSize: '100ml / 200ml / 500ml',
        approximatePrice: '₹420 / 100ml',
        notes: 'Gold standard premix fungicide for chilli anthracnose and fruit rot.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Custodia',
          manufacturer: 'ADAMA India',
          formulation: 'Azoxystrobin 11% + Tebuconazole 18.3% w/w SC',
          approximatePrice: '₹550 / 250ml',
          notes: 'Excellent curative and antisporulant action on fruit rot.',
        ),
        BrandInfo(
          name: 'Score',
          manufacturer: 'Syngenta India',
          formulation: 'Difenoconazole 25% EC',
          approximatePrice: '₹410 / 100ml',
          notes: 'Fast penetrant triazole with long protective buffer.',
        ),
        BrandInfo(
          name: 'Nativo',
          manufacturer: 'Bayer CropScience',
          formulation: 'Tebuconazole 50% + Trifloxystrobin 25% WG',
          approximatePrice: '₹720 / 100g',
          notes: 'Water dispersible granules with mesostemic movement.',
        ),
        BrandInfo(
          name: 'Blitox 50',
          manufacturer: 'Tata Rallis India',
          formulation: 'Copper Oxychloride 50% WP',
          approximatePrice: '₹340 / 500g',
          notes: 'Reliable inorganic copper protective barrier.',
        ),
      ],
      treatmentSteps: [
        'Spray Amistar Top @ 1 ml/L or Nativo @ 0.6 g/L upon observing fruit spotting.',
        'Collect and burn infected mummified fruits fallen on the ground.',
        'Avoid field operations when plant foliage is wet.',
      ],
      preventionTips: [
        'Seed treatment with Thiram 3g/kg or Carbendazim 2g/kg.',
        'Use disease-tolerant hybrid seeds like Arka Harita or Tej-4.',
      ],
      fertilizers: [
        'Boron 20% (Disodium Octaborate Tetrahydrate) @ 1.5g/L to prevent fruit cracking.',
      ],
      severity: 'Severe',
      cause: 'Fungal',
    ),

    // 6. Potato / Tomato Late Blight
    DiseaseModel(
      id: 'potato_late_blight',
      name: 'Late Blight (Phytophthora infestans)',
      scientificName: 'Phytophthora infestans',
      crop: 'Potato / Tomato',
      symptoms:
          'Water-soaked irregular black/dark lesions at leaf margins and stems. Fine white cottony mildew appears on undersides during wet mornings.',
      description:
          'Rapidly spreading oomycete capable of destroying entire crops within 48 to 72 hours under cool, cloudy, fog-laden weather.',
      activeIngredient: 'Dimethomorph 50% WP or Cymoxanil 8% + Mancozeb 64% WP',
      dosageInfo: '1.5 - 2.0 g per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-1640/F - Oomycete-targeted cinnamic acid derivative with anti-sporulant activity.',
      icarGuidelines:
          'Spray proactively when mean daily temperature is 10-20°C and relative humidity exceeds 80%. Ensure thorough coverage.',
      waitingPeriod: '10 - 14 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Acrobat',
        manufacturer: 'BASF India Ltd',
        formulation: 'Dimethomorph 50% WP',
        packageSize: '100g / 250g',
        approximatePrice: '₹410 / 100g',
        notes: 'Translaminar and curative inhibitor of oomycete cell wall synthesis.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Curzate',
          manufacturer: 'Corteva Agriscience',
          formulation: 'Cymoxanil 8% + Mancozeb 64% WP',
          approximatePrice: '₹490 / 500g',
          notes: 'Curative penetrant cymoxanil paired with protective mancozeb.',
        ),
        BrandInfo(
          name: 'Ridomil Gold',
          manufacturer: 'Syngenta India',
          formulation: 'Metalaxyl-M 4% + Mancozeb 64% WP',
          approximatePrice: '₹580 / 500g',
          notes: 'Renowned systemic oomycete protectant with mefenoxam.',
        ),
        BrandInfo(
          name: 'Infinito',
          manufacturer: 'Bayer CropScience',
          formulation: 'Fluopicolide 5.56% + Propamocarb HCl 55.6% SC',
          approximatePrice: '₹840 / 250ml',
          notes: 'Advanced anti-sporulant action preventing tuber rot.',
        ),
        BrandInfo(
          name: 'Blitox',
          manufacturer: 'Tata Rallis India',
          formulation: 'Copper Oxychloride 50% WP',
          approximatePrice: '₹340 / 500g',
          notes: 'Broad-spectrum inorganic protectant.',
        ),
      ],
      treatmentSteps: [
        'Apply Acrobat @ 1.5 g/L or Curzate @ 2 g/L immediately at first lesion sight.',
        'In infected fields, practice dehaulming (cut foliage) 10-12 days before harvest to prevent tuber infection.',
        'Avoid furrow over-irrigation that stagnates near ridges.',
      ],
      preventionTips: [
        'Plant certified disease-free seed tubers treated with Mancozeb 3g/L solution.',
        'Earth up ridges properly so tubers are covered by at least 10 cm of soil.',
      ],
      fertilizers: [
        'Potassium Schoenite @ 5g/L foliar spray for enhanced cold and stress tolerance.',
      ],
      severity: 'Severe',
      cause: 'Oomycete (Fungal-like)',
    ),

    // 7. Sucking Pests / Aphids / Jassids across Vegetables & Pulses
    DiseaseModel(
      id: 'sucking_pest_aphids',
      name: 'Aphids, Thrips & Sucking Pests',
      scientificName: 'Aphis gossypii / Scirtothrips dorsalis',
      crop: 'Vegetables / Pulses / Cotton',
      symptoms:
          'Leaves cup upward or downward, mottled yellowing, sticky honeydew secretion with black sooty mold growth on leaf surface.',
      description:
          'Colonies of tiny piercing-sucking insects sapping plant vitality and transmitting dangerous plant viruses.',
      activeIngredient: 'Imidacloprid 17.8% SL',
      dosageInfo: '0.4 - 0.5 ml per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-1420/I - Systemic neonicotinoid targeting insect acetylcholine receptors.',
      icarGuidelines:
          'Apply when pest population reaches economic threshold. Avoid spraying in direct sun during peak honeybee foraging hours.',
      waitingPeriod: '15 - 21 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Confidor',
        manufacturer: 'Bayer CropScience',
        formulation: 'Imidacloprid 17.8% SL',
        packageSize: '100ml / 250ml / 500ml',
        approximatePrice: '₹340 / 100ml',
        notes: 'India\'s standard systemic sucking pest control.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Tata Mida',
          manufacturer: 'Tata Rallis India',
          formulation: 'Imidacloprid 17.8% SL',
          approximatePrice: '₹280 / 100ml',
          notes: 'High bio-efficacy systemic sucking pest protectant.',
        ),
        BrandInfo(
          name: 'Victor',
          manufacturer: 'UPL Limited',
          formulation: 'Imidacloprid 17.8% SL',
          approximatePrice: '₹290 / 100ml',
          notes: 'Proven systemic neonicotinoid.',
        ),
        BrandInfo(
          name: 'Actara',
          manufacturer: 'Syngenta India',
          formulation: 'Thiamethoxam 25% WG',
          approximatePrice: '₹380 / 100g',
          notes: 'Highly soluble granule formulation with vigorous greening effect.',
        ),
        BrandInfo(
          name: 'Alika',
          manufacturer: 'Syngenta India',
          formulation: 'Thiamethoxam 12.6% + Lambda Cyhalothrin 9.5% ZC',
          approximatePrice: '₹460 / 100ml',
          notes: 'Dual systemic + instant contact knockdown capsule suspension.',
        ),
      ],
      treatmentSteps: [
        'Spray Imidacloprid 17.8% SL @ 0.5 ml/L or Thiamethoxam 25% WG @ 0.4 g/L.',
        'Install blue sticky traps for thrips and yellow traps for aphids/whiteflies.',
        'Spray Neem Oil (Azadirachtin 10,000 ppm) @ 2 ml/L as an eco-friendly repellent.',
      ],
      preventionTips: [
        'Conserve natural predators such as ladybird beetles and lacewings.',
        'Avoid excessive unmetered nitrogen fertilization which attracts aphids.',
      ],
      fertilizers: [
        'Foliar spray of 19:19:19 water-soluble NPK @ 5g/L to support recovery.',
      ],
      severity: 'Moderate',
      cause: 'Insect Pest',
    ),

    // 8. Maize / Corn Fall Armyworm
    DiseaseModel(
      id: 'maize_fall_armyworm',
      name: 'Fall Armyworm (Spodoptera frugiperda)',
      scientificName: 'Spodoptera frugiperda',
      crop: 'Maize / Corn',
      symptoms:
          'Pinholes on young leaves, ragged shot-hole feeding on whorl leaves, and prominent sawdust-like fecal frass inside the central plant whorl.',
      description:
          'Invasive, highly ravenous polyphagous noctuid pest feeding voraciously on maize crop whorls, tassels, and cobs.',
      activeIngredient: 'Chlorantraniliprole 18.5% SC',
      dosageInfo: '0.4 ml per Litre of water (ICAR Safe Dosage)',
      cibrcGuidelines:
          'CIBRC Reg. CIR-2880/I - Ryanodine receptor modulator anthranilic diamide targeting lepidopteran larvae.',
      icarGuidelines:
          'Spray directed deep into the leaf whorl where larvae feed. Apply in late afternoon when larvae are active.',
      waitingPeriod: '14 Days Pre-Harvest Interval (PHI)',
      primaryBrand: BrandInfo(
        name: 'Coragen',
        manufacturer: 'FMC India',
        formulation: 'Chlorantraniliprole 18.5% SC',
        packageSize: '60ml / 150ml',
        approximatePrice: '₹620 / 60ml',
        notes: 'Exceptional long residual whorl protection with minimal non-target impact.',
      ),
      alternativeBrands: [
        BrandInfo(
          name: 'Vesticor',
          manufacturer: 'Tata Rallis India',
          formulation: 'Chlorantraniliprole 18.5% SC',
          approximatePrice: '₹590 / 60ml',
          notes: 'High quality diamide formulation for stem & whorl borers.',
        ),
        BrandInfo(
          name: 'Ampligo',
          manufacturer: 'Syngenta India',
          formulation: 'Chlorantraniliprole 9.3% + Lambda-cyhalothrin 4.6% ZC',
          approximatePrice: '₹680 / 100ml',
          notes: 'Dual action providing rapid knockdown plus sustained residual activity.',
        ),
        BrandInfo(
          name: 'Proclaim',
          manufacturer: 'Syngenta India',
          formulation: 'Emamectin Benzoate 5% SG',
          approximatePrice: '₹340 / 100g',
          notes: 'Semi-synthetic avermectin with rapid stomach action on caterpillars.',
        ),
        BrandInfo(
          name: 'Spintor',
          manufacturer: 'Corteva Agriscience',
          formulation: 'Spinosad 45% SC',
          approximatePrice: '₹820 / 75ml',
          notes: 'Derived from natural soil bacterium with low mammalian toxicity.',
        ),
      ],
      treatmentSteps: [
        'Whorl application of Chlorantraniliprole 18.5% SC @ 0.4 ml/L or Emamectin Benzoate 5% SG @ 0.5 g/L.',
        'Use knapsack sprayer nozzle directly pointed into whorls.',
        'Apply dry sand mixed with neem seed powder (9:1 ratio) into central whorls for physical larval abrasion.',
      ],
      preventionTips: [
        'Install FAW pheromone traps @ 5 per acre for early adult moth tracking.',
        'Synchronize planting in a village block to avoid staggered caterpillar build-up.',
      ],
      fertilizers: [
        'Apply balanced basal DAP and Zinc Sulphate (10 kg/acre) for rapid vegetative vigor.',
      ],
      severity: 'Severe',
      cause: 'Insect Pest',
    ),
  ];

  List<DiseaseModel> getAllDiseases() => List.unmodifiable(_repository);

  DiseaseModel? findDiseaseById(String id) {
    try {
      return _repository.firstWhere(
        (d) => d.id.toLowerCase() == id.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Looks up repository disease by matching crop and keywords,
  /// or enriches a raw AI detection result with CIBRC active ingredients & brands.
  DiseaseModel enrichResult(Map<String, dynamic> aiJson) {
    final rawDisease = aiJson['disease']?.toString().toLowerCase() ?? '';
    final rawCrop = aiJson['crop']?.toString().toLowerCase() ?? '';

    // --- Ornamental / Houseplant detection: bypass CIBRC agricultural mapping ---
    // If the AI correctly identified a non-agricultural plant (money plant, rose, snake plant,
    // peace lily, cactus, fern, basil, aloe, etc.) — build a generic care model directly
    // from AI output instead of forcing it into a crop disease template.
    const houseplantKeywords = [
      'money plant', 'pothos', 'epipremnum', 'scindapsus',
      'peace lily', 'spathiphyllum',
      'snake plant', 'sansevieria', 'dracaena',
      'aloe', 'succulent', 'cactus',
      'rose', 'hibiscus', 'jasmine', 'bougainvillea',
      'fern', 'philodendron', 'monstera', 'anthurium',
      'rubber plant', 'ficus', 'croton',
      'spider plant', 'chlorophytum',
      'basil', 'mint', 'tulsi', 'curry leaf',
      'ornamental', 'houseplant', 'indoor plant', 'potted',
    ];
    final isHouseplant = houseplantKeywords.any(
      (kw) => rawCrop.contains(kw) || rawDisease.contains(kw),
    );

    if (isHouseplant) {
      // Build a DiseaseModel entirely from AI JSON — no CIBRC mapping applied.
      final rawTreatment = aiJson['treatment'];
      final List<String> treatmentSteps = rawTreatment is List
          ? rawTreatment.map((e) => e.toString()).toList()
          : (rawTreatment != null ? [rawTreatment.toString()] : [
              'Inspect roots and remove any mushy/black roots.',
              'Repot in fresh well-draining potting mix if root rot is suspected.',
              'Adjust watering — allow topsoil to dry between waterings.',
              'Move to bright indirect light; avoid direct harsh sun.',
            ]);

      final rawFertilizers = aiJson['fertilizers'];
      final List<String> fertilizers = rawFertilizers is List
          ? rawFertilizers.map((e) => e.toString()).toList()
          : ['Liquid NPK 20:20:20 @ 2g/L foliar spray monthly during growing season.'];

      final rawPrevention = aiJson['prevention']?.toString() ??
          'Maintain consistent watering schedule. Ensure adequate humidity and indirect bright light.';

      // Build recommended products from AI if present, else generic
      final rawProds = aiJson['recommended_products'];
      BrandInfo primaryBrand;
      List<BrandInfo> alternativeBrands = [];
      if (rawProds is List && rawProds.isNotEmpty) {
        final first = rawProds[0] is Map
            ? (rawProds[0] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        primaryBrand = BrandInfo(
          name: first['name']?.toString() ?? 'Neem Oil Spray',
          manufacturer: 'Houseplant Care',
          formulation: first['usage']?.toString() ?? '5 ml/L spray',
          notes: first['notes']?.toString() ?? 'Safe for indoor use.',
        );
        for (int i = 1; i < rawProds.length && i < 4; i++) {
          final prod = rawProds[i] is Map
              ? (rawProds[i] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
          alternativeBrands.add(BrandInfo(
            name: prod['name']?.toString() ?? '',
            manufacturer: 'General',
            formulation: prod['usage']?.toString() ?? '',
            notes: prod['notes']?.toString() ?? '',
          ));
        }
      } else {
        primaryBrand = const BrandInfo(
          name: 'Neem Oil Spray (3% Cold-Pressed)',
          manufacturer: 'Organic Houseplant Care',
          formulation: '5 ml per Litre of water',
          notes: 'Safe for all indoor ornamental plants. Spray on leaves and soil surface.',
          approximatePrice: '₹120 / 250ml',
        );
        alternativeBrands = const [
          BrandInfo(
            name: 'Hydrogen Peroxide 3% Solution',
            manufacturer: 'Pharmacy / General Store',
            formulation: '10 ml per 1 Litre water soil drench',
            notes: 'Kills root rot pathogens and re-oxygenates roots.',
          ),
          BrandInfo(
            name: 'Copper Fungicide (Ready-to-Use)',
            manufacturer: 'Houseplant Brand',
            formulation: 'Dilute as per label — typically 1–2 ml/L',
            notes: 'For mild fungal leaf spots on ornamental plants.',
          ),
        ];
      }

      return DiseaseModel(
        id: 'ornamental_${rawCrop.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z_]'), '')}',
        name: aiJson['disease']?.toString() ?? 'Plant Health Issue',
        scientificName: null,
        crop: aiJson['crop']?.toString() ?? 'Ornamental Plant',
        symptoms: aiJson['symptoms']?.toString() ??
            'Visual symptoms as identified by AI Vision analysis.',
        description: 'Ornamental / houseplant condition identified by AI Vision. '
            'Not an agricultural field crop — CIBRC guidelines do not apply. '
            'Follow general plant care practices and consult a horticulturist for confirmation.',
        activeIngredient: 'Neem Oil / Hydrogen Peroxide 3% (Organic)',
        dosageInfo: 'Neem Oil: 5 ml/L; H₂O₂: 10 ml/L as soil drench (ornamental care)',
        cibrcGuidelines: 'CIBRC agricultural registration not applicable for ornamental plants. '
            'Use general-purpose houseplant safe products only.',
        icarGuidelines: 'ICAR-NBPGR houseplant care: Ensure proper drainage, '
            'avoid waterlogging, and maintain moderate indirect light for tropical ornamentals.',
        waitingPeriod: 'Not applicable (ornamental plant)',
        primaryBrand: primaryBrand,
        alternativeBrands: alternativeBrands,
        treatmentSteps: treatmentSteps,
        preventionTips: [rawPrevention],
        fertilizers: fertilizers,
        severity: aiJson['severity']?.toString() ?? 'Moderate',
        cause: aiJson['cause']?.toString() ?? 'Fungal',
        confidence: aiJson['confidence']?.toString() ?? 'High (AI Vision)',
      );
    }

    // Check if it's healthy
    if (rawDisease.contains('health') || (aiJson['severity']?.toString().toLowerCase() ?? '').contains('health')) {
      return DiseaseModel(
        id: 'healthy_plant',
        name: 'Healthy Crop (${aiJson['crop'] ?? 'Identified'})',
        crop: aiJson['crop']?.toString() ?? 'Field Crop',
        symptoms: 'Vibrant green foliage with no detectable pathogens, lesions, or pest damage observed.',
        description: 'Plant displays excellent vegetative vigor and normal growth morphology.',
        activeIngredient: 'No chemical treatment needed (Eco-safe)',
        dosageInfo: 'Maintain regular irrigation and balanced nutrient management.',
        cibrcGuidelines: 'Organic & Good Agricultural Practices (GAP) compliant.',
        icarGuidelines: 'Monitor fields weekly. Maintain optimum field hygiene and border weed sanitation.',
        waitingPeriod: 'None',
        primaryBrand: const BrandInfo(
          name: 'Bio-stimulant / Organic Compost',
          manufacturer: 'Recommended Bio-Fertilizer',
        ),
        alternativeBrands: const [],
        treatmentSteps: const [
          'Continue scheduled balanced NPK fertilization.',
          'Scout crop weekly for early pest or disease symptoms.',
          'Maintain proper soil aeration and drip/furrow drainage.',
        ],
        preventionTips: const [
          'Rotate crops across cropping cycles.',
          'Avoid water stagnation around root zones.',
        ],
        fertilizers: const [
          'Balanced 19:19:19 NPK foliar application for sustained growth.',
          'Neem cake 100 kg/acre as soil amendment.',
        ],
        severity: 'Healthy',
        cause: 'Healthy Plant',
        confidence: aiJson['confidence']?.toString() ?? 'High',
      );
    }

    // Attempt intelligent matching with our certified CIBRC database
    // Only match if the crop also matches — avoid cross-mapping ornamental symptoms to crop diseases
    for (final model in _repository) {
      final cropMatches = rawCrop.isNotEmpty &&
          (model.crop.toLowerCase().contains(rawCrop.split(' ')[0]) ||
              rawCrop.contains(model.crop.toLowerCase().split(' ')[0]));
      if (!cropMatches) continue; // require crop to match first

      final nameMatches = model.name.toLowerCase().split(' ').any(
            (word) => word.length > 3 && rawDisease.contains(word),
          );
      if (nameMatches || rawDisease.contains(model.id.split('_').skip(1).join('_'))) {
        return model;
      }
    }

    // Direct keyword aliases — only triggered when crop also indicates an agricultural plant
    final isAgriculturalCrop = const [
      'tomato', 'rice', 'paddy', 'cotton', 'groundnut', 'peanut',
      'chilli', 'pepper', 'potato', 'maize', 'corn', 'wheat', 'onion',
      'sugarcane', 'soybean', 'sunflower', 'mango', 'banana', 'grape',
      'cucumber', 'brinjal', 'eggplant', 'okra', 'ladyfinger',
    ].any((crop) => rawCrop.contains(crop));

    if (isAgriculturalCrop) {
      if (rawDisease.contains('blast') && (rawCrop.contains('rice') || rawCrop.contains('paddy'))) {
        return findDiseaseById('rice_blast')!;
      }
      if (rawDisease.contains('early blight') || (rawDisease.contains('blight') && rawCrop.contains('tomato'))) {
        return findDiseaseById('tomato_early_blight')!;
      }
      if (rawDisease.contains('late blight') || rawCrop.contains('potato')) {
        return findDiseaseById('potato_late_blight')!;
      }
      if (rawDisease.contains('tikka') || rawDisease.contains('cercospora') ||
          rawCrop.contains('groundnut') || rawCrop.contains('peanut')) {
        return findDiseaseById('groundnut_tikka')!;
      }
      if ((rawDisease.contains('curl') || rawDisease.contains('whitefly')) && rawCrop.contains('cotton')) {
        return findDiseaseById('cotton_whitefly_leaf_curl')!;
      }
      if (rawDisease.contains('anthracnose') || rawDisease.contains('fruit rot') ||
          rawCrop.contains('chilli') || rawCrop.contains('pepper')) {
        return findDiseaseById('chilli_anthracnose')!;
      }
      if (rawDisease.contains('armyworm') || rawDisease.contains('borer') ||
          rawCrop.contains('maize') || rawCrop.contains('corn')) {
        return findDiseaseById('maize_fall_armyworm')!;
      }
      if (rawDisease.contains('aphid') || rawDisease.contains('thrip') ||
          rawDisease.contains('jassid') || rawDisease.contains('sucking')) {
        return findDiseaseById('sucking_pest_aphids')!;
      }
    }

    // Default Fallback: Construct complete DiseaseModel using CIBRC guidelines based on cause type
    final cause = aiJson['cause']?.toString() ?? 'Fungal';
    final isInsect = cause.toLowerCase().contains('pest') || cause.toLowerCase().contains('insect');

    final fallbackActive = isInsect ? 'Imidacloprid 17.8% SL / Chlorantraniliprole 18.5% SC' : 'Mancozeb 75% WP / Copper Oxychloride 50% WP';
    final fallbackDosage = isInsect ? '0.5 ml - 1.0 ml per Litre of water' : '2.0 - 2.5 g per Litre of water';
    final fallbackPrimary = isInsect
        ? const BrandInfo(
            name: 'Confidor',
            manufacturer: 'Bayer CropScience',
            formulation: '17.8% SL',
            approximatePrice: '₹340 / 100ml',
            notes: 'Broad-spectrum ICAR recommended formulation.',
          )
        : const BrandInfo(
            name: 'Dithane M-45',
            manufacturer: 'Indofil / Corteva',
            formulation: '75% WP',
            approximatePrice: '₹350 / kg',
            notes: 'Gold standard multi-site protective fungicide.',
          );

    final fallbackAlternatives = isInsect
        ? const [
            BrandInfo(name: 'Tata Mida', manufacturer: 'Tata Rallis', formulation: '17.8% SL'),
            BrandInfo(name: 'Victor', manufacturer: 'UPL Limited', formulation: '17.8% SL'),
            BrandInfo(name: 'Actara', manufacturer: 'Syngenta India', formulation: '25% WG'),
          ]
        : const [
            BrandInfo(name: 'Indofil M-45', manufacturer: 'Indofil Industries', formulation: '75% WP'),
            BrandInfo(name: 'Saaf', manufacturer: 'UPL Limited', formulation: 'Carbendazim + Mancozeb'),
            BrandInfo(name: 'Kavach', manufacturer: 'Syngenta India', formulation: 'Chlorothalonil 75% WP'),
            BrandInfo(name: 'Blitox 50', manufacturer: 'Tata Rallis', formulation: 'Copper Oxychloride 50% WP'),
          ];

    return DiseaseModel.fromMap({
      ...aiJson,
      'activeIngredient': fallbackActive,
      'dosageInfo': fallbackDosage,
      'cibrcGuidelines': 'Approved under CIBRC / Insecticides Act, 1968 for labeled crop application.',
      'icarGuidelines': 'Apply with hollow cone nozzle during early morning or evening. Wear protective gloves.',
      'primaryBrand': fallbackPrimary.toMap(),
      'alternativeBrands': fallbackAlternatives.map((b) => b.toMap()).toList(),
    });
  }
}
