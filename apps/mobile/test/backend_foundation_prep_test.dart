import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/config/api_contracts.dart';
import 'package:nestin/core/config/app_environment.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Local-First & Backend Preparation Foundation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AppEnvironment defaults safely to offline/local posture', () {
      expect(AppEnvironment.isBackendConfigured, isFalse);
      expect(AppEnvironment.isSupabaseConfigured, isFalse);
      expect(AppEnvironment.buildApiUri('/system/health'), isNull);
    });

    test('BackendGatewayService auto-provisions persistent guest UUID and stays offline-safe', () async {
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs);

      final first = await gateway.ensureGuestIdentity();
      expect(first.guestLocalId, isNotEmpty);
      expect(first.authMode, AccountAuthMode.guest);
      expect(first.cloudSyncOptIn, isFalse);

      final second = await gateway.ensureGuestIdentity();
      expect(second.guestLocalId, first.guestLocalId);

      // Linking account preserves guestLocalId and defaults cloudSyncOptIn to false
      final linked = first.linkRegisteredAccount(userId: 'user-uuid-123');
      expect(linked.guestLocalId, first.guestLocalId);
      expect(linked.authMode, AccountAuthMode.registered);
      expect(linked.linkedUserId, 'user-uuid-123');
      expect(linked.cloudSyncOptIn, isFalse);

      await gateway.saveGuestIdentity(linked);
      final reloaded = await gateway.ensureGuestIdentity();
      expect(reloaded.authMode, AccountAuthMode.registered);
      expect(reloaded.linkedUserId, 'user-uuid-123');

      // Fetching remote config cleanly reports offline/unconfigured without throwing
      final remoteConfig = await gateway.fetchRemoteConfig();
      expect(remoteConfig.isSuccess, isFalse);
      expect(remoteConfig.isOfflineOrUnconfigured, isTrue);
    });

    test('SyncMetadata tracks local-first tombstones cleanly for future P1 sync', () {
      final now = DateTime.utc(2026, 11, 14, 10, 0);
      final meta = SyncMetadata(
        id: 'rec-uuid-1',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      );

      final updated = meta.markUpdated(now: now.add(const Duration(minutes: 5)));
      expect(updated.syncStatus, SyncStatus.pendingPush);
      expect(updated.isDeleted, isFalse);

      final deleted = updated.markDeleted(now: now.add(const Duration(minutes: 10)));
      expect(deleted.isDeleted, isTrue);
      expect(deleted.syncStatus, SyncStatus.pendingPush);

      final restored = SyncMetadata.fromJson(deleted.toJson());
      expect(restored.id, 'rec-uuid-1');
      expect(restored.isDeleted, isTrue);
      expect(restored.syncStatus, SyncStatus.pendingPush);
    });

    test('StorageService.init migrates legacy keys to nestin_* keys cleanly', () async {
      final sampleAlarm = Alarm(
        id: 'a1',
        title: 'Morning',
        hour: 7,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: DateTime(2026, 11, 14),
        updatedAt: DateTime(2026, 11, 14),
      );
      SharedPreferences.setMockInitialValues({
        'roodoo_alarms_v1': jsonEncode([sampleAlarm.toJson()]),
      });

      final storage = await StorageService.init();
      final alarms = storage.loadAlarms();
      expect(alarms.length, 1);
      expect(alarms.first.id, 'a1');
      expect(storage.prefs.containsKey('nestin_alarms_v1'), isTrue);
      expect(storage.prefs.containsKey('roodoo_alarms_v1'), isFalse);
    });
  });
}
