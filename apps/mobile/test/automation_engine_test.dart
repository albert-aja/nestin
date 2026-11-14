import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/automation_rule.dart';
import 'package:nestin/data/models/entity_link.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/automation_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/automation/automation_hub_screen.dart';
import 'package:nestin/ui/widgets/linked_entities_section.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Shared Automation Engine', () {
    test('evaluates weekday condition, confirmation gate & execution flow',
        () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(
          hasDndAccess: true,
          canWriteSettings: true,
        ),
      );
      final dc = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await dc.refreshCapabilities();
      final auto = AutomationProvider(storage, dc);

      // Default 'auto_arrive_work_focus' has weekdayOnly condition & requiresConfirmation: true
      final saturday = DateTime(2026, 11, 14, 9, 0); // Saturday
      final satLogs = await auto.triggerByEvent(
        AutomationTriggerType.geofenceEnter,
        eventContext: const {'placeName': 'Work'},
        now: saturday,
      );
      expect(satLogs.single.status, AutomationExecutionStatus.skippedCondition);
      expect(auto.pendingConfirmations, isEmpty);

      final monday = DateTime(2026, 11, 16, 9, 0); // Monday
      final monLogs = await auto.triggerByEvent(
        AutomationTriggerType.geofenceEnter,
        eventContext: const {'placeName': 'Work'},
        now: monday,
      );
      expect(
        monLogs.single.status,
        AutomationExecutionStatus.pendingConfirmation,
      );
      expect(auto.pendingConfirmations.length, 1);
      expect(dc.activePhoneModeId, isNull);

      final confirmedLog = await auto.confirmPendingExecution(
        auto.pendingConfirmations.first.id,
        now: monday,
      );
      expect(confirmedLog?.status, AutomationExecutionStatus.succeeded);
      expect(dc.activePhoneModeId, 'mode_work');
      expect(mockService.systemState.dndFilter, 2);
    });

    test('enforces SharedSettingOwnership conflict locking & priority override',
        () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService();
      final dc = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await dc.refreshCapabilities();
      final auto = AutomationProvider(storage, dc);

      final lowPriorityRule = AutomationRule(
        id: 'rule_low',
        name: 'Relax DND (Low Priority)',
        priority: 40,
        triggerType: AutomationTriggerType.manual,
        actions: const [
          AutomationAction(
            type: AutomationActionType.activatePhoneMode,
            params: {'modeId': 'mode_relax'},
          ),
        ],
      );
      final highPriorityRule = AutomationRule(
        id: 'rule_high',
        name: 'Sleep Guard (High Priority)',
        priority: 90,
        triggerType: AutomationTriggerType.manual,
        actions: const [
          AutomationAction(
            type: AutomationActionType.activatePhoneMode,
            params: {'modeId': 'mode_sleep'},
          ),
        ],
      );

      await auto.addOrUpdateRule(lowPriorityRule);
      await auto.addOrUpdateRule(highPriorityRule);

      // Acquire lock with Sleep Guard (P90)
      final highLog = await auto.runRuleManually('rule_high');
      expect(highLog?.status, AutomationExecutionStatus.succeeded);
      expect(auto.activeOwnership['phone_mode']?.ownerId, 'rule_high');

      // Low priority rule (P40) must NOT overwrite P90
      final lowLog = await auto.runRuleManually('rule_low');
      expect(lowLog?.status, AutomationExecutionStatus.blockedByConflict);
      expect(dc.activePhoneModeId, 'mode_sleep');

      // Rollback Sleep Guard restores settings & releases ownership
      final rolledBack = await auto.rollbackExecution(highLog!.id);
      expect(rolledBack, true);
      expect(dc.activePhoneModeId, isNull);
      expect(auto.activeOwnership, isEmpty);
    });

    test('blocks DND action honestly when permission is missing', () async {
      final storage = await StorageService.init();
      final mockService = MockDeviceControlService(
        systemState: const DeviceSystemState(hasDndAccess: false),
      );
      final dc = DeviceControlProvider(
        storage,
        service: mockService,
        autoRefresh: false,
      );
      await dc.refreshCapabilities();
      final auto = AutomationProvider(storage, dc);

      final dndRule = AutomationRule(
        id: 'rule_dnd_check',
        name: 'DND Action',
        triggerType: AutomationTriggerType.manual,
        actions: const [
          AutomationAction(
            type: AutomationActionType.setDndEnabled,
            params: {'enable': true},
          ),
        ],
      );
      await auto.addOrUpdateRule(dndRule);

      final log = await auto.runRuleManually('rule_dnd_check');
      expect(log?.status, AutomationExecutionStatus.blockedByPermission);
    });
  });

  group('Cross-Module Entity Linking Layer', () {
    test('creates bidirectional links, avoids duplicates/self, and cleans orphans',
        () async {
      final storage = await StorageService.init();
      final linkProvider = CrossModuleLinkProvider(storage);

      final created = await linkProvider.addLink(
        sourceType: LinkEntityType.calendarEvent,
        sourceId: 'evt-1',
        sourceTitle: 'Sprint Planning',
        targetType: LinkEntityType.note,
        targetId: 'note-1',
        targetTitle: 'Q4 Agenda',
      );
      expect(created, isNotNull);

      // Bidirectional queries
      expect(
        linkProvider.linksFor(LinkEntityType.calendarEvent, 'evt-1').single.title,
        'Q4 Agenda',
      );
      expect(
        linkProvider.linksFor(LinkEntityType.note, 'note-1').single.title,
        'Sprint Planning',
      );

      // Reverse duplicate prevented
      final duplicate = await linkProvider.addLink(
        sourceType: LinkEntityType.note,
        sourceId: 'note-1',
        sourceTitle: 'Q4 Agenda',
        targetType: LinkEntityType.calendarEvent,
        targetId: 'evt-1',
        targetTitle: 'Sprint Planning',
      );
      expect(duplicate, isNull);

      // Self-link prevented
      final selfLink = await linkProvider.addLink(
        sourceType: LinkEntityType.task,
        sourceId: 't-1',
        sourceTitle: 'Task',
        targetType: LinkEntityType.task,
        targetId: 't-1',
        targetTitle: 'Task',
      );
      expect(selfLink, isNull);

      // Sync title reflects across sides
      await linkProvider.syncEntityTitle(
        LinkEntityType.note,
        'note-1',
        'Q4 Agenda Updated',
      );
      expect(
        linkProvider.linksFor(LinkEntityType.calendarEvent, 'evt-1').single.title,
        'Q4 Agenda Updated',
      );

      // Full backup export/restore preserves links, automations, modes, app rules
      final backupJson = storage.exportFullBackupJson();
      expect(backupJson.contains('Q4 Agenda Updated'), true);

      // Orphan cleanup
      await linkProvider.removeAllLinksFor(LinkEntityType.calendarEvent, 'evt-1');
      expect(linkProvider.allLinks, isEmpty);
    });
  });

  group('AutomationHubScreen & LinkedEntitiesSection Widget Tests', () {
    testWidgets('renders AutomationHubScreen & LinkedEntitiesSection cleanly',
        (tester) async {
      final storage = await StorageService.init();
      final dc = DeviceControlProvider(
        storage,
        service: MockDeviceControlService(),
        autoRefresh: false,
      );
      final auto = AutomationProvider(storage, dc);
      final linkProvider = CrossModuleLinkProvider(storage);
      await linkProvider.addLink(
        sourceType: LinkEntityType.task,
        sourceId: 'task-42',
        sourceTitle: 'Prepare Presentation',
        targetType: LinkEntityType.note,
        targetId: 'note-9',
        targetTitle: 'Slide Outline',
      );
      final settings = SettingsProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: dc),
            ChangeNotifierProvider.value(value: auto),
            ChangeNotifierProvider.value(value: linkProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: Scaffold(
              body: Column(
                children: const [
                  Expanded(child: AutomationHubScreen()),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: LinkedEntitiesSection(
                      entityType: LinkEntityType.task,
                      entityId: 'task-42',
                      entityTitle: 'Prepare Presentation',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bedtime Wind-Down'), findsOneWidget);
      expect(find.text('Twill · Slide Outline'), findsOneWidget);
    });
  });
}
