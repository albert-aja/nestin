import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/audio_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/weather_service.dart';
import 'data/services/widget_sync_service.dart';
import 'providers/settings_provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/sound_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/task_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/note_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/wearable_provider.dart';
import 'providers/hydration_provider.dart';
import 'providers/sleep_wellness_provider.dart';
import 'providers/oem_hardening_provider.dart';
import 'providers/medication_provider.dart';
import 'providers/hobby_provider.dart';
import 'providers/health_wellness_provider.dart';
import 'providers/reading_provider.dart';
import 'providers/geofence_provider.dart';
import 'providers/before_you_go_provider.dart';
import 'providers/money_provider.dart';
import 'providers/caffeine_provider.dart';
import 'providers/device_control_provider.dart';
import 'providers/automation_provider.dart';
import 'providers/cross_module_link_provider.dart';
import 'providers/account_provider.dart';
import 'providers/inspiration_provider.dart';
import 'data/services/backend_gateway_service.dart';
import 'data/services/inspiration_service.dart';
import 'data/services/oem_hardening_service.dart';
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep portrait lock for clean alarm interaction
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = await StorageService.init();
  await storageService.migrateMoneySchemaIfNeeded();
  await AppLocalizations.ensureDateFormatting();
  final audioService = AudioService();
  final notificationService = NotificationService();
  await notificationService.init();
  WidgetSyncService.instance.initialize();

  runApp(
    NestinApp(
      storageService: storageService,
      audioService: audioService,
      notificationService: notificationService,
    ),
  );
}

class NestinApp extends StatelessWidget {
  final StorageService storageService;
  final AudioService audioService;
  final NotificationService notificationService;

  const NestinApp({
    super.key,
    required this.storageService,
    required this.audioService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => SoundProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AlarmProvider(
            storageService,
            audioService,
            notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReminderProvider(
            storageService,
            notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TimerProvider(
            storageService,
            notificationService,
            audioService,
          ),
        ),
        // Nestin Everyday Space expansion providers
        ChangeNotifierProvider(
          create: (_) => CalendarProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => RoutineProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => NoteProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => CollectionProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => WearableProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => HydrationProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => SleepWellnessProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => OemHardeningProvider(storageService, OemHardeningService()),
        ),
        ChangeNotifierProvider(
          create: (_) => MedicationProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => HobbyProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => HealthWellnessProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => ReadingProvider(
            storageService,
            notificationService: notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => GeofenceProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              BeforeYouGoProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => MoneyProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => CaffeineProvider(storageService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceControlProvider(
            storageService,
            notifications: notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AutomationProvider(
            storageService,
            ctx.read<DeviceControlProvider>(),
            tasks: ctx.read<TaskProvider>(),
            reminders: ctx.read<ReminderProvider>(),
            hydration: ctx.read<HydrationProvider>(),
            notifications: notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CrossModuleLinkProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AccountProvider(storageService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => InspirationProvider(
            InspirationService.live(
              storageService.prefs,
              BackendGatewayService(storageService.prefs),
            ),
            notificationService: notificationService,
          ),
        ),
        Provider<WeatherProviderInterface>(
          create: (_) => LocalWeatherService(),
        ),
        Provider<NotificationService>.value(
          value: notificationService,
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Nestin',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
