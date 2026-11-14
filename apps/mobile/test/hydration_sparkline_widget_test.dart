import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/wearable_health_service.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/widgets/hydration_sparkline_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late NotificationService notificationService;
  late HydrationProvider hydrationProvider;
  late WearableProvider wearableProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    notificationService = NotificationService();
    hydrationProvider = HydrationProvider(storageService, notificationService);
    wearableProvider = WearableProvider(storageService);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<HydrationProvider>.value(
              value: hydrationProvider,
            ),
            ChangeNotifierProvider<WearableProvider>.value(
              value: wearableProvider,
            ),
          ],
          child: const SingleChildScrollView(
            child: HydrationSparklineCard(),
          ),
        ),
      ),
    );
  }

  group('HydrationSparklineCard Widget Tests', () {
    testWidgets('Renders sparkline header, metrics, 7 bars and controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Hydration & Weekly Intake'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);

      // Check Metrics
      expect(find.text("Today's Intake"), findsOneWidget);
      expect(find.text('Weekly Average'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);

      // Check Trend section
      expect(find.text('7-DAY INTAKE TREND'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Check quick logging buttons
      expect(find.text('+250ml'), findsOneWidget);

      // Tap +250ml to add water
      await tester.tap(find.text('+250ml'));
      await tester.pumpAndSettle();

      expect(hydrationProvider.glassesConsumed, 1);
      expect(hydrationProvider.currentMilliliters, 250);
      expect(find.text('250ml'), findsWidgets);
    });

    testWidgets('Tapping a bar toggles date details popup',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the 'Today' bar area
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Popover should appear showing milliliters
      expect(find.textContaining('glasses'), findsWidgets);
    });
  });
}
