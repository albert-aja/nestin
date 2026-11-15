import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/main.dart';
import 'package:nestin/ui/screens/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(
    Widget child, {
    ThemeMode themeMode = ThemeMode.dark,
    Locale locale = const Locale('en', 'US'),
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );
  }

  group('SplashScreen UI & Animation Tests', () {
    testWidgets('renders brand title, PRO tag, tagline, logo and banner overlay', (tester) async {
      bool finished = false;
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            minDuration: const Duration(milliseconds: 600),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pump();

      // Verify immediate presence of brand elements
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Nestin'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Every moment, right on time.'), findsOneWidget);
      expect(find.text('Personal Everyday Space'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify image assets are referenced
      final imageWidgets = tester.widgetList<Image>(find.byType(Image)).toList();
      final assetNames = imageWidgets
          .map((img) => img.image is AssetImage ? (img.image as AssetImage).assetName : '')
          .toList();

      expect(assetNames, contains('assets/banner.jpg'));
      expect(assetNames, contains('assets/logo.jpg'));

      // Forward animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(finished, isFalse);

      // Forward past minDuration to trigger callback
      await tester.pump(const Duration(milliseconds: 400));
      expect(finished, isTrue);
    });

    testWidgets('renders cleanly in Light mode with localized Indonesian tagline', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            minDuration: const Duration(milliseconds: 400),
            onFinish: () {},
          ),
          themeMode: ThemeMode.light,
          locale: const Locale('id', 'ID'),
        ),
      );

      await tester.pump();
      expect(find.text('Nestin'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Setiap momen, tepat waktu.'), findsOneWidget);
      expect(find.text('Personal Everyday Space'), findsOneWidget);
    });
  });

  group('NestinApp Splash Screen Launch Flow', () {
    testWidgets('NestinApp displays SplashScreen on cold launch and transitions to destination', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: true,
        ),
      );
      await tester.pump();

      // Initially SplashScreen is visible
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('splash_screen')), findsOneWidget);

      // Let splash timer run and settle
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // First time launch lands on MascotOnboardingScreen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });

    testWidgets('NestinApp showSplash=false enters directly without splash delay', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final storage = await StorageService.init();
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: false,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });
  });
}
