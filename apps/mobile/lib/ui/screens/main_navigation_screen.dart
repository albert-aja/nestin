import 'dart:async';
import 'package:flutter/material.dart';
import 'inspiration/inspiration_screen.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/medication_snooze.dart';
import '../../data/services/widget_sync_service.dart';
import '../../data/services/notification_service.dart';
import '../../providers/alarm_provider.dart';
import '../../providers/medication_provider.dart';
import '../../providers/before_you_go_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/inspiration_provider.dart';
import '../../providers/settings_provider.dart';
import 'home/home_dashboard_screen.dart';
import 'time/time_hub_screen.dart';
import 'organize/organize_hub_screen.dart';
import 'journal/journal_hub_screen.dart';
import 'explore/explore_hub_screen.dart';
import 'alarms/active_alarm_screen.dart';
import 'alarms/alarm_edit_screen.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/sleep_cycle_sheet.dart';
import '../widgets/health_wellness_sheet.dart';
import '../widgets/medication_tracker_sheet.dart';
import '../widgets/reading_tracker_sheet.dart';
import '../widgets/location_reminders_sheet.dart';
import '../widgets/before_you_go_sheet.dart';
import 'scout/digital_wellbeing_screen.dart';
import 'settings/permission_center_screen.dart';
import 'automation/automation_hub_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _timeHubSubTab = 0;
  int _organizeHubSubTab = 0;
  int _journalHubSubTab = 0;
  StreamSubscription<Uri>? _deepLinkSubscription;
  StreamSubscription<String>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deepLinkSubscription =
        WidgetSyncService.instance.deepLinkStream.listen(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final notifService =
            Provider.of<NotificationService>(context, listen: false);
        _notifSubscription = notifService.payloadStream.listen((payload) {
          if (!mounted) return;
          if (payload == 'wind_down_ambient' || payload == 'wind_down') {
            _onTabSelected(4);
            SleepCycleSheet.show(context);
          } else if (payload == 'seren_health_move') {
            _onTabSelected(4);
            HealthWellnessSheet.show(context);
          } else if (payload == 'location_reminders') {
            _onTabSelected(4);
            LocationRemindersSheet.show(context);
          } else if (payload == BeforeYouGoProvider.payloadPrefix ||
              payload.startsWith('${BeforeYouGoProvider.payloadPrefix}|')) {
            final parsed = BeforeYouGoProvider.parsePayload(payload);
            _onTabSelected(4);
            BeforeYouGoSheet.show(
              context,
              initialPresetId: parsed?.presetId,
              initialEventId: parsed?.eventId,
            );
          } else if (payload.startsWith(MedicationSnooze.payloadPrefix)) {
            _onTabSelected(4);
            MedicationTrackerSheet.show(context);
          } else if (payload == ReadingProvider.reminderPayload ||
              payload == 'nestin://reading') {
            _onTabSelected(4);
            ReadingTrackerSheet.show(context);
          } else if (payload.startsWith('nestin://inspiration')) {
            final uri = Uri.tryParse(payload);
            if (uri != null) {
              _handleDeepLink(uri);
            }
          }
        });
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      try {
        Provider.of<MedicationProvider>(context, listen: false)
            .reloadFromStorage();
      } catch (_) {}
      try {
        Provider.of<BeforeYouGoProvider>(context, listen: false)
            .reloadFromStorage();
      } catch (_) {}
      try {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (_currentIndex == 3) {
          settings.notifyDiaryEntered();
        } else {
          settings.evaluateAutoLock();
        }
      } catch (_) {}
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      try {
        Provider.of<SettingsProvider>(context, listen: false)
            .notifyDiaryLeft();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _handleDeepLink(Uri uri) {
    if (!mounted) return;

    if (uri.host == 'alarms') {
      _onTabSelected(1, 0); // TimeHub -> Alarms
    } else if (uri.host == 'habits') {
      _onTabSelected(1, 4); // TimeHub -> Routines
    } else if (uri.host == 'new_alarm') {
      _onTabSelected(1, 0);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
      );
    } else if (uri.host == 'wind_down' || uri.host == 'ambient_wind_down') {
      _onTabSelected(4);
      SleepCycleSheet.show(context);
    } else if (uri.host == 'health') {
      _onTabSelected(4);
      HealthWellnessSheet.show(context);
    } else if (uri.host == 'medication') {
      _onTabSelected(4);
      MedicationTrackerSheet.show(context);
    } else if (uri.host == 'reading') {
      _onTabSelected(4);
      ReadingTrackerSheet.show(context);
    } else if (uri.host == 'location_reminders') {
      _onTabSelected(4);
      LocationRemindersSheet.show(context);
    } else if (uri.host == 'before_you_go') {
      _onTabSelected(4);
      BeforeYouGoSheet.show(
        context,
        initialPresetId: uri.queryParameters['presetId'],
        initialEventId: uri.queryParameters['eventId'],
      );
    } else if (uri.host == 'money') {
      _onTabSelected(2, 3);
    } else if (uri.host == 'quick_capture') {
      final type = uri.queryParameters['type'];
      CaptureType captureType = CaptureType.note;
      if (type == 'task') {
        captureType = CaptureType.task;
      } else if (type == 'journal') {
        captureType = CaptureType.journal;
      }
      QuickCaptureSheet.show(context, initialType: captureType);
    } else if (uri.host == 'wellbeing') {
      _onTabSelected(4);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DigitalWellbeingScreen()),
      );
    } else if (uri.host == 'permissions') {
      _onTabSelected(4);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PermissionCenterScreen()),
      );
    } else if (uri.host == 'automation') {
      _onTabSelected(4);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AutomationHubScreen()),
      );
    } else if (uri.host == 'inspiration') {
      final quoteId = uri.queryParameters['quoteId'];
      final tabParam = uri.queryParameters['tab'];
      final inspProvider =
          Provider.of<InspirationProvider>(context, listen: false);
      if (quoteId != null && quoteId.isNotEmpty) {
        inspProvider.highlightQuote(quoteId);
      }
      final initialTab = tabParam == 'submissions'
          ? InspirationSectionTab.submissions
          : (tabParam == 'favorites'
              ? InspirationSectionTab.favorites
              : InspirationSectionTab.browse);
      _onTabSelected(4);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InspirationScreen(initialTab: initialTab),
        ),
      );
    }
  }

  void _onTabSelected(int index, [int? subTabIndex]) {
    final wasInJournal = _currentIndex == 3;
    final willBeInJournal = index == 3;

    setState(() {
      _currentIndex = index;
      if (index == 1 && subTabIndex != null) {
        _timeHubSubTab = subTabIndex;
      } else if (index == 2 && subTabIndex != null) {
        _organizeHubSubTab = subTabIndex;
      } else if (index == 3 && subTabIndex != null) {
        _journalHubSubTab = subTabIndex;
      }
    });

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (wasInJournal && !willBeInJournal) {
        settings.notifyDiaryLeft();
      } else if (!wasInJournal && willBeInJournal) {
        settings.notifyDiaryEntered();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final ringingAlarm = alarmProvider.ringingAlarm;

    // Full-screen Active Alarm Trigger Overlay (Preserved)
    if (ringingAlarm != null) {
      return ActiveAlarmScreen(alarm: ringingAlarm);
    }

    final l10n = context.l10n;
    final pages = [
      HomeDashboardScreen(
        onNavigateTab: (tab, [subTab]) => _onTabSelected(tab, subTab),
      ),
      TimeHubScreen(
        key: ValueKey('time_$_timeHubSubTab'),
        initialTabIndex: _timeHubSubTab,
      ),
      OrganizeHubScreen(
        key: ValueKey('organize_$_organizeHubSubTab'),
        initialTabIndex: _organizeHubSubTab,
      ),
      JournalHubScreen(
        key: ValueKey('journal_$_journalHubSubTab'),
        initialTabIndex: _journalHubSubTab,
      ),
      const ExploreHubScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickCaptureSheet.show(context),
        backgroundColor: AppColors.primary,
        tooltip: l10n.tr('quick_capture'),
        elevation: 4,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.recessedSurface(context),
          border: Border(
            top: BorderSide(color: AppColors.border(context), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => _onTabSelected(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.recessedSurface(context),
          selectedItemColor: AppColors.isDark(context)
              ? AppColors.primaryLight
              : AppColors.primary,
          unselectedItemColor: AppColors.textSecondary(context),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.today_outlined),
              activeIcon: const Icon(Icons.today_rounded),
              label: l10n.tr('nav_today'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.access_time_outlined),
              activeIcon: const Icon(Icons.access_time_filled_rounded),
              label: l10n.tr('nav_time'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder_outlined),
              activeIcon: const Icon(Icons.folder_rounded),
              label: l10n.tr('nav_organize'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_outlined),
              activeIcon: const Icon(Icons.auto_stories_rounded),
              label: l10n.tr('nav_journal'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_outlined),
              activeIcon: const Icon(Icons.explore_rounded),
              label: l10n.tr('nav_explore'),
            ),
          ],
        ),
      ),
    );
  }
}
