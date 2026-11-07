import 'package:flutter/material.dart';
import '../models/dealer_model.dart';
import '../services/dealer_service.dart';
import '../services/location_service.dart';

class DealerDirectorySheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialDistrict;

  const DealerDirectorySheet({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialDistrict,
  });

  static Future<void> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
    String? initialDistrict,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => DealerDirectorySheet(
          initialLat: initialLat,
          initialLng: initialLng,
          initialDistrict: initialDistrict,
        ),
      ),
    );
  }

  @override
  State<DealerDirectorySheet> createState() => _DealerDirectorySheetState();
}

class _DealerDirectorySheetState extends State<DealerDirectorySheet> {
  final _dealerService = DealerService.instance;
  final _locService = LocationService.instance;

  bool _loading = true;
  String? _error;
  List<DealerModel> _dealers = [];
  UserLocation? _currentLocation;
  double _selectedRadiusKm = 15.0;

  @override
  void initState() {
    super.initState();
    _initLocationAndDealers();
  }

  Future<void> _initLocationAndDealers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      UserLocation loc;
      if (widget.initialLat != null && widget.initialLng != null) {
        loc = UserLocation(
          latitude: widget.initialLat!,
          longitude: widget.initialLng!,
          district: widget.initialDistrict ?? 'Selected District',
          state: 'India',
          isGps: true,
        );
      } else {
        loc = await _locService.getCurrentLocation();
      }

      if (loc.latitude == 0 && loc.longitude == 0) {
        loc = LocationService.defaultLocation;
      }

      final list = await _dealerService.getDealers(
        latitude: loc.latitude,
        longitude: loc.longitude,
        maxRadiusKm: _selectedRadiusKm,
        preferredDistrict: loc.district,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
        _dealers = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load dealers: $e';
        _loading = false;
      });
    }
  }

  Future<void> _reloadDealers() async {
    if (_currentLocation == null || (_currentLocation!.latitude == 0 && _currentLocation!.longitude == 0)) {
      _currentLocation = LocationService.defaultLocation;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _dealerService.getDealers(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        maxRadiusKm: _selectedRadiusKm,
        preferredDistrict: _currentLocation!.district,
      );
      if (!mounted) return;
      setState(() {
        _dealers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _showDistrictPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Agricultural District',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: LocationService.presetDistricts.length,
                itemBuilder: (ctx, i) {
                  final item = LocationService.presetDistricts[i];
                  final isSelected = item.district == _currentLocation?.district;
                  return ListTile(
                    leading: Icon(
                      Icons.location_city_rounded,
                      color: isSelected ? const Color(0xFF2E7D32) : Colors.grey,
                    ),
                    title: Text(
                      '${item.district}, ${item.state}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentLocation = item;
                      });
                      _reloadDealers();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesticide & Fertilizer Dealers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'State Agri Dept & CIBRC Licensed Retailers',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Location and filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _currentLocation?.isGps == true ? Icons.my_location_rounded : Icons.location_on_outlined,
                      size: 18,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentLocation != null
                            ? '${_currentLocation!.district}, ${_currentLocation!.state}'
                            : 'Detecting location...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showDistrictPicker,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Change', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Radius filter chips
                Row(
                  children: [
                    const Text('Radius: ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [15.0, 25.0, 50.0, 100.0].map((radius) {
                            final isSel = _selectedRadiusKm == radius;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('${radius.toInt()} km'),
                                selected: isSel,
                                selectedColor: const Color(0xFF2E7D32),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _selectedRadiusKm = radius);
                                    _reloadDealers();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 12),
            Text('Finding licensed dealers near you...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _reloadDealers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Search'),
              ),
            ],
          ),
        ),
      );
    }

    if (_dealers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined, color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text(
                'No licensed pesticide dealers found within ${_selectedRadiusKm.toInt()} km.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try expanding your radius or select a nearby agricultural market hub.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _selectedRadiusKm = 100.0);
                  _reloadDealers();
                },
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Expand to 100 km'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _dealers.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final dealer = _dealers[i];
        return _DealerCard(
          dealer: dealer,
          onCall: () async {
            final messenger = ScaffoldMessenger.of(context);
            final details = await _dealerService.loadContactDetails(dealer);
            final ok = await _dealerService.callDealer(details.phone);
            if (!ok && mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('A verified phone number is not available for this store.'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
          },
          onDirections: () async {
            final messenger = ScaffoldMessenger.of(context);
            final ok = await _dealerService.getDirections(dealer);
            if (!ok && mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Could not open Google Maps navigation'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _DealerCard extends StatelessWidget {
  final DealerModel dealer;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _DealerCard({
    required this.dealer,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Shop name & distance badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dealer.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          dealer.proprietorName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (dealer.distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        dealer.formattedDistance,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            dealer.isVerified ? 'Verified agricultural dealer' : 'OpenStreetMap listing — unverified',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dealer.isVerified ? const Color(0xFF1565C0) : Colors.orange.shade800,
            ),
          ),
          if (dealer.distanceKm != null)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('Straight-line distance; route distance appears in Maps.', style: TextStyle(fontSize: 10, color: Colors.black54)),
            ),
          const SizedBox(height: 6),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 15, color: Colors.redAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${dealer.address}, ${dealer.district}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // License and rating
          Row(
            children: [
              if (dealer.licenseNumber != null && dealer.licenseNumber!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text(
                        dealer.licenseNumber!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (!dealer.isVerified) ...[
                Text(
                  'Licence status not verified',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
                const SizedBox(width: 8),
              ],
              if (dealer.rating != null && dealer.rating! > 0) ...[
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  dealer.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
              const Spacer(),
              Text(
                dealer.phone.isNotEmpty ? dealer.phone : 'Contact number unavailable',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: dealer.phone.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                  color: dealer.phone.isNotEmpty ? Colors.grey.shade800 : Colors.grey.shade500,
                  fontStyle: dealer.phone.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Available products tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: dealer.products.take(3).map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action Buttons: Call Dealer & Get Directions
          Row(
            children: [
              // Call Dealer Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: dealer.phone.isNotEmpty ? onCall : null,
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Call Dealer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Get Directions Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text('Get Directions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
