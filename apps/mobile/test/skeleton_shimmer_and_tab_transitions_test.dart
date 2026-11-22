import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/device_capability.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/discipline/digital_discipline_screen.dart';
import 'package:nestin/ui/screens/scout/phone_modes_screen.dart';
import 'package:nestin/ui/screens/settings/permission_center_screen.dart';
import 'package:nestin/ui/widgets/fade_through_indexed_stack.dart';
import 'package:nestin/ui/widgets/skeleton_shimmer.dart';

class _DeferredDeviceControlService extends MockDeviceControlService {
  Completer<DeviceCapabilityRegistry>? capabilityCompleter;

  _DeferredDeviceControlService() : super(platform: 'android');

  @override
  Future<DeviceCapabilityRegistry> inspectCapabilities() {
    if (capabilityCompleter != null && !capabilityCompleter!.isCompleted) {
      return capabilityCompleter!.future;
    }
    return super.inspectCapabilities();
  }
}

class _CounterTab extends StatefulWidget {
  final String label;
  const _CounterTab({required this.label});

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('${widget.label}: $_count'),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SkeletonShimmer & SkeletonCardList', () {
    testWidgets('renders themed placeholder cards in light and dark themes',
        (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SkeletonCardList(
                itemCount: 3,
                lineCount: 2,
                showTrailingPill: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(SkeletonPlaceholderCard), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('respects MediaQuery disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: SkeletonCardList(itemCount: 2),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SkeletonPlaceholderCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('FadeThroughIndexedStack', () {
    testWidgets('preserves child State across tab switches and settles cleanly',
        (tester) async {
      var activeIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return Scaffold(
                body: FadeThroughIndexedStack(
                  index: activeIndex,
                  children: const [
                    _CounterTab(label: 'Tab0'),
                    _CounterTab(label: 'Tab1'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Tab0: 0'), findsOneWidget);
      await tester.tap(find.text('Tab0: 0'));
      await tester.pump();
      expect(find.text('Tab0: 1'), findsOneWidget);

      // Switch to Tab1 and let fade-through complete
      outerSetState(() => activeIndex = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pumpAndSettle();

      expect(find.text('Tab1: 0'), findsOneWidget);

      // Switch back to Tab0 and verify state (_count == 1) was preserved
      outerSetState(() => activeIndex = 0);
      await tester.pumpAndSettle();
      expect(find.text('Tab0: 1'), findsOneWidget);
    });

    testWidgets('switches immediately when disableAnimations is true',
        (tester) async {
      var activeIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                return Scaffold(
                  body: FadeThroughIndexedStack(
                    index: activeIndex,
                    children: const [
                      _CounterTab(label: 'A'),
                      _CounterTab(label: 'B'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      outerSetState(() => activeIndex = 1);
      await tester.pump();
      expect(find.text('B: 0'), findsOneWidget);
    });
  });

  group('Async OS Capability & Usage Query Skeletons', () {
    testWidgets(
        'PermissionCenterScreen shows skeleton placeholders while refreshing',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      final service = _DeferredDeviceControlService();
      final provider = DeviceControlProvider(
        storage,
        service: service,
        autoRefresh: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PermissionCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonPlaceholderCard), findsNothing);

      // Trigger async capability refresh
      service.capabilityCompleter = Completer<DeviceCapabilityRegistry>();
      final future = provider.refreshCapabilities();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(provider.isRefreshing, isTrue);
      expect(find.byType(SkeletonPlaceholderCard), findsWidgets);

      service.capabilityCompleter!.complete(
        await MockDeviceControlService(platform: 'android')
            .inspectCapabilities(),
      );
      await future;
      await tester.pumpAndSettle();

      expect(provider.isRefreshing, isFalse);
      expect(find.byType(SkeletonPlaceholderCard), findsNothing);
    });

    testWidgets(
        'PhoneModesScreen & DigitalDisciplineScreen show skeletons while refreshing',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      final service = _DeferredDeviceControlService();
      final provider = DeviceControlProvider(
        storage,
        service: service,
        autoRefresh: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PhoneModesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.capabilityCompleter = Completer<DeviceCapabilityRegistry>();
      var refreshFuture = provider.refreshAll();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(SkeletonPlaceholderCard), findsWidgets);

      service.capabilityCompleter!.complete(
        await MockDeviceControlService(platform: 'android')
            .inspectCapabilities(),
      );
      await refreshFuture;
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonPlaceholderCard), findsNothing);

      // Now verify DigitalDisciplineScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DigitalDisciplineScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.capabilityCompleter = Completer<DeviceCapabilityRegistry>();
      refreshFuture = provider.refreshAll();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(SkeletonPlaceholderCard), findsWidgets);

      service.capabilityCompleter!.complete(
        await MockDeviceControlService(platform: 'android')
            .inspectCapabilities(),
      );
      await refreshFuture;
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonPlaceholderCard), findsNothing);
    });
  });
}
