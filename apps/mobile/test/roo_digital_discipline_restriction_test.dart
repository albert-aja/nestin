import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/app_restriction.dart';
import 'package:nestin/data/models/digital_wellbeing.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/wellbeing/restriction_engine.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/ui/screens/discipline/digital_discipline_screen.dart';
import 'package:nestin/ui/screens/discipline/wellbeing_app_fast_tab.dart';
import 'package:nestin/ui/screens/discipline/wellbeing_app_picker_sheet.dart';
import 'package:nestin/ui/screens/discipline/wellbeing_intervention_dialog.dart';
import 'package:nestin/ui/screens/scout/phone_modes_screen.dart';

class _StubAudioService implements AudioService {
  @override
  bool get isPlaying => false;
  @override
  double get currentVolume => 0.0;
  @override
  Future<void> startAlarm({
    required String soundId,
    String? customFilePath,
    required double targetVolume,
    required bool gradualVolume,
    required int gradualDurationSeconds,
  }) async {}
  @override
  Future<void> previewTone(
    String soundId,
    double volume, {
    String? customFilePath,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class _StubAmbientSoundService implements AmbientSoundService {
  @override
  AmbientSoundType get currentType => AmbientSoundType.none;
  @override
  double get volume => 0.5;
  @override
  bool get isPlaying => false;
  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {}
  @override
  Future<void> setVolume(double vol) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubNotificationService extends NotificationService {
  final List<String> shownTitles = [];
  @override
  Future<void> showWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownTitles.add(title);
  }

  @override
  Future<void> showTimerCompleteNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    shownTitles.add(title);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  group('Shared Restriction Engine & Capabilities', () {
    test('single restriction evaluation (App Fast Reminder vs Strict & Usage Limits)',
        () async {
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
        mockUsageMinutesByPackage: {
          'com.instagram.android': 50,
          'com.zhiliaoapp.musically': 15,
        },
      );

      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await provider.refreshCapabilities();
      await provider.refreshAppUsage(dispatchNotifications: false);

      final now = DateTime(2026, 11, 14, 14, 0); // Saturday
      await provider.createAppFastCommitment(
        AppFastCommitment(
          title: '30-Day IG Break',
          targetPackages: ['com.instagram.android'],
          targetAppNames: {'com.instagram.android': 'Instagram'},
          startAt: now.subtract(const Duration(hours: 2)),
          endAt: now.add(const Duration(days: 30)),
          mode: RestrictionEnforcementMode.reminder,
          motivation: 'More deep reading',
        ),
        now: now,
      );

      final reminderDecision = provider.evaluateApp('com.instagram.android', now: now);
      expect(reminderDecision.isRestricted, isTrue);
      expect(reminderDecision.effectiveStrength, RestrictionStrength.reminder);
      expect(reminderDecision.winningRule?.sourceType, RestrictionSourceType.appFast);
      expect(reminderDecision.platformSupport, PlatformSupportLevel.supported);
      expect(reminderDecision.canProceedAnyway, isTrue);

      // Weekday vs Weekend Usage Limit + Custom Daily Reset Window
      final customRule = TrackedAppRule(
        id: 'yt_custom',
        packageName: 'com.google.android.youtube',
        displayName: 'YouTube',
        dailyLimitMinutes: 60,
        weekdayLimitMinutes: 30,
        weekendLimitMinutes: 90,
        limitReachedAction: UsageLimitAction.strictBlock,
        dailyResetHour: 4,
        dailyResetMinute: 0,
      );
      expect(
        customRule.effectiveLimitMinutesFor(DateTime(2026, 11, 13, 12, 0)), // Friday
        30,
      );
      expect(
        customRule.effectiveLimitMinutesFor(DateTime(2026, 11, 14, 12, 0)), // Saturday
        90,
      );
      // 02:30 AM before 04:00 AM reset still belongs to previous reset window key
      expect(
        customRule.currentResetWindowKey(DateTime(2026, 11, 14, 2, 30)),
        '2026-11-13@04:00',
      );
      expect(
        customRule.currentResetWindowKey(DateTime(2026, 11, 14, 4, 5)),
        '2026-11-14@04:00',
      );
      provider.dispose();
    });

    test('monotonic conflict resolution & releasing one source keeps stronger sources active',
        () async {
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
        mockUsageMinutesByPackage: {
          'com.instagram.android': 70, // Over default 45m limit
        },
      );

      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await provider.refreshCapabilities();
      await provider.refreshAppUsage(dispatchNotifications: false);

      final now = DateTime(2026, 11, 14, 10, 0);

      // 1) Usage Limit set to strictBlock
      final igRule = provider.appRules
          .firstWhere((r) => r.packageName == 'com.instagram.android')
          .copyWith(limitReachedAction: UsageLimitAction.strictBlock);
      await provider.addOrUpdateAppRule(igRule);

      // 2) Coexisting Reminder App Fast + Reminder Focus Lock + Automation Warning
      await provider.createAppFastCommitment(
        AppFastCommitment(
          title: 'IG Reminder Fast',
          targetPackages: ['com.instagram.android'],
          targetAppNames: {'com.instagram.android': 'Instagram'},
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 7)),
          mode: RestrictionEnforcementMode.reminder,
        ),
        now: now,
      );

      await provider.activateFocusLockSession(
        source: 'roo_manual',
        taskLabel: 'Deep Work',
        duration: const Duration(minutes: 25),
        overrideRestrictedPackages: ['com.instagram.android'],
        overrideMode: RestrictionEnforcementMode.reminder,
        now: now,
      );

      await provider.registerExtraRestrictionRule(
        const RestrictionRule(
          id: 'auto_ig',
          sourceType: RestrictionSourceType.automation,
          sourceId: 'rule_1',
          title: 'Morning Rule',
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          strength: RestrictionStrength.warning,
          reason: 'Morning focus routine',
        ),
        now: now,
      );

      final combined = provider.evaluateApp('com.instagram.android', now: now);
      expect(combined.effectiveStrength, RestrictionStrength.strict);
      expect(combined.canProceedAnyway, isFalse);
      expect(combined.activeRules.length, 4);
      expect(
        combined.activeRules.map((r) => r.sourceType).toSet(),
        containsAll({
          RestrictionSourceType.usageLimit,
          RestrictionSourceType.appFast,
          RestrictionSourceType.focusLock,
          RestrictionSourceType.automation,
        }),
      );

      // Ending Focus Lock must NOT clear Usage Limit, App Fast, or Automation
      await provider.endFocusLockSession(reason: 'completed', force: true, now: now);
      final afterFocusEnds =
          provider.evaluateApp('com.instagram.android', now: now);
      expect(afterFocusEnds.effectiveStrength, RestrictionStrength.strict);
      expect(
        afterFocusEnds.activeRules.map((r) => r.sourceType),
        isNot(contains(RestrictionSourceType.focusLock)),
      );
      expect(afterFocusEnds.activeRules.length, 3);

      // Recording Reminder grace logs user bypass safely without crashing strict mode
      provider.recordReminderContinueAnyway('com.instagram.android', now: now);
      expect(provider.isInReminderGrace('com.instagram.android', now: now), isTrue);

      provider.dispose();
    });

    test('permission revocation & iOS entitlement downgrade report support honestly',
        () async {
      final mockService = MockDeviceControlService(
        platform: 'android',
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await provider.refreshCapabilities();
      expect(
        provider.supportLevelForStrength(RestrictionStrength.strict),
        PlatformSupportLevel.supported,
      );

      // User revokes Accessibility mid-restriction while keeping Overlay
      mockService.systemState = const DeviceSystemState(
        hasUsageStats: true,
        hasAccessibilityService: false,
        hasOverlayPermission: true,
        hasNotifications: true,
      );
      await provider.refreshCapabilities();
      expect(
        provider.supportLevelForStrength(RestrictionStrength.strict),
        PlatformSupportLevel.limitedSupport,
      );

      // Revoke Overlay too -> requires permission honestly
      mockService.systemState = const DeviceSystemState(
        hasUsageStats: true,
        hasAccessibilityService: false,
        hasOverlayPermission: false,
        hasNotifications: true,
      );
      await provider.refreshCapabilities();
      expect(
        provider.supportLevelForStrength(RestrictionStrength.strict),
        PlatformSupportLevel.supportedWithPermission,
      );

      // iOS without FamilyControls entitlement reports Supported with Entitlement
      final iosMock = MockDeviceControlService(
        platform: 'ios',
        manufacturer: 'Apple',
        systemState: const DeviceSystemState(
          hasFamilyControlsEntitlement: false,
        ),
      );
      final iosProvider = DeviceControlProvider(
        storage,
        service: iosMock,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await iosProvider.refreshCapabilities();
      expect(
        iosProvider.supportLevelForStrength(RestrictionStrength.strict),
        PlatformSupportLevel.supportedWithEntitlement,
      );

      provider.dispose();
      iosProvider.dispose();
    });

    test('restart recovery auto-releases expired Focus Lock & advances App Fast lifecycle',
        () async {
      final t0 = DateTime(2026, 11, 14, 9, 0);
      await storage.saveActiveFocusLockSession(
        FocusLockSession(
          source: 'roo_pomodoro',
          taskLabel: 'Morning Sprint',
          phase: 'work',
          restrictedPackages: ['com.instagram.android'],
          startedAt: t0.subtract(const Duration(minutes: 40)),
          expectedEndAt: t0.subtract(const Duration(minutes: 15)),
        ),
      );
      await storage.saveAppFastCommitments([
        AppFastCommitment(
          id: 'fast_scheduled',
          title: 'Future Fast',
          targetPackages: ['com.reddit.frontpage'],
          startAt: t0.add(const Duration(hours: 2)),
          endAt: t0.add(const Duration(days: 5)),
          status: AppFastStatus.scheduled,
        ),
        AppFastCommitment(
          id: 'fast_done',
          title: 'Ended Fast',
          targetPackages: ['com.zhiliaoapp.musically'],
          startAt: t0.subtract(const Duration(days: 3)),
          endAt: t0.subtract(const Duration(minutes: 5)),
          status: AppFastStatus.active,
        ),
      ]);

      final provider = DeviceControlProvider(
        storage,
        service: MockDeviceControlService(),
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );

      await provider.reconcileRestrictions(now: t0);
      expect(provider.activeFocusSession, isNull);
      expect(
        provider.appFastByStatus(AppFastStatus.scheduled, now: t0).map((e) => e.id),
        contains('fast_scheduled'),
      );
      expect(
        provider.appFastByStatus(AppFastStatus.completed, now: t0).map((e) => e.id),
        contains('fast_done'),
      );

      // Advance clock past fast_scheduled startAt -> transitions scheduled -> active
      final later = t0.add(const Duration(hours: 3));
      await provider.handleDayOrTimezoneChange(now: later);
      expect(
        provider.appFastByStatus(AppFastStatus.active, now: later).map((e) => e.id),
        contains('fast_scheduled'),
      );

      provider.dispose();
    });

    test('uninstalled apps & essential/emergency packages handled safely', () async {
      final mockService = MockDeviceControlService(
        mockInstalledApps: const [
          InstalledAppInfo(
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            category: 'social',
          ),
        ],
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await provider.discoverInstalledApps();
      expect(provider.isPackageInstalled('com.instagram.android'), isTrue);
      expect(provider.isPackageInstalled('com.example.uninstalled'), isFalse);

      // Even if a rule targets dialer or emergency, engine NEVER locks essential packages
      final now = DateTime(2026, 11, 14, 12, 0);
      await provider.createAppFastCommitment(
        AppFastCommitment(
          title: 'Test Dialer Safeguard',
          targetPackages: ['com.android.dialer', 'com.android.emergency', 'com.nestin.app'],
          startAt: now.subtract(const Duration(hours: 1)),
          endAt: now.add(const Duration(days: 1)),
          mode: RestrictionEnforcementMode.strict,
        ),
        now: now,
      );
      expect(provider.evaluateApp('com.android.dialer', now: now).isRestricted, isFalse);
      expect(provider.evaluateApp('com.android.emergency', now: now).isRestricted, isFalse);
      expect(provider.evaluateApp('com.nestin.app', now: now).isRestricted, isFalse);
      expect(RestrictionEngine.isEssentialSystemPackage('com.google.android.dialer'), isTrue);

      provider.dispose();
    });

    test('Roo Pomodoro (TimerProvider) integrates cleanly with Focus Lock Coordinator',
        () async {
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
      );
      final dcProvider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await dcProvider.refreshCapabilities();
      await dcProvider.updateFocusLockConfig(
        const FocusLockConfig(
          enabled: true,
          restrictedPackages: ['com.instagram.android'],
          restrictedAppNames: {'com.instagram.android': 'Instagram'},
          restrictDuringBreaks: false,
          allowManualEnd: false,
          enforcementMode: RestrictionEnforcementMode.strict,
        ),
      );

      final timerProvider = TimerProvider(
        storage,
        _StubNotificationService(),
        _StubAudioService(),
        _StubAmbientSoundService(),
        dcProvider,
      );

      timerProvider.startPomodoro();
      await Future<void>.delayed(Duration.zero);

      expect(dcProvider.activeFocusSession, isNotNull);
      expect(dcProvider.activeFocusSession!.source, 'roo_pomodoro');
      expect(
        dcProvider.evaluateApp('com.instagram.android').effectiveStrength,
        RestrictionStrength.strict,
      );

      // Manual end blocked when allowManualEnd is false
      final manualBlocked = await dcProvider.endFocusLockSession(reason: 'manual_end');
      expect(manualBlocked, isFalse);
      expect(dcProvider.activeFocusSession, isNotNull);

      // Pausing Pomodoro records pause state without dropping strict anti-bypass lock
      timerProvider.pausePomodoro();
      await Future<void>.delayed(Duration.zero);
      expect(dcProvider.activeFocusSession!.isPaused, isTrue);
      expect(
        dcProvider.evaluateApp('com.instagram.android').effectiveStrength,
        RestrictionStrength.strict,
      );

      timerProvider.resumePomodoro();
      await Future<void>.delayed(Duration.zero);
      expect(dcProvider.activeFocusSession!.isPaused, isFalse);
      expect(dcProvider.evaluateApp('com.instagram.android').isRestricted, isTrue);

      // Transitioning into shortBreak relaxes Focus Lock when restrictDuringBreaks == false
      await dcProvider.updateFocusLockPhase(
        phase: 'shortBreak',
        duration: const Duration(minutes: 5),
      );
      expect(dcProvider.activeFocusSession!.phase, 'shortBreak');
      expect(dcProvider.evaluateApp('com.instagram.android').isRestricted, isFalse);

      // Resetting Pomodoro cleanly ends the Focus Lock session
      timerProvider.resetPomodoro();
      await Future<void>.delayed(Duration.zero);
      expect(dcProvider.activeFocusSession, isNull);

      timerProvider.dispose();
      dcProvider.dispose();
    });

    test('Full backup export/restore preserves App Fast, Focus Lock config & Usage rules',
        () async {
      final dcProvider = DeviceControlProvider(
        storage,
        service: MockDeviceControlService(),
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      final now = DateTime(2026, 11, 14, 11, 0);
      await dcProvider.createAppFastCommitment(
        AppFastCommitment(
          id: 'backup_fast_1',
          title: 'Backed Up Fast',
          targetPackages: ['com.reddit.frontpage'],
          targetAppNames: {'com.reddit.frontpage': 'Reddit'},
          startAt: now,
          endAt: now.add(const Duration(days: 14)),
          mode: RestrictionEnforcementMode.strict,
          motivation: 'Evening peace',
        ),
        now: now,
      );
      await dcProvider.updateFocusLockConfig(
        const FocusLockConfig(
          enabled: true,
          restrictedPackages: ['com.reddit.frontpage'],
          restrictDuringBreaks: true,
          allowManualEnd: false,
          enforcementMode: RestrictionEnforcementMode.strict,
        ),
      );
      await dcProvider.addOrUpdateAppRule(
        TrackedAppRule(
          id: 'rule_reddit_custom',
          packageName: 'com.reddit.frontpage',
          displayName: 'Reddit',
          dailyLimitMinutes: 25,
          weekdayLimitMinutes: 15,
          weekendLimitMinutes: 40,
          limitReachedAction: UsageLimitAction.reminderPause,
        ),
      );

      final exported = storage.exportFullBackupJson();
      await prefs.clear();
      await storage.restoreFullBackupJson(exported);

      final restored = DeviceControlProvider(
        storage,
        service: MockDeviceControlService(),
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      expect(restored.appFastCommitments.map((c) => c.id), contains('backup_fast_1'));
      expect(restored.focusLockConfig.restrictDuringBreaks, isTrue);
      expect(restored.focusLockConfig.allowManualEnd, isFalse);
      final restoredRedditRule = restored.appRules
          .firstWhere((r) => r.packageName == 'com.reddit.frontpage');
      expect(restoredRedditRule.weekdayLimitMinutes, 15);
      expect(restoredRedditRule.weekendLimitMinutes, 40);
      expect(restoredRedditRule.resolvedLimitAction, UsageLimitAction.reminderPause);

      dcProvider.dispose();
      restored.dispose();
    });

    test('App Fast automatically transitions to failed when lock is bypassed via Continue Anyway, Shield grace or telemetry', () async {
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
      );
      final provider = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      final now = DateTime(2026, 11, 14, 10, 0);

      // Create an active App Fast for TikTok & Instagram
      final fast = AppFastCommitment(
        id: 'fast_bypass_test',
        title: 'Social Fast',
        targetPackages: ['com.zhiliaoapp.musically', 'com.instagram.android'],
        targetAppNames: {
          'com.zhiliaoapp.musically': 'TikTok',
          'com.instagram.android': 'Instagram',
        },
        startAt: now.subtract(const Duration(hours: 2)),
        endAt: now.add(const Duration(days: 7)),
        mode: RestrictionEnforcementMode.reminder,
      );
      await provider.createAppFastCommitment(fast, now: now);

      expect(provider.appFastCommitments.first.status, AppFastStatus.active);
      expect(provider.evaluateApp('com.zhiliaoapp.musically', now: now).isRestricted, isTrue);

      // 1. Bypass via Continue Anyway
      provider.recordReminderContinueAnyway('com.zhiliaoapp.musically', now: now);

      final failedFast = provider.appFastCommitments.firstWhere((c) => c.id == 'fast_bypass_test');
      expect(failedFast.status, AppFastStatus.failed);
      expect(failedFast.failedAt, now);
      expect(failedFast.failureReason, 'lock_bypassed_continue_anyway');
      expect(failedFast.isActiveAt(now), isFalse);

      // After failure, app is no longer restricted by this App Fast
      expect(provider.evaluateApp('com.zhiliaoapp.musically', now: now).isRestricted, isFalse);

      // 2. Test failure via usage telemetry during fast
      final fast2 = AppFastCommitment(
        id: 'fast_telemetry_test',
        title: 'IG Fast',
        targetPackages: ['com.instagram.android'],
        targetAppNames: {'com.instagram.android': 'Instagram'},
        startAt: now,
        endAt: now.add(const Duration(days: 7)),
        mode: RestrictionEnforcementMode.reminder,
      );
      await provider.createAppFastCommitment(fast2, now: now);
      expect(provider.appFastCommitments.first.status, AppFastStatus.active);

      // Simulate usage detected after fast started
      mockService.mockRecords = [
        AppUsageRecord(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          usedMinutesToday: 15,
          lastUsedAt: now.add(const Duration(minutes: 5)),
          dateKey: '2026-11-14',
        ),
      ];
      await provider.refreshAppUsage(now: now.add(const Duration(minutes: 10)), dispatchNotifications: false);

      final failedFast2 = provider.appFastCommitments.firstWhere((c) => c.id == 'fast_telemetry_test');
      expect(failedFast2.status, AppFastStatus.failed);
      expect(failedFast2.failureReason, 'usage_detected_during_fast');

      // 3. Test failure via native shield grace reporting
      final fast3 = AppFastCommitment(
        id: 'fast_shield_test',
        title: 'Shield Fast',
        targetPackages: ['com.reddit.frontpage'],
        targetAppNames: {'com.reddit.frontpage': 'Reddit'},
        startAt: now,
        endAt: now.add(const Duration(days: 7)),
        mode: RestrictionEnforcementMode.reminder,
      );
      await provider.createAppFastCommitment(fast3, now: now);
      expect(provider.appFastCommitments.first.status, AppFastStatus.active);

      mockService.mockRecords = null;
      mockService.mockBypassedPackages = ['com.reddit.frontpage'];
      await provider.refreshAppUsage(now: now.add(const Duration(minutes: 15)), dispatchNotifications: false);

      final failedFast3 = provider.appFastCommitments.firstWhere((c) => c.id == 'fast_shield_test');
      expect(failedFast3.status, AppFastStatus.failed);
      expect(failedFast3.failureReason, 'lock_bypassed_shield_grace');

      provider.dispose();
    });
  });

  group('Roo Digital Discipline & Scout Phone Modes UI (EN/ID & Dark/Light)', () {
    Widget wrapWithApp({
      required SettingsProvider settings,
      required DeviceControlProvider dc,
      required Widget child,
      Brightness brightness = Brightness.light,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<DeviceControlProvider>.value(value: dc),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    testWidgets('renders all 5 Roo discipline tabs, Scout Phone Modes, picker & dialog in ID dark mode',
        (tester) async {
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.id);

      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasUsageStats: true,
          hasAccessibilityService: true,
          hasOverlayPermission: true,
          hasNotifications: true,
        ),
        mockUsageMinutesByPackage: {
          'com.instagram.android': 30,
        },
      );
      final dc = DeviceControlProvider(
        storage,
        service: mockService,
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      await dc.refreshCapabilities();
      await dc.refreshAppUsage(dispatchNotifications: false);

      await tester.pumpWidget(
        wrapWithApp(
          settings: settings,
          dc: dc,
          brightness: Brightness.dark,
          child: const DigitalDisciplineScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Roo Digital Discipline 5 tabs (no Phone Modes in Roo)
      expect(find.text('Ringkasan'), findsOneWidget);
      expect(find.text('Puasa Aplikasi'), findsOneWidget);
      expect(find.text('Kunci Fokus'), findsOneWidget);
      expect(find.text('Batas Penggunaan'), findsOneWidget);
      expect(find.text('Penggunaan Aplikasi'), findsAtLeastNWidgets(1));
      expect(find.text('Mode Ponsel'), findsNothing);

      // Navigate to App Fast tab
      await tester.tap(find.text('Puasa Aplikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Komitmen Puasa Aplikasi'), findsOneWidget);

      // Open Focus Lock tab and verify Focus Lock controls
      await tester.tap(find.text('Kunci Fokus'));
      await tester.pumpAndSettle();
      expect(find.text('Kunci Fokus & Sinkron Pomodoro Roo'), findsOneWidget);

      // Verify Scout Phone Modes lives separately under Scout
      await tester.pumpWidget(
        wrapWithApp(
          settings: settings,
          dc: dc,
          brightness: Brightness.dark,
          child: const PhoneModesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scout · Mode & Kontrol Ponsel'), findsOneWidget);
      expect(find.text('Sleep Mode'), findsOneWidget);
      expect(find.text('Puasa Aplikasi'), findsNothing);

      // Render App Picker Sheet via static pickApps & confirm selection
      Map<String, String>? pickedApps;
      await tester.pumpWidget(
        wrapWithApp(
          settings: settings,
          dc: dc,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  pickedApps = await WellbeingAppPickerSheet.pickApps(
                    ctx,
                    initialSelected: const {'com.instagram.android'},
                    initialNames: const {'com.instagram.android': 'Instagram'},
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();
      expect(find.text('Instagram'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'TikTok');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('TikTok'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Konfirmasi (2)'));
      await tester.pumpAndSettle();
      expect(
        pickedApps?.keys,
        containsAll(['com.instagram.android', 'com.zhiliaoapp.musically']),
      );

      // Render WellbeingInterventionDialog in Reminder Mode
      final decision = RestrictionDecision(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        effectiveStrength: RestrictionStrength.reminder,
        winningRule: const RestrictionRule(
          id: 'r1',
          sourceType: RestrictionSourceType.appFast,
          sourceId: 'f1',
          title: 'Break Time',
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          strength: RestrictionStrength.reminder,
          reason: 'Stay intentional',
        ),
        activeRules: const [
          RestrictionRule(
            id: 'r1',
            sourceType: RestrictionSourceType.appFast,
            sourceId: 'f1',
            title: 'Break Time',
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            strength: RestrictionStrength.reminder,
            reason: 'Stay intentional',
          ),
        ],
        outcome: RestrictionExecutionOutcome.reminderOverlayShown,
        platformSupport: PlatformSupportLevel.supported,
        canProceedAnyway: true,
        explanation: 'App Fast Reminder active.',
        evaluatedAt: DateTime(2026, 11, 14, 15, 0),
      );

      await tester.pumpWidget(
        wrapWithApp(
          settings: settings,
          dc: dc,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    WellbeingInterventionDialog.show(ctx, dc, decision),
                child: const Text('Show Intervention'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Intervention'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Break Time'), findsOneWidget);
      expect(find.text('Tetap Fokus di Nestin'), findsOneWidget);
      expect(find.text('Lanjutkan (5 mnt)'), findsOneWidget);

      dc.dispose();
    });

    testWidgets('renders failed App Fast commitment with error badge and failure reason banner in EN and ID', (tester) async {
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);

      final dcProvider = DeviceControlProvider(
        storage,
        service: MockDeviceControlService(),
        notifications: _StubNotificationService(),
        autoRefresh: false,
      );
      final now = DateTime(2026, 11, 14, 12, 0);
      await dcProvider.createAppFastCommitment(
        AppFastCommitment(
          id: 'failed_ui_card',
          title: 'Night Detox',
          targetPackages: ['com.instagram.android'],
          targetAppNames: {'com.instagram.android': 'Instagram'},
          startAt: now.subtract(const Duration(days: 2)),
          endAt: now.add(const Duration(days: 5)),
          status: AppFastStatus.failed,
          failedAt: now.subtract(const Duration(hours: 3)),
          failureReason: 'lock_bypassed_continue_anyway',
        ),
        now: now,
      );

      await tester.pumpWidget(
        wrapWithApp(
          settings: settings,
          dc: dcProvider,
          child: const Scaffold(body: WellbeingAppFastTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Night Detox'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Failed: Lock bypassed via Continue Anyway'), findsOneWidget);

      // Switch to ID
      await settings.setLanguage(AppLanguage.id);
      await tester.pumpAndSettle();

      expect(find.text('GAGAL'), findsOneWidget);
      expect(find.text('Gagal: Kunci dilewati melalui Tetap Lanjut'), findsOneWidget);

      dcProvider.dispose();
    });
  });
}
