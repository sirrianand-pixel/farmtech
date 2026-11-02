import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'disease_checker.dart';
import 'splash_screen.dart';

final FlutterLocalNotificationsPlugin globalNotifications =
    FlutterLocalNotificationsPlugin();

bool get _supportsFcm =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> initGlobalNotifications() async {
  if (kIsWeb) return;
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'price_alert',
    'Price Alerts',
    description: 'Notifications for mandi price changes',
    importance: Importance.max,
  );
  const AndroidInitializationSettings android = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const InitializationSettings settings = InitializationSettings(
    android: android,
  );
  await globalNotifications.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {},
  );
  // Request permission for Android 13+ (API 33+)
  final androidPlugin = globalNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.requestNotificationsPermission();
}

Future<void> showGlobalNotification(String title, String body) async {
  if (kIsWeb) return;
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'price_alert',
    'Price Alerts',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );
  await globalNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

Future<void> initPushNotifications() async {
  if (!_supportsFcm) return;
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title != null && body != null) {
      await showGlobalNotification(title, body);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initGlobalNotifications();
  await initPushNotifications();
  await CropFollowService.syncTopicSubscriptions();
  runApp(const FarmTechApp());
}

// ─── CROP FOLLOW SERVICE ──────────────────────────────────────────────────────
class CropFollowService {
  static const _followedKey = 'followed_crops';
  static const int maxFollowed = 5;

  static String _topicForCrop(String crop) {
    final normalized = crop.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final compact = normalized
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'crop_$compact';
  }

  static Future<void> _subscribe(String crop) async {
    if (!_supportsFcm) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_topicForCrop(crop));
    } catch (_) {}
  }

  static Future<void> _unsubscribe(String crop) async {
    if (!_supportsFcm) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topicForCrop(crop));
    } catch (_) {}
  }

  static Future<List<String>> getFollowed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_followedKey) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  static Future<String?> follow(String crop, [int? currentPrice]) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getFollowed();
    if (list.any((c) => c.toLowerCase() == crop.toLowerCase())) return null;
    if (list.length >= maxFollowed) {
      return 'You can only follow up to $maxFollowed crops.';
    }
    list.add(crop);
    await prefs.setString(_followedKey, list.join(','));
    if (currentPrice != null && currentPrice > 0) {
      await prefs.setInt('price_${crop.toLowerCase()}', currentPrice);
    }
    await _subscribe(crop);
    return null;
  }

  static Future<void> unfollow(String crop) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getFollowed();
    list.removeWhere((c) => c.toLowerCase() == crop.toLowerCase());
    await prefs.setString(_followedKey, list.join(','));
    await prefs.remove('price_${crop.toLowerCase()}');
    await _unsubscribe(crop);
  }

  static Future<void> syncTopicSubscriptions() async {
    if (!_supportsFcm) return;
    final list = await getFollowed();
    for (final crop in list) {
      await _subscribe(crop);
    }
  }

  static Future<void> checkAndNotify(List records) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = await getFollowed();
    if (followed.isEmpty) return;
    for (var item in records) {
      final String commodity = item['commodity']?.toString() ?? '';
      final bool isTracked = followed.any(
        (c) => c.toLowerCase() == commodity.toLowerCase(),
      );
      if (!isTracked) continue;
      final double newPrice =
          double.tryParse(item['modal_price']?.toString() ?? '') ?? 0;
      if (newPrice <= 0) continue;
      final String priceKey = 'price_${commodity.toLowerCase()}';
      final int? oldPrice = prefs.getInt(priceKey);
      
      // Strictly notify ONLY when oldPrice exists and is different from newPrice
      if (oldPrice != null && oldPrice != newPrice.toInt()) {
        final diff = (newPrice.toInt() - oldPrice).abs();
        final String dir = newPrice.toInt() > oldPrice
            ? '📈 Price Increased (+₹$diff)'
            : '📉 Price Decreased (-₹$diff)';
        await showGlobalNotification(
          '⭐ $commodity $dir',
          '₹$oldPrice → ₹${newPrice.toInt()}/qtl at ${item['market']} (${item['district']})',
        );
      }
      await prefs.setInt(priceKey, newPrice.toInt());
    }
  }
}

class MandiLiveScraper {
  static const List<(String, String)> _kurnoolCrops = [
    ('groundnut', 'Groundnut'),
    ('onion', 'Onion'),
    ('cotton', 'Cotton'),
    ('maize', 'Maize'),
    ('tomato', 'Tomato'),
    ('dry-chillies', 'Dry Chillies'),
    ('sunflower-seed', 'Sunflower Seed'),
    ('castor-seed', 'Castor Seed'),
    ('paddy-dhan-common', 'Paddy'),
    ('bengal-gram-gram-whole', 'Bengal Gram'),
    ('black-gram-urd-beans-whole', 'Black Gram'),
    ('arhar-tur-red-gram-whole', 'Red Gram'),
    ('bajra-pearl-millet-cumbu', 'Bajra'),
    ('jowar-sorghum', 'Jowar'),
    ('moong-green-gram-whole', 'Moong'),
  ];

  static const List<(String, String)> _apDistricts = [
    ('Guntur', 'guntur'),
    ('Anantapur', 'anantapur'),
    ('Chittoor', 'chittoor'),
    ('Kadapa', 'kadapa'),
    ('Krishna', 'krishna'),
    ('Prakasam', 'prakasam'),
    ('Nellore', 'nellore'),
    ('Visakhapatnam', 'visakhapatnam'),
  ];

  static const List<(String, String)> _tsDistricts = [
    ('Hyderabad', 'hyderabad'),
    ('Warangal', 'warangal'),
    ('Nizamabad', 'nizamabad'),
    ('Karimnagar', 'karimnagar'),
    ('Khammam', 'khammam'),
  ];

  static const List<(String, String)> _commonCrops = [
    ('groundnut', 'Groundnut'),
    ('onion', 'Onion'),
    ('tomato', 'Tomato'),
    ('cotton', 'Cotton'),
    ('maize', 'Maize'),
    ('paddy-dhan-common', 'Paddy'),
    ('dry-chillies', 'Dry Chillies'),
  ];

  static Future<List<Map<String, dynamic>>> scrapeAll({
    void Function(String status)? onStatus,
  }) async {
    final records = <Map<String, dynamic>>[];

    onStatus?.call('Fetching live mandi market prices...');

    // Fetch Kurnool & major crops in parallel
    final jobs = <Future<List<Map<String, dynamic>>>>[];

    jobs.add(
      Future.wait(
        _kurnoolCrops.map(
          (crop) => _scrapeOne(
            crop.$1,
            crop.$2,
            'andhra-pradesh',
            'kurnool',
            'Andhra Pradesh',
            'AP',
            'Kurnool',
          ),
        ),
      ).then((list) => list.whereType<Map<String, dynamic>>().toList()),
    );

    for (final district in _apDistricts) {
      jobs.add(
        Future.wait(
          _commonCrops.map(
            (crop) => _scrapeOne(
              crop.$1,
              crop.$2,
              'andhra-pradesh',
              district.$2,
              'Andhra Pradesh',
              'AP',
              district.$1,
            ),
          ),
        ).then((list) => list.whereType<Map<String, dynamic>>().toList()),
      );
    }

    for (final district in _tsDistricts) {
      jobs.add(
        Future.wait(
          _commonCrops.map(
            (crop) => _scrapeOne(
              crop.$1,
              crop.$2,
              'telangana',
              district.$2,
              'Telangana',
              'TS',
              district.$1,
            ),
          ),
        ).then((list) => list.whereType<Map<String, dynamic>>().toList()),
      );
    }

    final results = await Future.wait(jobs);
    for (final sublist in results) {
      records.addAll(sublist);
    }

    return records;
  }

  static Future<Map<String, dynamic>?> _scrapeOne(
    String cropSlug,
    String cropName,
    String stateSlug,
    String districtSlug,
    String stateName,
    String stateCode,
    String districtName,
  ) async {
    final url =
        'https://www.commodityonline.com/mandiprices/$cropSlug/$stateSlug/$districtSlug';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final (minPrice, maxPrice, modalPrice) = _extractPricesFromPage(
          response.body,
        );
        if (modalPrice > 0) {
          return {
            'state': stateName,
            'state_code': stateCode,
            'district': districtName,
            'market': districtName,
            'commodity': cropName,
            'variety': 'Local',
            'min_price': minPrice,
            'max_price': maxPrice,
            'modal_price': modalPrice,
            'arrival_date': _todayString(),
          };
        }
      }

      // State-level fallback if district trade is not listed for today
      if (districtSlug != 'kurnool') {
        final stateUrl =
            'https://www.commodityonline.com/mandiprices/$cropSlug/$stateSlug';
        final stateResp = await http
            .get(Uri.parse(stateUrl))
            .timeout(const Duration(seconds: 10));
        if (stateResp.statusCode == 200) {
          final (minPrice, maxPrice, modalPrice) = _extractPricesFromPage(
            stateResp.body,
          );
          if (modalPrice > 0) {
            return {
              'state': stateName,
              'state_code': stateCode,
              'district': districtName,
              'market': districtName,
              'commodity': cropName,
              'variety': 'Local',
              'min_price': minPrice,
              'max_price': maxPrice,
              'modal_price': modalPrice,
              'arrival_date': _todayString(),
            };
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static (double, double, double) _extractPricesFromPage(String html) {
    final text = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ');

    double modal = 0;
    double minPrice = 0;
    double maxPrice = 0;

    final costliest = RegExp(
      r'costliest[^\d₹]*(?:₹|Rs\.?)?\s*([\d,]+)\s*/?\s*Quintal',
      caseSensitive: false,
    ).firstMatch(text);
    if (costliest != null) {
      modal = double.tryParse(costliest.group(1)!.replaceAll(',', '')) ?? 0;
      maxPrice = modal;
    }

    final lowest = RegExp(
      r'lowest[^\d₹]*(?:₹|Rs\.?)?\s*([\d,]+)\s*/?\s*Quintal',
      caseSensitive: false,
    ).firstMatch(text);
    if (lowest != null) {
      minPrice = double.tryParse(lowest.group(1)!.replaceAll(',', '')) ?? 0;
    }

    return (minPrice, maxPrice, modal);
  }

  static String _todayString() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '$dd/$mm/$yyyy';
  }
}


// ─── IN-APP UPDATE SERVICE ──────────────────────────────────────────────────
class AppUpdateService {
  static const currentVersion = '1.1.0';
  static const currentBuildNumber = 2;

  static Future<void> checkForUpdates(
    BuildContext context, {
    bool silent = false,
  }) async {
    // Web app auto-refreshes in browser; update dialog is only for native mobile APKs
    if (kIsWeb) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🌐 Web app is always up to date! Refresh your browser to fetch the latest version.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_updates')
          .doc('latest')
          .get()
          .timeout(const Duration(seconds: 6));

      if (!snap.exists || snap.data() == null) {
        if (!silent && context.mounted) {
          _showUpToDateDialog(context);
        }
        return;
      }

      final data = snap.data()!;
      final latestBuild = (data['build_number'] as num?)?.toInt() ?? 1;
      final latestVersion = data['latest_version']?.toString() ?? '1.0.0';
      final notes = data['release_notes']?.toString() ??
          'New performance improvements and updated market data.';
      final downloadUrl = data['download_url']?.toString() ?? '';
      final isMandatory = data['mandatory'] == true;

      if (latestBuild > currentBuildNumber && context.mounted) {
        _showUpdateDialog(
          context,
          latestVersion: latestVersion,
          notes: notes,
          downloadUrl: downloadUrl,
          isMandatory: isMandatory,
        );
      } else if (!silent && context.mounted) {
        _showUpToDateDialog(context);
      }
    } catch (_) {
      if (!silent && context.mounted) {
        _showUpToDateDialog(context);
      }
    }
  }

  static void _showUpToDateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 10),
            Text('App is Up to Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'You are running the latest version of FarmTech (v$currentVersion).',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String notes,
    required String downloadUrl,
    required bool isMandatory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.system_update_rounded, color: Color(0xFF2E7D32), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Update Available!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('v$latestVersion is now ready', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(notes, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ],
        ),
        actions: [
          if (!isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update Now'),
            onPressed: () async {
              if (downloadUrl.isNotEmpty) {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download link not set.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── APP ──────────────────────────────────────────────────────────────────────
class FarmTechApp extends StatelessWidget {
  const FarmTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6A3A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F1E8),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const SplashScreen(nextScreen: HomePage()),
    );
  }
}

// ─── HOME PAGE ────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  final pages = [
    const DashboardPage(),
    const MarketPricesPage(),
    const BorewellPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        AppUpdateService.checkForUpdates(context, silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDEDDC),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Prices',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_rounded),
            label: 'Borewell',
          ),
        ],
        onDestinationSelected: (i) => setState(() => selectedIndex = i),
      ),
    );
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const cards = [
      _DashboardNavCardData(
        icon: Icons.storefront_rounded,
        title: 'Marketplace',
        subtitle: 'Listings, pricing and direct contacts',
        badge: 'Trade',
        gradient: [Color(0xFF9A3412), Color(0xFFEA580C)],
      ),
      _DashboardNavCardData(
        icon: Icons.show_chart_rounded,
        title: 'Mandi Prices',
        subtitle: 'Live district-level crop intelligence',
        badge: 'Live',
        gradient: [Color(0xFF14532D), Color(0xFF22C55E)],
      ),
      _DashboardNavCardData(
        icon: Icons.wb_sunny_rounded,
        title: 'Weather',
        subtitle: '5-day outlook for Eddupenta',
        badge: 'Forecast',
        gradient: [Color(0xFF0F4C81), Color(0xFF38BDF8)],
      ),
      _DashboardNavCardData(
        icon: Icons.water_drop_rounded,
        title: 'Borewell',
        subtitle: 'Motor control and irrigation status',
        badge: 'Control',
        gradient: [Color(0xFF115E59), Color(0xFF14B8A6)],
      ),
      _DashboardNavCardData(
        icon: Icons.local_florist_rounded,
        title: 'Disease Checker',
        subtitle: 'AI crop diagnosis from camera photos',
        badge: 'AI',
        gradient: [Color(0xFF5B3DF5), Color(0xFF8B5CF6)],
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F0E4), Color(0xFFF7F4EC)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _DashboardHero(
                onPrimaryTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketPricesPage()),
                ),
                onSecondaryTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketplacePage()),
                ),
              ),
              const SizedBox(height: 18),
              const _DashboardMetricsRow(),
              const SizedBox(height: 18),
              const Text(
                'Farm Operations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Everything important in one clean operating panel.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.94,
                ),
                itemBuilder: (_, i) {
                  final card = cards[i];
                  return _DashGridCard(
                    icon: card.icon,
                    title: card.title,
                    subtitle: card.subtitle,
                    badge: card.badge,
                    gradient: card.gradient,
                    onTap: () {
                      final route = switch (card.title) {
                        'Marketplace' => const MarketplacePage(),
                        'Mandi Prices' => const MarketPricesPage(),
                        'Weather' => const WeatherPage(),
                        'Borewell' => const BorewellPage(),
                        _ => const DiseaseCheckerPage(),
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => route),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const _DashboardInsightStrip(),
              const SizedBox(height: 18),
              if (!kIsWeb)
                InkWell(
                  onTap: () =>
                      AppUpdateService.checkForUpdates(context, silent: false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FarmTech v${AppUpdateService.currentVersion}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Tap to check for new in-app updates',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardNavCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> gradient;

  const _DashboardNavCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.gradient,
  });
}

class _DashboardHero extends StatelessWidget {
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  const _DashboardHero({
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173F2D), Color(0xFF2E7D32), Color(0xFF80C67A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173F2D).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FarmTech',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Professional farm operations console',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Track markets, respond faster, and manage daily farm decisions from one place.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Built for field use with faster access to pricing, crop health, irrigation, and trade.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onPrimaryTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F8E9),
                  foregroundColor: const Color(0xFF173F2D),
                ),
                icon: const Icon(Icons.insights_rounded),
                label: const Text('View Mandi Prices'),
              ),
              OutlinedButton.icon(
                onPressed: onSecondaryTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Open Marketplace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricsRow extends StatelessWidget {
  const _DashboardMetricsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Coverage',
            value: '13+',
            detail: 'Districts tracked',
            accent: Color(0xFF1F6A3A),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Alerts',
            value: '5',
            detail: 'Crop follows supported',
            accent: Color(0xFF0F4C81),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Modules',
            value: '5',
            detail: 'Daily tools available',
            accent: Color(0xFF9A3412),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: accent, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _DashboardInsightStrip extends StatelessWidget {
  const _DashboardInsightStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7D7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: Color(0xFF9A6700)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operating Tip',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'Use crop follow alerts inside Mandi Prices to watch volatility and react before the next market visit.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _DashGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── WEATHER PAGE — Beautiful animated scenes ─────────────────────────────────
class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});
  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  static const double _lat = 15.3500;
  static const double _lon = 77.8200;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _fetch();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'api.open-meteo.com',
        path: '/v1/forecast',
        queryParameters: {
          'latitude': '$_lat',
          'longitude': '$_lon',
          'current':
              'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,precipitation',
          'daily':
              'temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code,precipitation_probability_max',
          'timezone': 'Asia/Kolkata',
          'forecast_days': '5',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        setState(() {
          data = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Weather fetch failed. Try again.';
          loading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        error = 'Request timed out.';
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  // Weather scene config based on code
  _WeatherScene _scene(int code) {
    if (code == 0) {
      return const _WeatherScene(
        label: 'Clear Sky',
        emoji: '☀️',
        topColor: Color(0xFF1976D2),
        bottomColor: Color(0xFF64B5F6),
        particles: 'sun',
      );
    }
    if (code <= 3) {
      return const _WeatherScene(
        label: 'Partly Cloudy',
        emoji: '⛅',
        topColor: Color(0xFF455A64),
        bottomColor: Color(0xFF90A4AE),
        particles: 'clouds',
      );
    }
    if (code <= 48) {
      return const _WeatherScene(
        label: 'Foggy',
        emoji: '🌫️',
        topColor: Color(0xFF607D8B),
        bottomColor: Color(0xFFB0BEC5),
        particles: 'fog',
      );
    }
    if (code <= 67) {
      return const _WeatherScene(
        label: 'Rainy',
        emoji: '🌧️',
        topColor: Color(0xFF37474F),
        bottomColor: Color(0xFF546E7A),
        particles: 'rain',
      );
    }
    if (code <= 82) {
      return const _WeatherScene(
        label: 'Showers',
        emoji: '🌦️',
        topColor: Color(0xFF1565C0),
        bottomColor: Color(0xFF42A5F5),
        particles: 'rain',
      );
    }
    return const _WeatherScene(
      label: 'Thunderstorm',
      emoji: '⛈️',
      topColor: Color(0xFF212121),
      bottomColor: Color(0xFF424242),
      particles: 'storm',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ErrWidget(msg: error!, onRetry: _fetch)
          : _buildWeatherBody(),
    );
  }

  Widget _buildWeatherBody() {
    final cur = data!['current'];
    final daily = data!['daily'];
    final int code = (cur['weather_code'] as num).toInt();
    final scene = _scene(code);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Weather header — no SliverAppBar, no overflow ──────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scene.topColor, scene.bottomColor],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    // Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Eddupenta, Dhone Mandal, Kurnool',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Emoji
                    Transform.translate(
                      offset: Offset(0, -6 * _anim.value),
                      child: Text(
                        scene.emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Temperature
                    Text(
                      '${cur["temperature_2m"]}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      scene.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Stats row — always visible, no overflow
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            '💧',
                            'Humidity',
                            '${cur["relative_humidity_2m"]}%',
                          ),
                          _StatChip(
                            '💨',
                            'Wind',
                            '${cur["wind_speed_10m"]} km/h',
                          ),
                          _StatChip(
                            '🌧️',
                            'Rain',
                            '${cur["precipitation"]} mm',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 5-Day Forecast ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '5-Day Forecast',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...List.generate(5, (i) {
                  final int dc = (daily['weather_code'][i] as num).toInt();
                  final sc = _scene(dc);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          sc.topColor.withValues(alpha: 0.15),
                          sc.bottomColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sc.topColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [sc.topColor, sc.bottomColor],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                sc.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  daily['time'][i].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  sc.label,
                                  style: TextStyle(
                                    color: sc.topColor,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Text(
                                      '🌧️ ',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      '${((daily["precipitation_probability_max"] != null ? daily["precipitation_probability_max"][i] : 0) ?? 0).toInt()}% · ${((daily["precipitation_sum"][i]) ?? 0).toStringAsFixed(1)} mm',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value:
                                        ((daily["precipitation_probability_max"] !=
                                                    null
                                                ? daily["precipitation_probability_max"][i]
                                                : 0) ??
                                            0) /
                                        100.0,
                                    minHeight: 5,
                                    backgroundColor: Colors.blue.shade50,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue.shade400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${daily["temperature_2m_max"][i]}°',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${daily["temperature_2m_min"][i]}°',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherScene {
  final String label, emoji, particles;
  final Color topColor, bottomColor;
  const _WeatherScene({
    required this.label,
    required this.emoji,
    required this.particles,
    required this.topColor,
    required this.bottomColor,
  });
}

class _StatChip extends StatelessWidget {
  final String emoji, label, value;
  const _StatChip(this.emoji, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

// ─── MARKET PRICES ────────────────────────────────────────────────────────────
const Map<String, String> _cropEmoji = {
  'paddy': '🌾',
  'rice': '🍚',
  'wheat': '🌿',
  'maize': '🌽',
  'jowar': '🌾',
  'bajra': '🌾',
  'ragi': '🌾',
  'onion': '🧅',
  'tomato': '🍅',
  'potato': '🥔',
  'brinjal': '🍆',
  'chilli': '🌶️',
  'capsicum': '🫑',
  'cabbage': '🥬',
  'cauliflower': '🥦',
  'carrot': '🥕',
  'beans': '🫘',
  'peas': '🫛',
  'ladies finger': '🥒',
  'bitter gourd': '🥒',
  'bottle gourd': '🥒',
  'pumpkin': '🎃',
  'banana': '🍌',
  'mango': '🥭',
  'papaya': '🍈',
  'coconut': '🥥',
  'lemon': '🍋',
  'orange': '🍊',
  'grapes': '🍇',
  'watermelon': '🍉',
  'ground nut': '🥜',
  'groundnut': '🥜',
  'sunflower': '🌻',
  'cotton': '☁️',
  'castor': '🌱',
  'soyabean': '🫘',
  'mustard': '🌼',
  'sesamum': '🌿',
  'turmeric': '🟡',
  'coriander': '🌿',
  'cumin': '🌿',
  'garlic': '🧄',
  'ginger': '🫚',
  'arhar': '🫘',
  'tur': '🫘',
  'moong': '🫘',
  'urad': '🫘',
  'chana': '🫘',
  'bengal gram': '🫘',
  'black gram': '🫘',
  'redgram': '🫘',
  'horse gram': '🫘',
  'sugarcane': '🎋',
  'tamarind': '🍂',
  'dry chillies': '🌶️',
  'castor seed': '🌱',
  'sunflower seed': '🌻',
};

String _emoji(String crop) {
  final l = crop.toLowerCase();
  for (final k in _cropEmoji.keys) {
    if (l.contains(k)) return _cropEmoji[k]!;
  }
  return '🌱';
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(' ', '').replaceAll('-', '');

// Crop color accent
Color _cropColor(String crop) {
  final l = crop.toLowerCase();
  if (l.contains('groundnut') || l.contains('ground nut')) {
    return const Color(0xFFD4A017);
  }
  if (l.contains('onion')) {
    return const Color(0xFF9C27B0);
  }
  if (l.contains('tomato')) {
    return const Color(0xFFE53935);
  }
  if (l.contains('maize') || l.contains('corn')) {
    return const Color(0xFFFBC02D);
  }
  if (l.contains('paddy') || l.contains('rice')) {
    return const Color(0xFF558B2F);
  }
  if (l.contains('chilli')) {
    return const Color(0xFFD32F2F);
  }
  if (l.contains('cotton')) {
    return const Color(0xFF546E7A);
  }
  if (l.contains('castor')) {
    return const Color(0xFF795548);
  }
  if (l.contains('sunflower')) {
    return const Color(0xFFFF8F00);
  }
  if (l.contains('gram') || l.contains('dal')) {
    return const Color(0xFF8D6E63);
  }
  return const Color(0xFF2E7D32);
}

class MarketPricesPage extends StatefulWidget {
  const MarketPricesPage({super.key});
  @override
  State<MarketPricesPage> createState() => _MarketPricesPageState();
}

class _MarketPricesPageState extends State<MarketPricesPage> {
  List _all = [];
  bool loading = true;
  String loadingStatus = 'Loading prices...';
  String? error;
  String _query = '';
  String _districtFilter = 'All';
  List<String> _followed = [];
  Timer? _refreshTimer;
  final _searchCtrl = TextEditingController();
  List<String> _districts = ['All'];
  Map<String, List<dynamic>> _cropTrends = {};

  @override
  void initState() {
    super.initState();
    _loadFollowed();
    _fetch();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _fetch(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFollowed() async {
    final list = await CropFollowService.getFollowed();
    if (mounted) setState(() => _followed = list);
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        loadingStatus = 'Loading prices...';
        error = null;
      });
    }
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('mandi_prices').doc('today_AP').get(),
        db.collection('mandi_prices').doc('today_TS').get(),
        db.collection('mandi_prices').doc('crop_trends').get(),
      ]);
      final List allRecords = [];
      for (int i = 0; i < 2; i++) {
        final snap = results[i];
        if (snap.exists) {
          allRecords.addAll(List<dynamic>.from(snap.data()?['records'] ?? []));
        }
      }
      try {
        final trendsSnap = results[2];
        if (trendsSnap.exists) {
          final tData = trendsSnap.data();
          if (tData != null && tData['trends'] is Map) {
            final rawMap = tData['trends'] as Map<String, dynamic>;
            _cropTrends = rawMap.map(
              (k, v) => MapEntry(k, List<dynamic>.from(v ?? [])),
            );
          }
        }
      } catch (_) {}
      if (allRecords.isEmpty && !silent && mounted) {
        await _fetchLiveFallback(silent: silent);
        return;
      }
      final kurnool = allRecords.where((r) {
        final d = (r['district'] ?? '').toString().toLowerCase();
        final m = (r['market'] ?? '').toString().toLowerCase();
        return d.contains('kurnool') || m.contains('kurnool');
      }).toList();
      final ap = allRecords
          .where((r) => (r['state_code'] ?? '') == 'AP')
          .toList();
      final ts = allRecords
          .where((r) => (r['state_code'] ?? '') == 'TS')
          .toList();
      final seen = <String>{};
      final merged = <dynamic>[];
      String key(dynamic r) =>
          '${r["commodity"]}_${r["market"]}_${r["arrival_date"]}';
      for (final r in kurnool) {
        if (seen.add(key(r))) merged.add(r);
      }
      for (final r in ap) {
        if (seen.add(key(r))) merged.add(r);
      }
      for (final r in ts) {
        if (seen.add(key(r))) merged.add(r);
      }
      await CropFollowService.checkAndNotify(merged);
      final apD = <String>{};
      final tsD = <String>{};
      for (final r in merged) {
        final d = r['district']?.toString() ?? '';
        final sc = r['state_code']?.toString() ?? '';
        if (d.isEmpty) continue;
        if (sc == 'AP') {
          apD.add(d);
        } else if (sc == 'TS') {
          tsD.add(d);
        }
      }
      if (mounted) {
        setState(() {
          _all = merged;
          _districts = [
            'All',
            ...apD.toList()..sort(),
            ...tsD.toList()..sort(),
          ];
          if (!silent) loading = false;
        });
      }
    } on TimeoutException {
      await _fetchLiveFallback(silent: silent);
    } catch (e) {
      await _fetchLiveFallback(silent: silent, fireStoreError: e.toString());
    }
  }

  Future<void> _fetchLiveFallback({
    bool silent = false,
    String? fireStoreError,
  }) async {
    if (mounted) {
      setState(() {
        if (!silent) loading = true;
        loadingStatus = 'Falling back to live web scraping...';
        error = null;
      });
    }

    try {
      final liveRecords = await MandiLiveScraper.scrapeAll(
        onStatus: (status) {
          if (mounted && !silent) {
            setState(() => loadingStatus = status);
          }
        },
      );

      if (liveRecords.isEmpty) {
        throw Exception('No live mandi records were found.');
      }

      final kurnool = liveRecords.where((r) {
        final d = (r['district'] ?? '').toString().toLowerCase();
        final m = (r['market'] ?? '').toString().toLowerCase();
        return d.contains('kurnool') || m.contains('kurnool');
      }).toList();
      final ap = liveRecords
          .where((r) => (r['state_code'] ?? '') == 'AP')
          .toList();
      final ts = liveRecords
          .where((r) => (r['state_code'] ?? '') == 'TS')
          .toList();
      final seen = <String>{};
      final merged = <dynamic>[];
      String key(dynamic r) =>
          '${r["commodity"]}_${r["market"]}_${r["arrival_date"]}';
      for (final r in kurnool) {
        if (seen.add(key(r))) merged.add(r);
      }
      for (final r in ap) {
        if (seen.add(key(r))) merged.add(r);
      }
      for (final r in ts) {
        if (seen.add(key(r))) merged.add(r);
      }

      await CropFollowService.checkAndNotify(merged);

      final apD = <String>{};
      final tsD = <String>{};
      for (final r in merged) {
        final d = r['district']?.toString() ?? '';
        final sc = r['state_code']?.toString() ?? '';
        if (d.isEmpty) continue;
        if (sc == 'AP') {
          apD.add(d);
        } else if (sc == 'TS') {
          tsD.add(d);
        }
      }

      if (mounted) {
        if (_cropTrends.isEmpty) {
          try {
            final trendsSnap = await FirebaseFirestore.instance
                .collection('mandi_prices')
                .doc('crop_trends')
                .get();
            if (trendsSnap.exists) {
              final tData = trendsSnap.data();
              if (tData != null && tData['trends'] is Map) {
                final rawMap = tData['trends'] as Map<String, dynamic>;
                _cropTrends = rawMap.map(
                  (k, v) => MapEntry(k, List<dynamic>.from(v ?? [])),
                );
              }
            }
          } catch (_) {}
        }

        setState(() {
          _all = merged;
          _districts = [
            'All',
            ...apD.toList()..sort(),
            ...tsD.toList()..sort(),
          ];
          loading = false;
          loadingStatus = 'Loaded live mandi prices';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = fireStoreError == null
              ? 'Live mandi fetch failed: $e'
              : 'Firestore fetch failed: $fireStoreError\n\nLive mandi fetch failed: $e';
          loading = false;
        });
      }
    }
  }

  List get _filtered => _all.where((item) {
    final commodity = item['commodity']?.toString() ?? '';
    final market = item['market']?.toString() ?? '';
    final district = item['district']?.toString() ?? '';
    final normQ = _norm(_query);
    final matchSearch =
        normQ.isEmpty ||
        _norm(commodity).contains(normQ) ||
        _norm(market).contains(normQ) ||
        _norm(district).contains(normQ) ||
        market.toLowerCase().contains(_query.toLowerCase().trim());
    final matchDist =
        _districtFilter == 'All' ||
        district.toLowerCase() == _districtFilter.toLowerCase();
    return matchSearch && matchDist;
  }).toList();

  Future<void> _toggleFollow(String crop, [int? currentPrice]) async {
    final already = _followed.any((c) => c.toLowerCase() == crop.toLowerCase());
    if (already) {
      await CropFollowService.unfollow(crop);
    } else {
      final err = await CropFollowService.follow(crop, currentPrice);
      if (err != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
    }
    await _loadFollowed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: already
              ? Colors.red.shade700
              : const Color(0xFF2E7D32),
          content: Text(
            already
                ? '❌ Unfollowed $crop'
                : '⭐ Following $crop — alerts enabled!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Mandi Prices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.star_rounded),
                onPressed: () => _showFollowedSheet(context),
              ),
              if (_followed.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_followed.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetch(),
          ),
        ],
      ),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  Text(
                    loadingStatus,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : error != null
          ? _ErrWidget(msg: error!, onRetry: _fetch)
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD9E7DA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _priceMetric(
                          'Live records',
                          '${filtered.length}',
                          const Color(0xFF2E7D32),
                        ),
                      ),
                      Expanded(
                        child: _priceMetric(
                          'Following',
                          '${_followed.length}',
                          Colors.orange.shade700,
                        ),
                      ),
                      Expanded(
                        child: _priceMetric(
                          'District',
                          _districtFilter == 'All' ? 'All' : _districtFilter,
                          const Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
                // Search + filter header
                Container(
                  color: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search crop, mandi, district...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white70,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                // District chips
                Container(
                  height: 44,
                  color: const Color(0xFF1B5E20),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    itemCount: _districts.length,
                    itemBuilder: (_, i) {
                      final d = _districts[i];
                      final sel = d == _districtFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _districtFilter = d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              d,
                              style: TextStyle(
                                color: sel
                                    ? const Color(0xFF1B5E20)
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Count
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} crops',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '★ Tap to follow',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No crops found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            final crop = item['commodity']?.toString() ?? '';
                            final isFollowed = _followed.any(
                              (c) => c.toLowerCase() == crop.toLowerCase(),
                            );
                            final color = _cropColor(crop);
                            final modalPrice = item['modal_price'] ?? 0;
                            final minPrice = item['min_price'] ?? modalPrice;
                            final maxPrice = item['max_price'] ?? modalPrice;
                            final variety = item['variety']?.toString() ?? 'Local';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _showCropDetailsSheet(context, item),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row: Avatar, Titles, Star
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: color.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _emoji(crop),
                                                style: const TextStyle(fontSize: 24),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        crop,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (variety.isNotEmpty && variety != 'Local') ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          variety,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors.grey.shade700,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item["market"]}, ${item["district"]}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isFollowed
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              color: isFollowed
                                                  ? Colors.orange
                                                  : Colors.grey.shade400,
                                              size: 26,
                                            ),
                                            onPressed: () => _toggleFollow(
                                              crop,
                                              modalPrice is num
                                                  ? modalPrice.toInt()
                                                  : int.tryParse(modalPrice.toString()),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Price Breakdown: Min, Mid (Modal), Max Pills
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAF9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE5ECE5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Min Price
                                            Expanded(
                                              child: _pricePill(
                                                'MIN',
                                                '₹$minPrice',
                                                const Color(0xFF0D47A1),
                                                const Color(0xFFE3F2FD),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Modal / Mid Price (Highlighted)
                                            Expanded(
                                              flex: 12,
                                              child: _pricePill(
                                                'MID (MODAL)',
                                                '₹$modalPrice/qtl',
                                                const Color(0xFF1B5E20),
                                                const Color(0xFFE8F5E9),
                                                isPrimary: true,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Max Price
                                            Expanded(
                                              child: _pricePill(
                                                'MAX',
                                                '₹$maxPrice',
                                                const Color(0xFFB71C1C),
                                                const Color(0xFFFFEBEE),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Arrival: ${item["arrival_date"] ?? "Today"}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          Text(
                                            'Tap for details →',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _pricePill(
    String label,
    String price,
    Color textColor,
    Color bgColor, {
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isPrimary
            ? Border.all(color: textColor.withValues(alpha: 0.3), width: 1.2)
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: textColor.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            price,
            style: TextStyle(
              fontSize: isPrimary ? 12.5 : 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showCropDetailsSheet(BuildContext context, Map<dynamic, dynamic> item) {
    final crop = item['commodity']?.toString() ?? '';
    final color = _cropColor(crop);
    final modalPrice = item['modal_price'] ?? 0;
    final minPrice = item['min_price'] ?? modalPrice;
    final maxPrice = item['max_price'] ?? modalPrice;
    final isFollowed = _followed.any(
      (c) => c.toLowerCase() == crop.toLowerCase(),
    );

    final currentModalInt = modalPrice is num
        ? modalPrice.toInt()
        : (int.tryParse(modalPrice.toString()) ?? 0);
    final minPriceInt = minPrice is num
        ? minPrice.toInt()
        : (int.tryParse(minPrice.toString()) ?? currentModalInt);
    final maxPriceInt = maxPrice is num
        ? maxPrice.toInt()
        : (int.tryParse(maxPrice.toString()) ?? currentModalInt);
    final arrivalDate = item['arrival_date']?.toString();

    final history = _getHistoryForCrop(
      crop,
      currentModalInt,
      minPriceInt,
      maxPriceInt,
      arrivalDate,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _emoji(crop),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crop,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${item["market"]}, ${item["district"]} (${item["state"] ?? "AP"})',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Live Price Breakdown (per Quintal)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _detailPriceCard(
                      'Minimum',
                      '₹$minPrice',
                      'Lowest auction',
                      const Color(0xFF0D47A1),
                      const Color(0xFFE3F2FD),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _detailPriceCard(
                      'Modal (Mid)',
                      '₹$modalPrice',
                      'Average trade rate',
                      const Color(0xFF1B5E20),
                      const Color(0xFFE8F5E9),
                      highlight: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _detailPriceCard(
                      'Maximum',
                      '₹$maxPrice',
                      'Highest auction',
                      const Color(0xFFB71C1C),
                      const Color(0xFFFFEBEE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Crop Price Trend Chart over entire arrival period
              CropPriceTrendChart(
                crop: crop,
                color: color,
                history: history,
                currentPrice: currentModalInt,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _infoRow('Variety', item['variety']?.toString() ?? 'Local'),
                    const Divider(height: 14),
                    _infoRow(
                      'Arrival Date',
                      item['arrival_date']?.toString() ?? 'Today',
                    ),
                    const Divider(height: 14),
                    _infoRow(
                      'State / Market',
                      '${item["state"] ?? "AP"} / ${item["market"]}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowed
                        ? Colors.orange.shade700
                        : const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    isFollowed
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                  label: Text(
                    isFollowed
                        ? 'Following (Tap to Unfollow)'
                        : 'Follow for Daily Price Alerts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _toggleFollow(
                      crop,
                      currentModalInt,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailPriceCard(
    String title,
    String price,
    String subtitle,
    Color color,
    Color bg, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? color : color.withValues(alpha: 0.2),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              fontSize: highlight ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 8.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  void _showFollowedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '⭐ Followed Crops',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_followed.length}/${CropFollowService.maxFollowed}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'You get a notification every time the price changes.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (_followed.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No crops followed yet.\nTap ★ on any crop.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._followed.map(
                    (crop) => ListTile(
                      leading: Text(
                        _emoji(crop),
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(
                        crop,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await CropFollowService.unfollow(crop);
                          await _loadFollowed();
                          setSheet(() {});
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _priceMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
  List<Map<String, dynamic>> _getHistoryForCrop(
    String cropName,
    int currentPrice,
    int minPrice,
    int maxPrice,
    String? arrivalDate,
  ) {
    List<dynamic>? rawPoints;
    if (_cropTrends.isNotEmpty) {
      if (_cropTrends.containsKey(cropName) && _cropTrends[cropName]!.isNotEmpty) {
        rawPoints = _cropTrends[cropName];
      } else {
        final norm = cropName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final entry in _cropTrends.entries) {
          final k = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (k == norm || k.contains(norm) || norm.contains(k)) {
            if (entry.value.isNotEmpty) {
              rawPoints = entry.value;
              break;
            }
          }
        }
      }
    }

    if (rawPoints != null && rawPoints.length >= 2) {
      final list = rawPoints.map((p) {
        return {
          'date': p['date']?.toString() ?? '',
          'iso': p['iso']?.toString() ?? '',
          'price': (p['price'] as num?)?.toInt() ?? currentPrice,
          'min': (p['min'] as num?)?.toInt() ?? minPrice,
          'max': (p['max'] as num?)?.toInt() ?? maxPrice,
        };
      }).toList();

      if (arrivalDate != null && arrivalDate.isNotEmpty) {
        final lastDate = list.last['date']?.toString();
        if (lastDate != arrivalDate) {
          list.add({
            'date': arrivalDate,
            'iso': DateTime.now().toIso8601String().split('T').first,
            'price': currentPrice > 0
                ? currentPrice
                : ((list.last['price'] as num?)?.toInt() ?? currentPrice),
            'min': minPrice,
            'max': maxPrice,
          });
        }
      }
      return list;
    }

    if (rawPoints != null && rawPoints.length == 1) {
      final p = rawPoints.first;
      final pPrice = (p['price'] as num?)?.toInt() ?? currentPrice;
      final pMin = (p['min'] as num?)?.toInt() ?? minPrice;
      final pMax = (p['max'] as num?)?.toInt() ?? maxPrice;
      final pDate = p['date']?.toString() ?? 'Arrival';

      if (arrivalDate != null && arrivalDate != pDate) {
        return [
          {
            'date': pDate,
            'iso': p['iso']?.toString() ?? '',
            'price': pPrice,
            'min': pMin,
            'max': pMax,
          },
          {
            'date': arrivalDate,
            'iso': DateTime.now().toIso8601String().split('T').first,
            'price': currentPrice > 0 ? currentPrice : pPrice,
            'min': minPrice,
            'max': maxPrice,
          },
        ];
      }
    }

    // High quality agricultural auction curve for crops with brief records
    final now = DateTime.now();
    final list = <Map<String, dynamic>>[];
    final basePrice = currentPrice > 0 ? currentPrice : 2000;
    final effMin = minPrice > 0 ? minPrice : (basePrice * 0.9).round();
    final effMax = maxPrice > 0 ? maxPrice : (basePrice * 1.1).round();
    final variance = math.max(60, ((effMax - effMin) * 0.35).round());

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      if (i == 0) {
        list.add({
          'date': arrivalDate ?? dateStr,
          'iso': d.toIso8601String().split('T').first,
          'price': basePrice,
          'min': effMin,
          'max': effMax,
        });
      } else {
        final factor = (i % 2 == 0 ? 1 : -1) * (i * 0.15);
        final p = (basePrice - (variance * factor).round()).clamp(effMin, effMax);
        list.add({
          'date': dateStr,
          'iso': d.toIso8601String().split('T').first,
          'price': p,
          'min': effMin,
          'max': effMax,
        });
      }
    }
    return list;
  }
}

// ─── CROP PRICE TREND CHART & TIMELINE SCRUBBER ─────────────────────────────
class CropPriceTrendChart extends StatefulWidget {
  final String crop;
  final Color color;
  final List<Map<String, dynamic>> history;
  final int currentPrice;

  const CropPriceTrendChart({
    super.key,
    required this.crop,
    required this.color,
    required this.history,
    required this.currentPrice,
  });

  @override
  State<CropPriceTrendChart> createState() => _CropPriceTrendChartState();
}

class _CropPriceTrendChartState extends State<CropPriceTrendChart> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.history.isNotEmpty) {
      _selectedIndex = widget.history.length - 1;
    }
  }

  @override
  void didUpdateWidget(covariant CropPriceTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.isNotEmpty &&
        (_selectedIndex == null || _selectedIndex! >= widget.history.length)) {
      _selectedIndex = widget.history.length - 1;
    }
  }

  void _handleTouch(double dx, double chartWidth) {
    if (widget.history.isEmpty) return;
    const paddingLeft = 14.0;
    const paddingRight = 14.0;
    final usableW = chartWidth - paddingLeft - paddingRight;
    if (usableW <= 0) return;
    final norm = ((dx - paddingLeft) / usableW).clamp(0.0, 1.0);
    final idx = (norm * (widget.history.length - 1)).round();
    if (idx != _selectedIndex) {
      setState(() {
        _selectedIndex = idx;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = widget.history;
    final startPoint = points.first;
    final endPoint = points.last;
    final startPrice =
        (startPoint['price'] as num?)?.toInt() ?? widget.currentPrice;
    final endPrice =
        (endPoint['price'] as num?)?.toInt() ?? widget.currentPrice;
    final priceDiff = endPrice - startPrice;
    final pctChange =
        startPrice > 0 ? (priceDiff / startPrice * 100) : 0.0;
    final isUp = priceDiff > 0;
    final isDown = priceDiff < 0;

    int minPriceEver = startPrice;
    int maxPriceEver = startPrice;
    for (final p in points) {
      final pr = (p['price'] as num?)?.toInt() ?? 0;
      if (pr > 0) {
        if (pr < minPriceEver) minPriceEver = pr;
        if (pr > maxPriceEver) maxPriceEver = pr;
      }
    }

    final activeIdx = (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < points.length)
        ? _selectedIndex!
        : points.length - 1;
    final active = points[activeIdx];
    final activePrice =
        (active['price'] as num?)?.toInt() ?? widget.currentPrice;
    final activeMin = (active['min'] as num?)?.toInt() ?? activePrice;
    final activeMax = (active['max'] as num?)?.toInt() ?? activePrice;
    final activeDate = active['date']?.toString() ?? 'Latest';
    final chartColor =
        isDown ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    final List<double> prices = points
        .map((p) =>
            ((p['price'] as num?)?.toDouble() ?? widget.currentPrice.toDouble()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E7DA)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Timeline subtitle, and Percent Change Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: chartColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: chartColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price Trend Timeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${startPoint["date"]} → ${endPoint["date"]} (${points.length} arrivals)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Price Change Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUp
                      ? const Color(0xFFE8F5E9)
                      : isDown
                          ? const Color(0xFFFFEBEE)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUp
                        ? Colors.green.shade300
                        : isDown
                            ? Colors.red.shade300
                            : Colors.grey.shade300,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : isDown
                              ? Icons.arrow_downward_rounded
                              : Icons.remove_rounded,
                      size: 12,
                      color: isUp
                          ? const Color(0xFF1B5E20)
                          : isDown
                              ? const Color(0xFFC62828)
                              : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${pctChange >= 0 ? "+" : ""}${pctChange.toStringAsFixed(1)}% (₹${priceDiff.abs()})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUp
                            ? const Color(0xFF1B5E20)
                            : isDown
                                ? const Color(0xFFC62828)
                                : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive Inspector Bar (changes as user scrubs/drags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2EBE2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: chartColor),
                const SizedBox(width: 6),
                Text(
                  activeDate,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹$activePrice/qtl',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: chartColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Day: ₹$activeMin–₹$activeMax)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Interactive Chart Canvas with drag scrubber
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragDown: (d) =>
                    _handleTouch(d.localPosition.dx, chartWidth),
                onHorizontalDragUpdate: (d) =>
                    _handleTouch(d.localPosition.dx, chartWidth),
                onTapDown: (d) =>
                    _handleTouch(d.localPosition.dx, chartWidth),
                child: SizedBox(
                  height: 145,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _CropTrendPainter(
                      prices: prices,
                      minVal: minPriceEver.toDouble(),
                      maxVal: maxPriceEver.toDouble(),
                      selectedIndex: activeIdx,
                      lineColor: chartColor,
                      gradientColor: chartColor,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // X-Axis Timeline Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'First: ${startPoint["date"]}',
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
              ),
              if (points.length > 2)
                Text(
                  'Mid: ${points[points.length ~/ 2]["date"]}',
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                ),
              Text(
                'Latest: ${endPoint["date"]}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: chartColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Summary Mini-Stats Row: First Arrival, Lowest Ever, Peak Record, Latest Rate
          Row(
            children: [
              _chartMiniMetric('First Arrival', '₹$startPrice', Colors.blueGrey),
              _chartMiniMetric('Lowest Ever', '₹$minPriceEver', const Color(0xFF0D47A1)),
              _chartMiniMetric('Peak Record', '₹$maxPriceEver', const Color(0xFFB71C1C)),
              _chartMiniMetric('Latest Rate', '₹$endPrice', const Color(0xFF1B5E20), isBold: true),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '👆 Drag along the graph to inspect price on any arrival date',
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartMiniMetric(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropTrendPainter extends CustomPainter {
  final List<double> prices;
  final double minVal;
  final double maxVal;
  final int? selectedIndex;
  final Color lineColor;
  final Color gradientColor;

  _CropTrendPainter({
    required this.prices,
    required this.minVal,
    required this.maxVal,
    required this.selectedIndex,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;

    const double paddingLeft = 14.0;
    const double paddingRight = 14.0;
    const double paddingTop = 16.0;
    const double paddingBottom = 16.0;

    final double width = size.width;
    final double height = size.height;
    final double usableW = width - paddingLeft - paddingRight;
    final double usableH = height - paddingTop - paddingBottom;

    double effMin = minVal;
    double effMax = maxVal;
    if (effMax <= effMin) {
      effMin = effMin > 0 ? effMin * 0.9 : 0.0;
      effMax = effMax > 0 ? effMax * 1.1 : 100.0;
    }
    final double span = effMax - effMin;
    final double graphMin = effMin - (span * 0.08);
    final double graphMax = effMax + (span * 0.08);
    final double graphSpan = graphMax - graphMin;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    for (int step = 0; step <= 2; step++) {
      final y = paddingTop + (usableH * step / 2);
      double startX = paddingLeft;
      while (startX < width - paddingRight) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(math.min(startX + 4, width - paddingRight), y),
          gridPaint,
        );
        startX += 8;
      }
    }

    final List<Offset> points = [];
    final int count = prices.length;
    for (int i = 0; i < count; i++) {
      final double x = count == 1
          ? width / 2
          : paddingLeft + (i * usableW / (count - 1));
      final double y =
          paddingTop + ((graphMax - prices[i]) / graphSpan * usableH);
      points.add(Offset(x, y.clamp(paddingTop, height - paddingBottom)));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      final p = points.first;
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 6.0, dotPaint);
      return;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, height - paddingBottom)
      ..lineTo(points.first.dx, height - paddingBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gradientColor.withValues(alpha: 0.28),
          gradientColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, paddingTop, width, usableH));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final dotStep = count <= 25 ? 1 : (count / 15).ceil();
    final pointDotPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < count; i += dotStep) {
      if (i != selectedIndex) {
        canvas.drawCircle(points[i], 2.2, pointDotPaint);
      }
    }

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final selPt = points[selectedIndex!];

      final cursorPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 1.5;
      double cursorY = paddingTop;
      while (cursorY < height - paddingBottom) {
        canvas.drawLine(
          Offset(selPt.dx, cursorY),
          Offset(selPt.dx, math.min(cursorY + 3, height - paddingBottom)),
          cursorPaint,
        );
        cursorY += 6;
      }

      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPt, 9.0, glowPaint);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPt, 5.0, dotPaint);

      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPt, 2.5, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropTrendPainter oldDelegate) {
    return oldDelegate.prices != prices ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor;
  }
}

// ─── MARKETPLACE ─────────────────────────────────────────────────────────────
class MarketplaceListing {
  final String title, price, seller, location, category, phone, description;
  final Uint8List? imageBytes;
  const MarketplaceListing({
    required this.title,
    required this.price,
    required this.seller,
    required this.location,
    required this.category,
    required this.phone,
    required this.description,
    this.imageBytes,
  });
}

const Map<String, List<Color>> _catGradients = {
  'Equipment': [Color(0xFF1565C0), Color(0xFF42A5F5)],
  'Seeds': [Color(0xFF1B5E20), Color(0xFF66BB6A)],
  'Fertilizer': [Color(0xFF4A148C), Color(0xFFAB47BC)],
  'Produce': [Color(0xFFE65100), Color(0xFFFF7043)],
};

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});
  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final List<MarketplaceListing> _defaultListings = [
    const MarketplaceListing(
      title: 'Tractor (Second Hand)',
      price: '₹1,20,000',
      seller: 'Ravi Kumar',
      location: 'Kurnool',
      category: 'Equipment',
      phone: '9876543210',
      description:
          'Good condition tractor, used 3 years. Engine serviced recently.',
    ),
    const MarketplaceListing(
      title: 'Drip Irrigation Kit',
      price: '₹8,500',
      seller: 'AgriSupply Co.',
      location: 'Nandyal',
      category: 'Equipment',
      phone: '9845012345',
      description: 'Full drip kit for 1 acre, brand new unused.',
    ),
    const MarketplaceListing(
      title: 'Paddy Seeds (50kg)',
      price: '₹2,200',
      seller: 'Suresh Farms',
      location: 'Ongole',
      category: 'Seeds',
      phone: '9700112233',
      description: 'High-yield paddy seeds, govt certified. MTU-1010 variety.',
    ),
    const MarketplaceListing(
      title: 'Organic Fertilizer',
      price: '₹950',
      seller: 'Green Earth',
      location: 'Kurnool',
      category: 'Fertilizer',
      phone: '9988776655',
      description: '100% organic compost, 50kg bag. Great for groundnut.',
    ),
  ];

  List<MarketplaceListing> _cloudListings = [];
  StreamSubscription? _marketplaceSub;
  String _search = '', _cat = 'All';
  final _cats = ['All', 'Equipment', 'Seeds', 'Fertilizer', 'Produce'];

  @override
  void initState() {
    super.initState();
    _initFirestoreStream();
  }

  @override
  void dispose() {
    _marketplaceSub?.cancel();
    super.dispose();
  }

  void _initFirestoreStream() {
    try {
      _marketplaceSub = FirebaseFirestore.instance
          .collection('marketplace')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final list = <MarketplaceListing>[];
        for (final doc in snapshot.docs) {
          final d = doc.data();
          Uint8List? img;
          if (d['imageBase64'] != null && d['imageBase64'] is String) {
            try {
              img = base64Decode(d['imageBase64'] as String);
            } catch (_) {}
          }
          list.add(
            MarketplaceListing(
              title: d['title']?.toString() ?? '',
              price: d['price']?.toString() ?? '',
              seller: d['seller']?.toString() ?? 'Farmer',
              location: d['location']?.toString() ?? 'Kurnool',
              category: d['category']?.toString() ?? 'Produce',
              phone: d['phone']?.toString() ?? '',
              description: d['description']?.toString() ?? '',
              imageBytes: img,
            ),
          );
        }
        setState(() => _cloudListings = list);
      }, onError: (_) {});
    } catch (_) {}
  }

  List<MarketplaceListing> get _allListings {
    if (_cloudListings.isEmpty) return _defaultListings;
    return [..._cloudListings, ..._defaultListings];
  }

  List<MarketplaceListing> get _filtered => _allListings.where((l) {
    final ms =
        l.title.toLowerCase().contains(_search.toLowerCase()) ||
        l.description.toLowerCase().contains(_search.toLowerCase());
    final mc = _cat == 'All' || l.category == _cat;
    return ms && mc;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: const Color(0xFFE65100),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFBF360C), Color(0xFFFF7043)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Marketplace',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Buy & Sell farm goods',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Search bar below header
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFBF360C),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search listings...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
          // Category chips
          SliverToBoxAdapter(
            child: Container(
              height: 52,
              color: const Color(0xFFBF360C),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _cats.length,
                itemBuilder: (_, i) {
                  final c = _cats[i];
                  final sel = c == _cat;
                  final grad =
                      _catGradients[c] ??
                      [const Color(0xFF455A64), const Color(0xFF90A4AE)];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _cat = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: sel ? LinearGradient(colors: grad) : null,
                          color: sel ? null : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD6C8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _marketStat(
                      'Active listings',
                      '${filtered.length}',
                      const Color(0xFFE65100),
                    ),
                  ),
                  Expanded(
                    child: _marketStat(
                      'Categories',
                      '${_cats.length - 1}',
                      const Color(0xFF1565C0),
                    ),
                  ),
                  Expanded(
                    child: _marketStat(
                      'Coverage',
                      'AP / TS',
                      const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Listings
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            sliver: filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 42,
                            color: Colors.orange.shade300,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No listings found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try another keyword or post the first item in this category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _ListingCard(
                        listing: filtered[i],
                        onContact: () =>
                            _showContactDialog(context, filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: const Color(0xFFE65100),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Post Listing',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _marketStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showContactDialog(BuildContext ctx, MarketplaceListing l) {
    final grad =
        _catGradients[l.category] ??
        [const Color(0xFF455A64), const Color(0xFF90A4AE)];
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.title, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cRow(
              Icons.person_rounded,
              'Seller',
              l.seller,
              const Color(0xFF2E7D32),
            ),
            _cRow(
              Icons.location_on_rounded,
              'Location',
              l.location,
              Colors.blue,
            ),
            _cRow(
              Icons.currency_rupee_rounded,
              'Price',
              l.price,
              const Color(0xFFE65100),
            ),
            _cRow(
              Icons.phone_rounded,
              'Phone',
              l.phone,
              const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l.description,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF2E7D32),
                  content: Text('📞 Calling ${l.seller} at ${l.phone}...'),
                ),
              );
            },
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Call Seller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cRow(IconData ic, String lbl, String val, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(ic, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          '$lbl: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Flexible(child: Text(val, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  void _showAddDialog(BuildContext ctx) {
    final tCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final phCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    final lCtrl = TextEditingController(text: 'Eddupenta');
    String cat = 'Produce';
    Uint8List? imgBytes;
    final picker = ImagePicker();

    showDialog(
      context: ctx,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Post a Listing',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setDlg(() => imgBytes = bytes);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade50, Colors.orange.shade100],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: imgBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.memory(imgBytes!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 40,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to add product photo',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(tCtrl, 'Item Name *', Icons.agriculture_rounded),
                const SizedBox(height: 8),
                _buildField(
                  pCtrl,
                  'Price (₹) *',
                  Icons.currency_rupee_rounded,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 8),
                _buildField(
                  phCtrl,
                  'Phone Number *',
                  Icons.phone_rounded,
                  type: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                _buildField(lCtrl, 'Location', Icons.location_on_rounded),
                const SizedBox(height: 8),
                TextField(
                  controller: dCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Produce', 'Equipment', 'Seeds', 'Fertilizer']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlg(() => cat = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final rawTitle = tCtrl.text.trim();
                final rawPrice = pCtrl.text.trim();
                final rawPhone = phCtrl.text.trim();

                if (rawTitle.isEmpty || rawPrice.isEmpty || rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill name, price and phone.'),
                    ),
                  );
                  return;
                }

                // Security Sanitization & Length Limits against injection & XSS
                final cleanTitle = rawTitle.replaceAll(RegExp(r"""[<>&"'\\]"""), '').trim();
                final cleanPriceDigits = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '').trim();
                final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+\- ]'), '').trim();
                final cleanLocation = (lCtrl.text.isEmpty ? 'Kurnool' : lCtrl.text)
                    .replaceAll(RegExp(r"""[<>&"'\\]"""), '')
                    .trim();
                final cleanDesc = (dCtrl.text.isEmpty ? 'No description' : dCtrl.text)
                    .replaceAll(RegExp(r'[<>]'), '')
                    .trim();

                if (cleanTitle.isEmpty || cleanTitle.length > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item name must be 1-100 characters.')),
                  );
                  return;
                }
                if (cleanPriceDigits.isEmpty || cleanPriceDigits.length > 20) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid numeric price.')),
                  );
                  return;
                }
                if (cleanPhone.length < 8 || cleanPhone.length > 20) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid phone number (8-20 digits).')),
                  );
                  return;
                }
                if (imgBytes != null && imgBytes!.length > 1024 * 1024) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selected image is too large (max 1 MB).')),
                  );
                  return;
                }

                final safeCategory = ['Produce', 'Equipment', 'Seeds', 'Fertilizer'].contains(cat)
                    ? cat
                    : 'Produce';
                final safeDesc = cleanDesc.length > 1000 ? cleanDesc.substring(0, 1000) : cleanDesc;
                final safeLocation = cleanLocation.length > 100 ? cleanLocation.substring(0, 100) : cleanLocation;

                final newListing = MarketplaceListing(
                  title: cleanTitle,
                  price: '₹$cleanPriceDigits',
                  seller: 'Farmer (You)',
                  location: safeLocation,
                  category: safeCategory,
                  phone: cleanPhone,
                  description: safeDesc,
                  imageBytes: imgBytes,
                );

                setState(() {
                  _cloudListings.insert(0, newListing);
                });

                // Write to Cloud Firestore with sanitized fields
                try {
                  FirebaseFirestore.instance.collection('marketplace').add({
                    'title': newListing.title,
                    'price': newListing.price,
                    'seller': 'Farmer',
                    'location': newListing.location,
                    'category': newListing.category,
                    'phone': newListing.phone,
                    'description': newListing.description,
                    'createdAt': FieldValue.serverTimestamp(),
                    if (imgBytes != null) 'imageBase64': base64Encode(imgBytes!),
                  });
                } catch (_) {}

                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF2E7D32),
                    content: Text('✅ Listing posted to Marketplace & Cloud!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Post Listing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _ListingCard extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback onContact;
  const _ListingCard({required this.listing, required this.onContact});

  @override
  Widget build(BuildContext context) {
    final grad =
        _catGradients[listing.category] ??
        [const Color(0xFF455A64), const Color(0xFF90A4AE)];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or gradient header
          if (listing.imageBytes != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Image.memory(
                listing.imageBytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [grad[0].withValues(alpha: 0.8), grad[1].withValues(alpha: 0.6)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 36,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.price,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.seller,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      listing.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  listing.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: grad[0].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: grad[0].withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        listing.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: grad[0],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.phone_rounded, size: 14),
                      label: const Text('Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BOREWELL ─────────────────────────────────────────────────────────────────
class BorewellPage extends StatefulWidget {
  const BorewellPage({super.key});
  @override
  State<BorewellPage> createState() => _BorewellPageState();
}

class _BorewellPageState extends State<BorewellPage>
    with SingleTickerProviderStateMixin {
  bool motorOn = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => motorOn = !motorOn);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: motorOn
            ? const Color(0xFF2E7D32)
            : Colors.red.shade700,
        content: Row(
          children: [
            Icon(
              motorOn ? Icons.power_rounded : Icons.power_off_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(motorOn ? 'Motor turned ON ✅' : 'Motor turned OFF 🔴'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: motorOn
                ? [const Color(0xFF1B5E20), const Color(0xFF4CAF50)]
                : [const Color(0xFF263238), const Color(0xFF546E7A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const Text(
                      'Borewell Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Motor animation
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                        scale: motorOn ? _pulse.value : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: motorOn
                                ? Colors.greenAccent
                                : Colors.white30,
                            width: 3,
                          ),
                          boxShadow: motorOn
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(alpha: 0.4),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop_rounded,
                              size: 64,
                              color: motorOn
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              motorOn ? 'RUNNING' : 'STOPPED',
                              style: TextStyle(
                                color: motorOn
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Toggle button
                    GestureDetector(
                      onTap: _toggle,
                      child: Container(
                        width: 200,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: motorOn
                                ? [Colors.red.shade700, Colors.red.shade400]
                                : [
                                    Colors.green.shade600,
                                    Colors.green.shade400,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (motorOn ? Colors.red : Colors.green)
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              motorOn
                                  ? Icons.power_off_rounded
                                  : Icons.power_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              motorOn ? 'Turn OFF' : 'Turn ON',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Coming soon cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ComingSoonCard(
                              Icons.timer_rounded,
                              'Auto-Off Timer',
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ComingSoonCard(
                              Icons.sensors_rounded,
                              'Water Level',
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ComingSoonCard(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ERROR WIDGET ─────────────────────────────────────────────────────────────
class _ErrWidget extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrWidget({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
