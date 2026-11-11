import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/audio_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/weather_service.dart';
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
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep portrait lock for clean alarm interaction
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = await StorageService.init();
  final audioService = AudioService();
  final notificationService = NotificationService();
  await notificationService.init();

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
        // RooDoo Everyday Space expansion providers
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
        Provider<WeatherProviderInterface>(
          create: (_) => LocalWeatherService(),
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
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}

typedef RooDooApp = NestinApp;
