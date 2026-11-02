// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmtech/main.dart';

void main() {
  testWidgets('FarmTech home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FarmTechApp());
    // Advance past splash timer (2.2s) and transition animation (0.5s)
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('FarmTech'), findsWidgets);
  });

  testWidgets('CropPriceTrendChart renders and scrubs timeline points', (WidgetTester tester) async {
    final sampleHistory = [
      {'date': '01/09/2025', 'iso': '2025-09-01', 'price': 1500, 'min': 1200, 'max': 1800},
      {'date': '15/12/2025', 'iso': '2025-12-15', 'price': 1800, 'min': 1500, 'max': 2100},
      {'date': '09/10/2026', 'iso': '2026-10-09', 'price': 2200, 'min': 1900, 'max': 2500},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CropPriceTrendChart(
            crop: 'Tomato',
            color: const Color(0xFF2E7D32),
            history: sampleHistory,
            currentPrice: 2200,
          ),
        ),
      ),
    );

    expect(find.text('Price Trend Timeline'), findsOneWidget);
    expect(find.textContaining('3 arrivals'), findsOneWidget);
    expect(find.textContaining('First: 01/09/2025'), findsOneWidget);
    expect(find.textContaining('Latest: 09/10/2026'), findsOneWidget);
    expect(find.text('First Arrival'), findsOneWidget);
    expect(find.text('Lowest Ever'), findsOneWidget);
    expect(find.text('Peak Record'), findsOneWidget);
    expect(find.text('Latest Rate'), findsOneWidget);

    // Verify scrubber gesture
    await tester.tap(find.byType(CustomPaint).last);
    await tester.pump();
  });
}
