import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roodoo/data/models/alarm_category.dart';
import 'package:roodoo/ui/widgets/category_badge.dart';
import 'package:roodoo/ui/widgets/roodoo_brand_header.dart';

void main() {
  testWidgets('RooDooBrandHeader renders logo and title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RooDooBrandHeader(
            subtitle: 'Every moment, right on time.',
          ),
        ),
      ),
    );

    expect(find.text('RooDoo'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('Every moment, right on time.'), findsOneWidget);
  });

  testWidgets('CategoryBadge renders category icon and text', (WidgetTester tester) async {
    final cat = AlarmCategory.fromType(AlarmCategoryType.wakeUp);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBadge(category: cat),
        ),
      ),
    );

    expect(find.text('Wake Up'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
  });
}
