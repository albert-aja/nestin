import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/core/config/api_contracts.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/inspiration_models.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/inspiration_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/quote_card_export_service.dart';
import 'package:nestin/providers/inspiration_provider.dart';
import 'package:nestin/ui/screens/inspiration/inspiration_screen.dart';
import 'package:nestin/ui/screens/inspiration/quote_card_studio_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBackendTransport implements BackendHttpTransport {
  bool failAll = false;
  final Map<String, BackendHttpResponse> responses = {};
  final List<String> requestedPaths = [];

  @override
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    requestedPaths.add('$method ${uri.path}');
    if (failAll) {
      throw const SocketException('Simulated offline network');
    }
    final key = '$method ${uri.path}';
    if (responses.containsKey(key)) {
      return responses[key]!;
    }
    return const BackendHttpResponse(statusCode: 404, body: '{"error":"none"}');
  }
}

class _FakeNotificationService extends NotificationService {
  int scheduleCallCount = 0;
  int cancelCallCount = 0;
  int previewCallCount = 0;
  String? lastFrequency;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleDailyInspirationNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
    String frequency = 'DAILY',
    String? quoteId,
  }) async {
    scheduleCallCount += 1;
    lastFrequency = frequency;
  }

  @override
  Future<void> cancelDailyInspirationNotification() async {
    cancelCallCount += 1;
  }

  @override
  Future<void> showInspirationPreviewNotification({
    required String title,
    required String body,
    String? quoteId,
  }) async {
    previewCallCount += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testConfig = BackendGatewayConfig(
    apiBaseUrl: 'https://api.nestin.test',
    supabaseUrl: 'https://auth.nestin.test',
    supabaseAnonKey: 'anon-key',
  );

  group('InspirationService & InspirationProvider', () {
    test('caches featured quote offline and falls back to cache when disconnected',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      final transport = _FakeBackendTransport();

      transport.responses['GET /api/v1/inspiration/featured'] =
          BackendHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'success': true,
          'data': {
            'quote': {
              'id': '99990000-0000-0000-0000-000000000099',
              'quoteText': 'Fresh from backend featured slot.',
              'author': 'Roo • Time & Planning',
              'category': 'motivation',
              'locale': 'en',
              'isFeatured': true,
              'scheduledFor': '2026-11-15',
            },
          },
        }),
      );

      final service = InspirationService(
        prefs,
        gateway,
        config: testConfig,
        transport: transport,
      );

      final onlineQuote = await service.fetchDailyFeaturedQuote(locale: 'en');
      expect(onlineQuote.quoteText, 'Fresh from backend featured slot.');

      // Go offline -> cached backend featured quote must be served instead of blank/error
      transport.failAll = true;
      final offlineQuote = await service.fetchDailyFeaturedQuote(locale: 'en');
      expect(offlineQuote.quoteText, 'Fresh from backend featured slot.');
    });

    test('filters library by category, keyword, and favorites locally', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      final service = InspirationService(prefs, gateway);
      final provider = InspirationProvider(service);

      await provider.applyFilters(categorySlug: 'gratitude');
      expect(
        provider.quotes.every((q) => q.category == 'gratitude'),
        isTrue,
      );

      final target = provider.quotes.first;
      await provider.toggleFavorite(target);
      expect(provider.isFavorite(target.id), isTrue);

      await provider.applyFilters(
        clearCategory: true,
        favoritesOnly: true,
        search: target.quoteText.split(' ').first,
      );
      expect(provider.quotes.length, 1);
      expect(provider.quotes.first.id, target.id);
    });

    test('distinguishes offline draft submission from confirmed server submission',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      await gateway.saveAuthSession(
        SupabaseAuthSession(
          accessToken: 'jwt-valid-user',
          userId: 'user-1',
          email: 'user@nestin.app',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
        ),
      );
      final transport = _FakeBackendTransport()..failAll = true;

      final service = InspirationService(
        prefs,
        gateway,
        config: testConfig,
        transport: transport,
      );

      final personal = await service.createPersonalQuote(
        quoteText: 'Calm plans outlast noisy urgency.',
        authorName: 'Alya',
        category: InspirationService.starterCategories.first,
      );
      expect(personal.isLocalOnlyDraft, isTrue);

      final offlineAttempt = await service.submitQuoteForGlobalModeration(
        quote: personal,
        anonymousPublication: true,
        rightsConfirmed: true,
      );
      expect(offlineAttempt.isOfflineOrUnconfigured, isTrue);
      final queuedSubs = service.loadSubmissions();
      expect(queuedSubs.length, 1);
      expect(queuedSubs.first.isConfirmedByServer, isFalse);
      expect(queuedSubs.first.status, InspirationSubmissionStatus.draft);

      // Go online -> confirmed PENDING submission replaces draft
      transport.failAll = false;
      transport.responses['POST /api/v1/inspiration/me/submissions'] =
          BackendHttpResponse(
        statusCode: 201,
        body: jsonEncode({
          'success': true,
          'data': {
            'id': '88880000-0000-0000-0000-000000000001',
            'userQuoteId': personal.id,
            'status': 'PENDING',
            'anonymousPublication': true,
            'quoteText': personal.quoteText,
            'authorName': personal.authorName,
            'categoryId': personal.categoryId,
            'categorySlug': personal.categorySlug,
            'locale': 'en',
          },
        }),
      );

      final onlineAttempt = await service.submitQuoteForGlobalModeration(
        quote: personal,
        anonymousPublication: true,
        rightsConfirmed: true,
      );
      expect(onlineAttempt.isSuccess, isTrue);
      final confirmedSubs = service.loadSubmissions();
      expect(confirmedSubs.length, 1);
      expect(confirmedSubs.first.isConfirmedByServer, isTrue);
      expect(confirmedSubs.first.status, InspirationSubmissionStatus.pending);
    });

    test('notification preferences default to disabled and schedule only when opted in',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      final fakeNotifs = _FakeNotificationService();
      final service = InspirationService(prefs, gateway, config: testConfig);
      final provider = InspirationProvider(
        service,
        notificationService: fakeNotifs,
      );

      expect(provider.notificationPreferences.dailyEnabled, isFalse);
      await provider.initialize();
      expect(fakeNotifs.scheduleCallCount, 0);

      await provider.updateNotificationPreferences(
        provider.notificationPreferences.copyWith(
          dailyEnabled: true,
          preferredTime: '07:45',
          frequency: InspirationNotificationFrequency.weekdays,
        ),
      );
      expect(fakeNotifs.scheduleCallCount, 1);
      expect(fakeNotifs.lastFrequency, 'WEEKDAYS');

      await provider.updateNotificationPreferences(
        provider.notificationPreferences.copyWith(dailyEnabled: false),
      );
      expect(fakeNotifs.cancelCallCount, 1);
    });
  });

  group('InspirationScreen & QuoteCardStudioScreen Widgets', () {
    testWidgets('renders InspirationScreen featured quote & library across themes',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      final provider = InspirationProvider(
        InspirationService(prefs, gateway, config: testConfig),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const InspirationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DAILY FEATURED'), findsOneWidget);
      expect(find.textContaining('Small progress is still progress'),
          findsWidgets);
      expect(find.text('Open Quote Card'), findsOneWidget);

      await tester.tap(find.text('My Quotes'));
      await tester.pumpAndSettle();
      expect(find.text('New Personal Quote'), findsOneWidget);
    });

    testWidgets('QuoteCardStudioScreen renders preview, lock screen safe zone, and exports PNG bytes',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = BackendGatewayService(prefs, config: testConfig);
      final provider = InspirationProvider(
        InspirationService(prefs, gateway, config: testConfig),
      );
      final tempDir = await Directory.systemTemp.createTemp('nestin_card_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final boundaryKey = GlobalKey();
      final minimalPng = <int>[
        137, 80, 78, 71, 13, 10, 26, 10, // PNG header
        0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      ];
      var capturedRenderObjectMounted = false;
      final exportService = QuoteCardExportService(
        directoryProvider: () async => tempDir,
        shareInvoker: (_, _) async => true,
        capturePng: (key, ratio) async {
          final ro = key.currentContext?.findRenderObject();
          capturedRenderObjectMounted =
              ro is RenderRepaintBoundary && ro.size.width > 0;
          return Uint8List.fromList(minimalPng);
        },
      );

      debugPrint('STEP 1: pumping widget');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: QuoteCardStudioScreen(
              quoteText: 'Quiet steps compound cleanly over seasons.',
              authorName: 'Pippin • Curiosity & Craft',
              initialMascotDomain: 'pippin',
              exportService: exportService,
              previewBoundaryKey: boundaryKey,
            ),
          ),
        ),
      );
      debugPrint('STEP 2: settle after mount');
      await tester.pumpAndSettle();

      expect(find.textContaining('Quiet steps compound cleanly'), findsOneWidget);

      debugPrint('STEP 3: tap Lock Screen');
      await tester.tap(find.text('Lock Screen 9:16'));
      await tester.pumpAndSettle();
      expect(find.text('Lock Screen Clock Safe Zone'), findsOneWidget);

      debugPrint('STEP 4: ensureVisible Export PNG');
      await tester.ensureVisible(find.text('Export PNG'));
      await tester.pumpAndSettle();
      debugPrint('STEP 5: tap Export PNG');
      await tester.tap(find.text('Export PNG'));
      await tester.pump();
      debugPrint('STEP 6: runAsync io wait');
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        final cardsDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}nestin_quote_cards',
        );
        while (DateTime.now().isBefore(deadline)) {
          if (cardsDir.existsSync() &&
              cardsDir.listSync().any((f) => File(f.path).lengthSync() > 0)) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      debugPrint('STEP 7: settle after export');
      await tester.pumpAndSettle();

      expect(capturedRenderObjectMounted, isTrue);
      final savedFiles = Directory(
        '${tempDir.path}${Platform.pathSeparator}nestin_quote_cards',
      ).listSync();
      expect(savedFiles.length, 1);
      final bytes = File(savedFiles.first.path).readAsBytesSync();
      expect(bytes.take(4).toList(), [137, 80, 78, 71]);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved:'), findsOneWidget);
    });
  });
}
