import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/config/api_contracts.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/money_transaction.dart';
import 'package:nestin/data/models/note_item.dart';
import 'package:nestin/data/models/task_item.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/account_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';

class _RecordedRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, dynamic>? jsonBody;

  _RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.jsonBody,
  });
}

class _FakeBackendTransport implements BackendHttpTransport {
  final List<_RecordedRequest> requests = [];
  final BackendHttpResponse Function(_RecordedRequest req) handler;

  _FakeBackendTransport(this.handler);

  @override
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    Map<String, dynamic>? parsedBody;
    if (body != null && body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        parsedBody = decoded;
      }
    }
    final req = _RecordedRequest(
      method: method,
      uri: uri,
      headers: headers,
      jsonBody: parsedBody,
    );
    requests.add(req);
    return handler(req);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const configuredEndpoints = BackendGatewayConfig(
    apiBaseUrl: 'https://api.nestin.test',
    supabaseUrl: 'https://proj.supabase.co',
    supabaseAnonKey: 'anon-key-test',
  );

  Future<void> seedSampleLocalData(StorageService storage) async {
    final now = DateTime.utc(2026, 11, 14, 9, 0);
    await storage.saveAlarms([
      Alarm(
        id: 'alarm-local-1',
        title: 'Morning Rooster',
        hour: 6,
        minute: 30,
        category: AlarmCategory.predefined.first,
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await storage.saveTasks([
      TaskItem(
        id: 'task-local-1',
        title: 'Water plants',
        category: AlarmCategory.predefined.first,
        createdAt: now,
      ),
    ]);
    await storage.saveNotes([
      NoteItem(
        id: 'note-local-1',
        title: 'Recipe Idea',
        content: 'Crispy tempeh',
        category: AlarmCategory.predefined.first,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await storage.saveMoneyTransactions([
      MoneyTransaction(
        id: 'tx-local-1',
        type: MoneyTransactionType.expense,
        amountMinor: 25000,
        accountId: 'acc-cash',
        categoryId: 'cat-food',
        transactionDate: DateTime.utc(2026, 11, 14, 12, 0),
        description: 'Nasi uduk',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  group('Optional Supabase Account & Guest Migration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'signUpWithSupabase + prepareGuestMigration links Guest UUID without altering local records',
      () async {
        final storage = await StorageService.init();
        await seedSampleLocalData(storage);

        final transport = _FakeBackendTransport((req) {
          if (req.uri.path == '/auth/v1/signup') {
            return BackendHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'access_token': 'jwt-access-123',
                'refresh_token': 'jwt-refresh-123',
                'expires_in': 3600,
                'user': {
                  'id': 'supa-user-uuid-1',
                  'email': 'alex@nestin.app',
                  'user_metadata': {
                    'display_name': 'Alex',
                    'preferred_language': 'id',
                  },
                },
              }),
            );
          }
          if (req.uri.path == '/api/v1/auth/guest-migration/prepare') {
            return BackendHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'userId': 'supa-user-uuid-1',
                  'guestLocalId': req.jsonBody?['guestLocalId'],
                  'migratedAt': '2026-11-14T16:00:00.000Z',
                  'localDataPreserved': true,
                  'cloudSyncOptIn': false,
                  'acknowledgedLocalCounts': req.jsonBody?['localRecordCounts'],
                },
              }),
            );
          }
          if (req.uri.path == '/auth/v1/logout') {
            return const BackendHttpResponse(statusCode: 204, body: '');
          }
          return const BackendHttpResponse(statusCode: 404, body: '{}');
        });

        final gateway = BackendGatewayService(
          storage.prefs,
          config: configuredEndpoints,
          transport: transport,
        );
        final initialGuest = await gateway.ensureGuestIdentity();

        final signUpRes = await gateway.signUpWithSupabase(
          email: 'alex@nestin.app',
          password: 'password123',
          displayName: 'Alex',
          preferredLanguage: 'id',
        );
        expect(signUpRes.isSuccess, isTrue);
        expect(signUpRes.data?.requiresEmailConfirmation, isFalse);
        expect(signUpRes.data?.session?.accessToken, 'jwt-access-123');
        expect(signUpRes.data?.session?.userId, 'supa-user-uuid-1');

        final countsBefore = storage.collectLocalRecordCounts();
        final migrationRes = await gateway.prepareGuestMigration(
          preferredLanguage: 'id',
          localRecordCounts: countsBefore,
        );
        expect(migrationRes.isSuccess, isTrue);
        expect(migrationRes.data?.guestLocalId, initialGuest.guestLocalId);
        expect(migrationRes.data?.localDataPreserved, isTrue);
        expect(migrationRes.data?.cloudSyncOptIn, isFalse);
        expect(migrationRes.data?.acknowledgedLocalCounts['alarms'], 1);
        expect(migrationRes.data?.acknowledgedLocalCounts['tasks'], 1);
        expect(migrationRes.data?.acknowledgedLocalCounts['notes'], 1);
        expect(
          migrationRes.data?.acknowledgedLocalCounts['moneyTransactions'],
          1,
        );

        // Verify exact outbound request contracts
        final prepareReq = transport.requests.firstWhere(
          (r) => r.uri.path == '/api/v1/auth/guest-migration/prepare',
        );
        expect(prepareReq.method, 'POST');
        expect(prepareReq.headers['authorization'], 'Bearer jwt-access-123');
        expect(prepareReq.jsonBody?.keys.toSet(), {
          'guestLocalId',
          'preferredLanguage',
          'localRecordCounts',
        });

        // Verify guest profile linked locally with cloudSyncOptIn still false
        final linkedGuest = await gateway.ensureGuestIdentity();
        expect(linkedGuest.guestLocalId, initialGuest.guestLocalId);
        expect(linkedGuest.authMode, AccountAuthMode.registered);
        expect(linkedGuest.linkedUserId, 'supa-user-uuid-1');
        expect(linkedGuest.cloudSyncOptIn, isFalse);

        // Verify ALL local records remain completely unaltered
        expect(storage.loadAlarms().single.title, 'Morning Rooster');
        expect(storage.loadTasks().single.title, 'Water plants');
        expect(storage.loadNotes().single.content, 'Crispy tempeh');
        expect(storage.loadMoneyTransactions().single.amountMinor, 25000);

        // Verify sign-out reverts session but leaves local data & guestLocalId intact
        await gateway.signOut();
        expect(gateway.loadStoredAuthSession(), isNull);
        final afterSignOut = await gateway.ensureGuestIdentity();
        expect(afterSignOut.guestLocalId, initialGuest.guestLocalId);
        expect(afterSignOut.authMode, AccountAuthMode.guest);
        expect(storage.loadAlarms().single.id, 'alarm-local-1');
        expect(storage.loadMoneyTransactions().single.id, 'tx-local-1');
      },
    );

    test(
      'signUpWithSupabase handles email confirmation requirement honestly',
      () async {
        final storage = await StorageService.init();
        final transport = _FakeBackendTransport((req) {
          return BackendHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'id': 'pending-user-1',
              'email': 'verify@nestin.app',
              'confirmation_sent_at': '2026-11-14T16:00:00.000Z',
            }),
          );
        });

        final gateway = BackendGatewayService(
          storage.prefs,
          config: configuredEndpoints,
          transport: transport,
        );
        final res = await gateway.signUpWithSupabase(
          email: 'verify@nestin.app',
          password: 'password123',
        );
        expect(res.isSuccess, isTrue);
        expect(res.data?.requiresEmailConfirmation, isTrue);
        expect(res.data?.pendingEmail, 'verify@nestin.app');
        expect(res.data?.session, isNull);
        expect(gateway.loadStoredAuthSession(), isNull);
      },
    );

    testWidgets(
      'SettingsScreen renders Nestin Account (Optional) and triggers sign-up + guest migration prepare without altering local records',
      (tester) async {
        final storage = await StorageService.init();
        await seedSampleLocalData(storage);

        final transport = _FakeBackendTransport((req) {
          if (req.uri.path == '/auth/v1/signup') {
            return BackendHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'access_token': 'widget-jwt-token',
                'refresh_token': 'widget-refresh-token',
                'expires_in': 3600,
                'user': {
                  'id': 'supa-widget-user',
                  'email': 'rina@nestin.app',
                },
              }),
            );
          }
          if (req.uri.path == '/api/v1/auth/guest-migration/prepare') {
            return BackendHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'userId': 'supa-widget-user',
                  'guestLocalId': req.jsonBody?['guestLocalId'],
                  'migratedAt': '2026-11-14T16:05:00.000Z',
                  'localDataPreserved': true,
                  'cloudSyncOptIn': false,
                  'acknowledgedLocalCounts': req.jsonBody?['localRecordCounts'],
                },
              }),
            );
          }
          return const BackendHttpResponse(statusCode: 204, body: '');
        });

        final gateway = BackendGatewayService(
          storage.prefs,
          config: configuredEndpoints,
          transport: transport,
        );
        final accountProvider = AccountProvider(storage, gateway: gateway);
        await accountProvider.initialize();
        final settingsProvider = SettingsProvider(storage);
        final oemProvider = OemHardeningProvider(
          storage,
          MockOemHardeningService(
            manufacturer: 'Pixel',
            brand: 'Google',
            model: 'Pixel 9',
            isIgnoringBatteryOptimizations: true,
            isKeepAliveRunning: false,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<StorageService>.value(value: storage),
              Provider<NotificationService>.value(value: NotificationService()),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
              ChangeNotifierProvider<SoundProvider>(
                create: (_) => SoundProvider(storage),
              ),
              ChangeNotifierProvider<WearableProvider>(
                create: (_) => WearableProvider(storage),
              ),
              ChangeNotifierProvider<OemHardeningProvider>.value(
                value: oemProvider,
              ),
              ChangeNotifierProvider<GeofenceProvider>(
                create: (_) => GeofenceProvider(
                  storage,
                  NotificationService(),
                  autoInitializeNative: false,
                ),
              ),
              ChangeNotifierProvider<MoneyProvider>(
                create: (_) => MoneyProvider(storage),
              ),
              ChangeNotifierProvider<AccountProvider>.value(
                value: accountProvider,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.text('Nestin Account (Optional)');
        await tester.scrollUntilVisible(
          tileFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tileFinder, findsOneWidget);
        expect(find.text('Guest'), findsOneWidget);

        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Modal sheet opens with local-first guarantee and local counts intact
        expect(find.textContaining('Local-First Guarantee:'), findsOneWidget);
        expect(
          find.textContaining(accountProvider.guestIdentity!.guestLocalId),
          findsOneWidget,
        );
        expect(find.text('Alarms: 1'), findsOneWidget);
        expect(find.text('Tasks: 1'), findsOneWidget);

        // Fill optional sign-up form and submit
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Display Name (Optional)'),
          'Rina',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'rina@nestin.app',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'secret123',
        );
        final createBtn = find.text('Create Optional Account');
        await tester.ensureVisible(createBtn);
        await tester.pumpAndSettle();
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        // Both Supabase signup and /api/v1/auth/guest-migration/prepare ran
        expect(
          transport.requests.map((r) => r.uri.path).toList(),
          ['/auth/v1/signup', '/api/v1/auth/guest-migration/prepare'],
        );
        expect(find.text('rina@nestin.app'), findsOneWidget);
        expect(find.text('Cloud Sync: Off (Local-First)'), findsOneWidget);
        expect(find.text('Migration Link Acknowledged'), findsOneWidget);

        // Local records remain completely untouched
        expect(storage.loadAlarms().single.title, 'Morning Rooster');
        expect(storage.loadTasks().single.title, 'Water plants');
        expect(storage.loadNotes().single.content, 'Crispy tempeh');
        expect(storage.loadMoneyTransactions().single.amountMinor, 25000);

        // Explicit Refresh / Prepare Migration button works again
        final refreshBtn = find.text('Refresh Guest Migration Link');
        await tester.ensureVisible(refreshBtn);
        await tester.pumpAndSettle();
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();
        expect(
          transport.requests
              .where((r) => r.uri.path == '/api/v1/auth/guest-migration/prepare')
              .length,
          2,
        );

        // Sign out preserves all local records
        final signOutBtn = find.text('Sign Out (Keep Local Data)');
        await tester.ensureVisible(signOutBtn);
        await tester.pumpAndSettle();
        await tester.tap(signOutBtn);
        await tester.pumpAndSettle();
        expect(accountProvider.isSignedIn, isFalse);
        expect(storage.loadAlarms().single.title, 'Morning Rooster');
        expect(storage.loadTasks().single.title, 'Water plants');
      },
    );

    testWidgets(
      'Nestin Account (Optional) renders cleanly in Dark Mode and offline builds',
      (tester) async {
        final storage = await StorageService.init();
        await seedSampleLocalData(storage);

        final offlineGateway = BackendGatewayService(storage.prefs);
        final accountProvider = AccountProvider(
          storage,
          gateway: offlineGateway,
        );
        await accountProvider.initialize();
        final settingsProvider = SettingsProvider(storage);
        final oemProvider = OemHardeningProvider(
          storage,
          MockOemHardeningService(
            manufacturer: 'Pixel',
            brand: 'Google',
            model: 'Pixel 9',
            isIgnoringBatteryOptimizations: true,
            isKeepAliveRunning: false,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<StorageService>.value(value: storage),
              Provider<NotificationService>.value(value: NotificationService()),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
              ChangeNotifierProvider<SoundProvider>(
                create: (_) => SoundProvider(storage),
              ),
              ChangeNotifierProvider<WearableProvider>(
                create: (_) => WearableProvider(storage),
              ),
              ChangeNotifierProvider<OemHardeningProvider>.value(
                value: oemProvider,
              ),
              ChangeNotifierProvider<GeofenceProvider>(
                create: (_) => GeofenceProvider(
                  storage,
                  NotificationService(),
                  autoInitializeNative: false,
                ),
              ),
              ChangeNotifierProvider<MoneyProvider>(
                create: (_) => MoneyProvider(storage),
              ),
              ChangeNotifierProvider<AccountProvider>.value(
                value: accountProvider,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.text('Nestin Account (Optional)');
        await tester.scrollUntilVisible(
          tileFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('Offline-only build:'), findsOneWidget);
        expect(find.text('Alarms: 1'), findsOneWidget);
      },
    );
  });
}
