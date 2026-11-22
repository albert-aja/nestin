import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/before_you_go.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/weather_service.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/ui/widgets/before_you_go_card.dart';
import 'package:nestin/ui/widgets/before_you_go_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => true,
  );

  late StorageService storage;
  late NotificationService notifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.init();
    notifications = NotificationService();
    AppLocalizations.currentLanguage = AppLanguage.en;
  });

  tearDown(() {
    AppLocalizations.currentLanguage = AppLanguage.en;
  });

  group('LocalWeatherService & WeatherInfo Detection', () {
    test('detects rain, heavy rain, cool ambient, cool lowTemp, and cold thresholds', () {
      const warmClear = WeatherInfo(
        temperatureCelsius: 27,
        condition: 'Sunny',
        locationName: 'Local Area',
        highTemp: 30,
        lowTemp: 22,
        rainChancePercent: 10,
        advice: 'Clear sky',
      );
      expect(warmClear.isRainy, isFalse);
      expect(warmClear.isCool, isFalse);
      expect(warmClear.hasBeforeYouGoAdvisories, isFalse);

      const rainByPercent = WeatherInfo(
        temperatureCelsius: 25,
        condition: 'Mostly Cloudy',
        locationName: 'Local Area',
        highTemp: 27,
        lowTemp: 22,
        rainChancePercent: 45,
        advice: 'Cloudy',
      );
      expect(rainByPercent.isRainy, isTrue);
      expect(rainByPercent.isHeavyRain, isFalse);
      expect(rainByPercent.isCool, isFalse);

      const thunderstorm = WeatherInfo(
        temperatureCelsius: 13,
        condition: 'Afternoon Storm',
        locationName: 'Local Area',
        highTemp: 15,
        lowTemp: 11,
        rainChancePercent: 80,
        advice: 'Stay dry',
      );
      expect(thunderstorm.isRainy, isTrue);
      expect(thunderstorm.isHeavyRain, isTrue);
      expect(thunderstorm.isCool, isTrue);
      expect(thunderstorm.isCold, isTrue);

      const coolEveningLow = WeatherInfo(
        temperatureCelsius: 23,
        condition: 'Breezy',
        locationName: 'Local Area',
        highTemp: 26,
        lowTemp: 18,
        rainChancePercent: 15,
        advice: 'Cool night drop',
      );
      expect(coolEveningLow.isCool, isTrue);
      expect(coolEveningLow.isCold, isFalse);
    });

    test('LocalWeatherService auto clock & explicit scenarios work deterministically', () async {
      final morningSvc = LocalWeatherService(
        clock: () => DateTime(2026, 11, 14, 9, 30),
      );
      final morning = await morningSvc.getCurrentWeather();
      expect(morning.isRainy, isFalse);
      expect(morning.isCool, isFalse);

      final nightSvc = LocalWeatherService(
        clock: () => DateTime(2026, 11, 14, 21, 0),
      );
      final night = await nightSvc.getCurrentWeather();
      expect(night.isCool, isTrue);

      nightSvc.setScenario(LocalWeatherScenario.rainyShowers);
      final rainy = await nightSvc.getCurrentWeather();
      expect(rainy.isRainy, isTrue);
      expect(rainy.rainChancePercent, greaterThanOrEqualTo(40));

      nightSvc.setScenario(LocalWeatherScenario.clearWarm);
      final warm = await nightSvc.getCurrentWeather();
      expect(warm.hasBeforeYouGoAdvisories, isFalse);
    });
  });

  group('WeatherSuggestedItem Evaluation & BeforeYouGoProvider', () {
    test('evaluates missing items and skips existing synonyms (EN + ID)', () {
      final now = DateTime(2026, 11, 14, 8, 0);
      final everyday = DeparturePreset.seedDefaults(now).first;
      const coldRain = WeatherInfo(
        temperatureCelsius: 12,
        condition: 'Heavy Rain',
        locationName: 'Local Area',
        highTemp: 14,
        lowTemp: 10,
        rainChancePercent: 85,
        advice: 'Bundle up',
      );

      final initial = WeatherSuggestedItem.evaluateForPreset(
        weather: coldRain,
        preset: everyday,
      );
      expect(
        initial.map((s) => s.key).toList(),
        [
          WeatherSuggestedItem.umbrellaKey,
          WeatherSuggestedItem.raincoatKey,
          WeatherSuggestedItem.lightJacketKey,
          WeatherSuggestedItem.warmLayerKey,
        ],
      );

      final withCover = everyday.copyWith(
        items: [
          ...everyday.items,
          const DepartureChecklistItem(id: 'u1', label: 'Compact Payung'),
          const DepartureChecklistItem(id: 'j1', label: 'Favorite Hoodie'),
        ],
      );
      final filtered = WeatherSuggestedItem.evaluateForPreset(
        weather: coldRain,
        preset: withCover,
      );
      expect(
        filtered.map((s) => s.key).toList(),
        [
          WeatherSuggestedItem.raincoatKey,
          WeatherSuggestedItem.warmLayerKey,
        ],
      );
    });

    test('provider adds suggestions, persists scenarios, handles per-preset dismissals & notifications', () async {
      final weatherService = LocalWeatherService(
        initialScenario: LocalWeatherScenario.rainyShowers,
      );
      final provider = BeforeYouGoProvider(
        storage,
        notifications,
        weatherService: weatherService,
      );
      addTearDown(provider.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(provider.activeWeatherSuggestions.length, 2); // Umbrella + Raincoat
      expect(
        provider.activeWeatherSuggestions.map((e) => e.label),
        contains('Umbrella'),
      );

      final event = await provider.addDepartureEvent(
        title: 'Office Commute',
        presetId: DeparturePreset.everydayPresetId,
        hour: 8,
        minute: 15,
        recurrence: DepartureRecurrenceType.weekdays,
      );
      final withTipContent = provider.buildNotificationContent(event);
      expect(withTipContent.body, contains('Weather tip: Pack Umbrella'));

      // Dismiss umbrella on Everyday -> Work still suggests Umbrella
      provider.dismissWeatherSuggestion(
        DeparturePreset.everydayPresetId,
        WeatherSuggestedItem.umbrellaKey,
      );
      expect(
        provider.activeWeatherSuggestions.map((e) => e.key),
        isNot(contains(WeatherSuggestedItem.umbrellaKey)),
      );
      expect(
        provider
            .suggestedWeatherItemsForPreset(
              provider.findPresetById(DeparturePreset.workPresetId)!,
            )
            .map((e) => e.key),
        contains(WeatherSuggestedItem.umbrellaKey),
      );

      // Restore dismissals and switch scenario to Cool Breeze -> adds Light Jacket in Indonesian
      provider.restoreDismissedWeatherSuggestions(DeparturePreset.everydayPresetId);
      await provider.setLocalWeatherScenario(LocalWeatherScenario.coolBreeze);
      expect(storage.loadWeatherScenario(), LocalWeatherScenario.coolBreeze);
      expect(
        provider.activeWeatherSuggestions.map((e) => e.label),
        ['Light Jacket'],
      );

      final addedCount = await provider.addAllWeatherSuggestionsToPreset(
        DeparturePreset.everydayPresetId,
        languageCode: 'id',
      );
      expect(addedCount, 1);
      expect(
        provider.activePreset.items.any((i) => i.label == 'Jaket Tipis'),
        isTrue,
      );
      expect(provider.activeWeatherSuggestions, isEmpty);

      // Re-instantiate provider with default auto service -> loads persisted Cool Breeze scenario
      final reloaded = BeforeYouGoProvider(storage, notifications);
      addTearDown(reloaded.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.localWeatherScenario, LocalWeatherScenario.coolBreeze);
      expect(reloaded.activePreset.items.any((i) => i.label == 'Jaket Tipis'), isTrue);
    });
  });

  group('Weather Prompt UI Integration Tests', () {
    testWidgets('BeforeYouGoCard displays seasonal prompts in Light & Dark themes and adds item on tap', (tester) async {
      final weatherService = LocalWeatherService(
        initialScenario: LocalWeatherScenario.rainyShowers,
      );
      final provider = BeforeYouGoProvider(
        storage,
        notifications,
        weatherService: weatherService,
      );
      addTearDown(provider.dispose);
      await provider.refreshWeatherPrompts();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BeforeYouGoCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rain likely'), findsOneWidget);
      expect(find.text('+ Umbrella'), findsOneWidget);
      expect(find.text('Add All (2)'), findsOneWidget);

      await tester.tap(find.text('+ Umbrella'));
      await tester.pumpAndSettle();

      expect(
        provider.activePreset.items.any((i) => i.label == 'Umbrella'),
        isTrue,
      );
      expect(find.text('0/6 Ready'), findsOneWidget);
      expect(find.text('+ Umbrella'), findsNothing);
      expect(find.text('Added "Umbrella" to Everyday'), findsOneWidget);

      // Switch weather to Clear & Warm -> weather prompt banner hides cleanly
      await provider.setLocalWeatherScenario(LocalWeatherScenario.clearWarm);
      await tester.pumpAndSettle();
      expect(find.textContaining('Rain likely'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BeforeYouGoSheet switches weather scenarios, renders localized prompts, and marks ready', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final weatherService = LocalWeatherService(
        initialScenario: LocalWeatherScenario.clearWarm,
      );
      final provider = BeforeYouGoProvider(
        storage,
        notifications,
        weatherService: weatherService,
      );
      addTearDown(provider.dispose);
      await provider.refreshWeatherPrompts();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: BeforeYouGoSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('28°C • Partly Sunny'), findsOneWidget);
      expect(find.text('Clear & Warm'), findsOneWidget);

      // Open scenario picker -> pick Cold & Stormy
      await tester.tap(find.text('Clear & Warm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cold & Stormy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('13°C • Cold Rain & Wind'), findsOneWidget);
      expect(find.text('+ Umbrella'), findsOneWidget);
      expect(find.text('+ Light Jacket'), findsOneWidget);
      expect(find.text('Add All (4)'), findsOneWidget);
      // Confirm original Add button remains unique
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(find.text('Add All (4)'));
      await tester.pumpAndSettle();

      expect(
        find.text("Everyday already covers today's weather gear."),
        findsOneWidget,
      );
      expect(provider.activePreset.items.length, 9);
      expect(tester.takeException(), isNull);
    });
  });
}
