import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/device_capability.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/scout/digital_wellbeing_screen.dart';
import 'package:nestin/ui/screens/settings/permission_center_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Device Capability Registry & Revoked Permission Detection', () {
    test('classifies Android vs iOS capabilities honestly in 4 tiers', () async {
      final androidMock = MockDeviceControlService(
        platform: 'android',
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasDndAccess: false,
          canWriteSettings: true,
          hasAccessibilityService: false,
        ),
      );
      final androidReg = await androidMock.inspectCapabilities();
      expect(
        androidReg.supportFor(DeviceCapabilityRegistry.actionUsageStats),
        ActionExecutionSupport.directlySupported,
      );
      expect(
        androidReg.supportFor(DeviceCapabilityRegistry.actionDndToggle),
        ActionExecutionSupport.permissionRequired,
      );
      expect(
        androidReg.supportFor(DeviceCapabilityRegistry.actionAppBlockingShield),
        ActionExecutionSupport.delegatedToSystemSettings,
      );

      final iosMock = MockDeviceControlService(
        platform: 'ios',
        manufacturer: 'Apple',
      );
      final iosReg = await iosMock.inspectCapabilities();
      expect(
        iosReg.supportFor(DeviceCapabilityRegistry.actionUsageStats),
        ActionExecutionSupport.unsupported,
      );
      expect(
        iosReg.supportFor(DeviceCapabilityRegistry.actionDndToggle),
        ActionExecutionSupport.delegatedToSystemSettings,
      );
      expect(
        iosReg.supportFor(DeviceCapabilityRegistry.actionBrightnessControl),
        ActionExecutionSupport.unsupported,
      );
    });

    test('detects previously granted permission later revoked by OS/user',
        () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        platform: 'android',
        systemState: const DeviceSystemState(hasUsageStats: true),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );

      await provider.refreshCapabilities();
      expect(provider.registry.isGranted(NestinPermissionKind.usageStats), true);
      expect(provider.registry.revokedPermissions, isEmpty);

      // Simulate user revoking Usage Access in Android Settings
      mockService.systemState = const DeviceSystemState(hasUsageStats: false);
      await provider.refreshCapabilities();

      final revoked = provider.registry.revokedPermissions;
      expect(revoked.length, 1);
      expect(revoked.first.kind, NestinPermissionKind.usageStats);
      expect(revoked.first.status, PermissionStatus.revoked);
    });
  });

  group('5-Level Digital Wellbeing Intervention Manager', () {
    test('triggers pre-limit warning, soft pause, and overnight schedule',
        () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        mockUsageMinutesByPackage: {
          'com.instagram.android': 38, // >= 80% of 45 -> warning (36)
          'com.zhiliaoapp.musically': 35, // >= 30 limit
          'com.facebook.katana': 40, // Track Only -> silent
        },
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await provider.refreshCapabilities();

      // Enable Games rule with blocking schedule 23:00-07:00
      final gamesRule = provider.appRules
          .firstWhere((r) => r.packageName == 'com.nestin.category.games')
          .copyWith(isEnabled: true);
      await provider.addOrUpdateAppRule(gamesRule);

      final nightTime = DateTime(2026, 11, 14, 23, 30);
      final logs = await provider.refreshAppUsage(
        dispatchNotifications: false,
        now: nightTime,
      );

      expect(
        logs.any((l) =>
            l.packageName == 'com.instagram.android' &&
            l.reason == 'scheduled_block' &&
            l.outcome == 'paused_by_user' ||
            l.packageName == 'com.instagram.android' &&
                l.reason == 'pre_limit_warning'),
        true,
      );
      expect(
        logs.any((l) =>
            l.packageName == 'com.zhiliaoapp.musically' &&
            l.reason == 'scheduled_block' &&
            l.outcome == 'paused_by_user'),
        true,
      );
      // Track only must not interrupt
      expect(
        logs.any((l) => l.packageName == 'com.facebook.katana'),
        false,
      );
      // Mobile Games without Accessibility should honestly delegate
      expect(
        logs.any((l) =>
            l.packageName == 'com.nestin.category.games' &&
            l.reason == 'scheduled_block' &&
            l.outcome == 'delegated_to_settings'),
        true,
      );
    });
  });

  group('Phone Mode Orchestrator & Safe State Restoration', () {
    test('captures pre-mode settings and restores them cleanly on exit',
        () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          dndFilter: 1,
          brightnessRaw: 200,
          screenTimeoutMs: 60000,
          hasDndAccess: true,
          canWriteSettings: true,
        ),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );

      final outcomes = await provider.activatePhoneMode('mode_sleep');
      expect(outcomes.where((o) => o.succeeded).length, 3);
      expect(mockService.systemState.dndFilter, 2);
      expect(mockService.systemState.brightnessRaw, lessThan(100));
      expect(mockService.systemState.screenTimeoutMs, 15000);
      expect(provider.activePhoneModeId, 'mode_sleep');

      final notes = await provider.endActivePhoneMode();
      expect(notes.length, 3);
      expect(mockService.systemState.dndFilter, 1);
      expect(mockService.systemState.brightnessRaw, 200);
      expect(mockService.systemState.screenTimeoutMs, 60000);
      expect(provider.activePhoneModeId, isNull);
    });

    test('preserves manual user brightness edit made mid-session', () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          dndFilter: 1,
          brightnessRaw: 180,
          screenTimeoutMs: 60000,
          hasDndAccess: true,
          canWriteSettings: true,
        ),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );

      await provider.activatePhoneMode('mode_work');
      expect(mockService.systemState.dndFilter, 2);
      final appliedBrightness = mockService.systemState.brightnessRaw;
      expect(appliedBrightness, isNot(180));

      // Simulate user manually sliding brightness up to max (245) mid-session
      mockService.systemState = DeviceSystemState(
        dndFilter: mockService.systemState.dndFilter,
        brightnessRaw: 245,
        screenTimeoutMs: mockService.systemState.screenTimeoutMs,
        hasDndAccess: true,
        canWriteSettings: true,
      );

      final notes = await provider.endActivePhoneMode();
      // DND (untouched by user) restores to 1, while brightness keeps user's 245!
      expect(mockService.systemState.dndFilter, 1);
      expect(mockService.systemState.brightnessRaw, 245);
      expect(
        notes.any((n) => n.contains('Preserved user manual brightness')),
        true,
      );
    });

    test('recovers expired session after app restart safely', () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          dndFilter: 1,
          brightnessRaw: 190,
          screenTimeoutMs: 60000,
          hasDndAccess: true,
          canWriteSettings: true,
        ),
      );
      final firstInstance = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );

      final startedAt = DateTime(2026, 11, 14, 10, 0);
      await firstInstance.activatePhoneMode('mode_study', now: startedAt);
      expect(mockService.systemState.dndFilter, 2);

      // Reconstruct provider as if app restarted 2 hours later (Study duration = 60m)
      final restartedInstance = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await restartedInstance.recoverExpiredOrInterruptedModeIfNeeded(
        now: startedAt.add(const Duration(minutes: 90)),
      );

      expect(restartedInstance.activePhoneModeId, isNull);
      expect(mockService.systemState.dndFilter, 1);
      expect(mockService.systemState.brightnessRaw, 190);
      expect(mockService.systemState.screenTimeoutMs, 60000);
    });

    test('reports permissionRequired cleanly when OS denies writes', () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasDndAccess: false,
          canWriteSettings: false,
        ),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );

      final outcomes = await provider.activatePhoneMode('mode_sleep');
      expect(outcomes.every((o) => !o.succeeded), true);
      expect(provider.activeSnapshot!.hasAnyModifiedSetting, false);
    });
  });

  group('UI Widget Smoke Tests (Light & Dark Adaptive Rendering)', () {
    testWidgets(
        'renders DigitalWellbeingScreen and PermissionCenterScreen cleanly in light & dark mode',
        (tester) async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        mockUsageMinutesByPackage: {'com.instagram.android': 25},
      );
      final dcProvider = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await dcProvider.refreshAll();
      final settingsProvider = SettingsProvider(storage);

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MultiProvider(
            key: ValueKey(mode),
            providers: [
              ChangeNotifierProvider.value(value: settingsProvider),
              ChangeNotifierProvider.value(value: dcProvider),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: const DigitalWellbeingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Instagram'), findsOneWidget);

        await tester.tap(find.text('Phone Modes'));
        await tester.pumpAndSettle();
        expect(find.text('Sleep Mode'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.verified_user_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(PermissionCenterScreen), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
      }
    });
  });
}
