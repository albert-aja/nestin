import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/break_the_cycle_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/seren/mental_wellness_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android Launcher "Need a Moment?" App Shortcut Configuration', () {
    test('AndroidManifest, shortcuts.xml, icon & EN/ID strings are wired cleanly',
        () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      final shortcutsFile =
          File('android/app/src/main/res/xml/shortcuts.xml');
      final iconFile =
          File('android/app/src/main/res/drawable/ic_shortcut_mental_aid.xml');
      final enStringsFile =
          File('android/app/src/main/res/values/strings.xml');
      final inStringsFile =
          File('android/app/src/main/res/values-in/strings.xml');
      final idStringsFile =
          File('android/app/src/main/res/values-id/strings.xml');

      expect(manifestFile.existsSync(), isTrue);
      expect(shortcutsFile.existsSync(), isTrue);
      expect(iconFile.existsSync(), isTrue);
      expect(enStringsFile.existsSync(), isTrue);
      expect(inStringsFile.existsSync(), isTrue);
      expect(idStringsFile.existsSync(), isTrue);

      final manifestXml = manifestFile.readAsStringSync();
      expect(manifestXml, contains('android:name="android.app.shortcuts"'));
      expect(manifestXml, contains('android:resource="@xml/shortcuts"'));
      expect(manifestXml, contains('android:scheme="nestin"'));

      final shortcutsXml = shortcutsFile.readAsStringSync();
      expect(
        shortcutsXml,
        contains('android:shortcutId="mental_aid_immediate_support"'),
      );
      expect(
        shortcutsXml,
        contains('android:icon="@drawable/ic_shortcut_mental_aid"'),
      );
      expect(
        shortcutsXml,
        contains('android:action="android.intent.action.VIEW"'),
      );
      expect(shortcutsXml, contains('android:data="nestin://mental_aid"'));
      expect(shortcutsXml, contains('android:targetPackage="com.nestin.app"'));
      expect(
        shortcutsXml,
        contains('android:targetClass="com.nestin.app.MainActivity"'),
      );

      final enXml = enStringsFile.readAsStringSync();
      expect(enXml, contains('shortcut_mental_aid_short_label'));
      expect(enXml, contains('Need a Moment?'));

      for (final localized in [inStringsFile, idStringsFile]) {
        final content = localized.readAsStringSync();
        expect(content, contains('shortcut_mental_aid_short_label'));
        expect(content, contains('Butuh Jeda?'));
      }
    });
  });

  group('nestin://mental_aid Layer 1 Immediate Support Destination', () {
    testWidgets(
      'MentalWellnessScreen(initialLayer: 1) opens directly in Layer 1 '
      'Immediate Support with felt-state doors, Urge Support, and Crisis Bridge',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<JournalProvider>.value(value: journal),
              ChangeNotifierProvider<BreakTheCycleProvider>.value(value: btc),
            ],
            child: MaterialApp(
              locale: const Locale('en', 'US'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: AppTheme.lightTheme,
              home: const MentalWellnessScreen(initialLayer: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mw_immediate_urge_support_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mw_l4_open_crisis_bridge_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mw_felt_state_overwhelmed')),
          findsOneWidget,
        );
        // Layer 2 & 3-only sections stay hidden when launched directly into Layer 1
        expect(
          find.byKey(const Key('mw_comfort_kit_add_item_btn')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('mw_btc_mindful_pause_switch')),
          findsNothing,
        );
      },
    );
  });
}
