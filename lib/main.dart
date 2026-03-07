import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  runApp(const FarmTechApp());
}

class FarmTechApp extends StatelessWidget {
  const FarmTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "FarmTech",
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int selectedIndex = 0;

  final pages = [
    const DashboardPage(),
    const MarketPrices(),
    const BorewellPage(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: pages[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: "Prices",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop),
            label: "Borewell",
          ),

        ],

        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("FarmTech Dashboard")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            Card(
              child: ListTile(
                leading: const Icon(Icons.agriculture),
                title: const Text("Marketplace"),
                subtitle: const Text("Sell or buy farm tools"),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text("Weather"),
                subtitle: const Text("Weather feature coming soon"),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: ListTile(
                leading: const Icon(Icons.water),
                title: const Text("Borewell Monitor"),
                subtitle: const Text("Motor control system"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
class MarketPrices extends StatefulWidget {
  const MarketPrices({super.key});

  @override
  State<MarketPrices> createState() => _MarketPricesState();
}

class _MarketPricesState extends State<MarketPrices> {

  List prices = [];
  bool loading = true;
  String alertMessage = "";

  @override
  void initState() {
    super.initState();
    fetchPrices();
  }

  // PRICE CHANGE CHECK
  Future<void> checkPriceChange(List data) async {
    final prefs = await SharedPreferences.getInstance();

    for (var item in data) {
      String crop = item['commodity'];
      int price = int.tryParse(item['modal_price'].toString()) ?? 0;

      int? oldPrice = prefs.getInt(crop);

      if (oldPrice != null) {
        if (price > oldPrice) {
          alertMessage = "📈 $crop price increased ₹$oldPrice → ₹$price";
        } 
        else if (price < oldPrice) {
          alertMessage = "📉 $crop price decreased ₹$oldPrice → ₹$price";
        }
      }

      prefs.setInt(crop, price);
    }
  }

  // FETCH MANDI DATA
  Future<void> fetchPrices() async {

    print("Fetching mandi data...");

    final url = Uri.parse(
  "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070"
  "?api-key=579b464db66ec23bdd0000011cfb947394444938442424e86eb5b786"
  "&format=json"
  "&filters[state]=Andhra%20Pradesh"
  "&limit=800"
);

    final response = await http.get(url);

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      List records = data["records"];

      await checkPriceChange(records);

      setState(() {
        prices = records;
        loading = false;
      });

      if(alertMessage.isNotEmpty){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(alertMessage))
        );
      }

      print("Records loaded: ${prices.length}");

    } else {
      print("API failed");
    }
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Market Prices"),
        actions: [

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                loading = true;
              });
              fetchPrices();
            },
          )

        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())

          : ListView.builder(
              itemCount: prices.length,

              itemBuilder: (context, index) {

                final item = prices[index];

                return Card(

                  margin: const EdgeInsets.all(10),

                  child: ListTile(

                    leading: const Icon(
                      Icons.grass,
                      color: Colors.green,
                    ),

                    title: Text(
                      item["commodity"] ?? "Unknown Crop",
                    ),

                    subtitle: Text(
                      "${item["district"] ?? ""} - ${item["market"] ?? ""}",
                    ),

                    trailing: Text(
                      "₹${item["modal_price"] ?? ""}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                  ),
                );
              },
            ),
    );
  }
}

class BorewellPage extends StatelessWidget {
  const BorewellPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Borewell Control"),
      ),

      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(
              Icons.water,
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              "Motor Control Coming Soon",
              style: TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {},
              child: const Text("Turn Motor ON"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {},
              child: const Text("Turn Motor OFF"),
            ),

          ],
        ),
      ),
    );
  }
}