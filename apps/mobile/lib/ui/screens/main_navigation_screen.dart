import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/medication_snooze.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/widget_sync_service.dart';
import '../../providers/alarm_provider.dart';
import '../../providers/before_you_go_provider.dart';
import '../../providers/break_the_cycle_provider.dart';
import '../../providers/device_control_provider.dart';
import '../../providers/hydration_provider.dart';
import '../../providers/inspiration_provider.dart';
import '../../providers/medication_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/seren_relaxation_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/before_you_go_sheet.dart';
import '../widgets/fade_through_indexed_stack.dart';
import '../widgets/health_wellness_sheet.dart';
import '../widgets/hydration_settings_sheet.dart';
import '../widgets/location_reminders_sheet.dart';
import '../widgets/medication_tracker_sheet.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/reading_tracker_sheet.dart';
import '../widgets/seren/mindful_app_pause_dialog.dart';
import '../widgets/sleep_cycle_sheet.dart';
import 'alarms/active_alarm_screen.dart';
import 'alarms/alarm_edit_screen.dart';
import 'alarms/alarms_list_screen.dart';
import 'automation/automation_hub_screen.dart';
import 'discipline/digital_discipline_screen.dart';
import 'explore/bucket_list_screen.dart';
import 'home/home_dashboard_screen.dart';
import 'inspiration/inspiration_screen.dart';
import 'nest/bird_house_shared.dart';
import 'nest/echo_house_screen.dart';
import 'nest/nest_treehouse_screen.dart';
import 'nest/pippin_house_screen.dart';
import 'nest/roo_house_screen.dart';
import 'nest/scout_house_screen.dart';
import 'nest/seren_house_screen.dart';
import 'nest/twill_house_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'scout/phone_modes_screen.dart';
import 'search/universal_search_screen.dart';
import 'seren/mental_wellness_screen.dart';
import 'seren/seren_relaxation_screen.dart';
import 'settings/permission_center_screen.dart';
import 'time/calendar_screen.dart';
import 'time/routines_screen.dart';
import 'time/tasks_screen.dart';
import 'timers/timers_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  /// 0 = Dashboard (`HomeDashboardScreen`), 1 = Nest (`NestTreehouseScreen`).
  int _currentIndex = 0;
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
            _selectDockTab(1);
            SleepCycleSheet.show(context);
          } else if (payload == 'seren_health_move') {
            _selectDockTab(1);
            HealthWellnessSheet.show(context);
          } else if (payload == 'location_reminders') {
            _selectDockTab(1);
            LocationRemindersSheet.show(context);
          } else if (payload == BeforeYouGoProvider.payloadPrefix ||
              payload.startsWith('${BeforeYouGoProvider.payloadPrefix}|')) {
            final parsed = BeforeYouGoProvider.parsePayload(payload);
            _selectDockTab(1);
            BeforeYouGoSheet.show(
              context,
              initialPresetId: parsed?.presetId,
              initialEventId: parsed?.eventId,
            );
          } else if (payload.startsWith(MedicationSnooze.payloadPrefix)) {
            _selectDockTab(1);
            MedicationTrackerSheet.show(context);
          } else if (payload == ReadingProvider.reminderPayload ||
              payload == 'nestin://reading') {
            _selectDockTab(1);
            ReadingTrackerSheet.show(context);
          } else if (payload == 'mental_aid' ||
              payload == 'nestin://mental_aid' ||
              payload == 'mental_wellness') {
            _selectDockTab(1);
            final layer = (payload == 'mental_aid' ||
                    payload == 'nestin://mental_aid')
                ? 1
                : 0;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MentalWellnessScreen(initialLayer: layer),
              ),
            );
          } else if (payload.startsWith('nestin://')) {
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
        Provider.of<HydrationProvider>(context, listen: false)
            .reloadFromStorage();
      } catch (_) {}
      try {
        Provider.of<DeviceControlProvider>(context, listen: false)
            .refreshCapabilities();
      } catch (_) {}
      try {
        final btc = Provider.of<BreakTheCycleProvider>(context, listen: false);
        btc.reloadFromStorage();
        btc.checkForegroundAppForMindfulPause().then((pkg) {
          if (pkg != null && mounted) {
            MindfulAppPauseDialog.show(
              context,
              packageName: pkg,
              onStepBackToUrgeSupport: () {
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MentalWellnessScreen(
                      initialLayer: 3,
                      openUrgeSupportOnInit: true,
                    ),
                  ),
                );
              },
            );
          }
        });
      } catch (_) {}
      try {
        Provider.of<SettingsProvider>(context, listen: false)
            .evaluateAutoLock();
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

  void _selectDockTab(int index) {
    final target = index.clamp(0, 1);
    if (_currentIndex == target) return;
    setState(() {
      _currentIndex = target;
    });
  }

  /// Compatibility router bridging legacy 5-tab callbacks (from Dashboard
  /// links) to the 3-slot dock and 6 Bird House destinations.
  void _handleLegacyTabRoute(int tab, [int? subTab]) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (tab) {
      case 0:
        _selectDockTab(0);
        return;
      case 1:
        _selectDockTab(1);
        final target = switch (subTab) {
          0 => const AlarmsListScreen(),
          1 => const RemindersListScreen(),
          2 => BirdToolPageScaffold(
              title: l10n.tr('tab_calendar'),
              child: const CalendarScreen(),
            ),
          3 => BirdTwoTabPageScaffold(
              title: l10n.tr('house_roo_tasks_routines'),
              accentColor: RooHouseScreen.rooColor,
              firstLabel: l10n.tr('tab_tasks'),
              firstIcon: Icons.checklist_rounded,
              firstChild: const TasksScreen(),
              secondLabel: l10n.tr('tab_routines'),
              secondIcon: Icons.repeat_rounded,
              secondChild: const RoutinesScreen(),
              initialIndex: 0,
            ),
          4 => BirdTwoTabPageScaffold(
              title: l10n.tr('house_roo_tasks_routines'),
              accentColor: RooHouseScreen.rooColor,
              firstLabel: l10n.tr('tab_tasks'),
              firstIcon: Icons.checklist_rounded,
              firstChild: const TasksScreen(),
              secondLabel: l10n.tr('tab_routines'),
              secondIcon: Icons.repeat_rounded,
              secondChild: const RoutinesScreen(),
              initialIndex: 1,
            ),
          5 => const TimersScreen(),
          6 => const DigitalDisciplineScreen(),
          _ => const RooHouseScreen(),
        };
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => target),
        );
        return;
      case 2:
        _selectDockTab(1);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TwillHouseScreen(initialTabIndex: subTab ?? 0),
          ),
        );
        return;
      case 3:
        _selectDockTab(1);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EchoHouseScreen()),
        );
        return;
      case 4:
      default:
        _selectDockTab(1);
        return;
    }
  }

  void _handleDeepLink(Uri uri) {
    if (!mounted) return;
    final l10n = context.l10n;

    if (uri.host == 'alarms') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AlarmsListScreen()),
      );
    } else if (uri.host == 'habits') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BirdTwoTabPageScaffold(
            title: l10n.tr('house_roo_tasks_routines'),
            accentColor: RooHouseScreen.rooColor,
            firstLabel: l10n.tr('tab_tasks'),
            firstIcon: Icons.checklist_rounded,
            firstChild: const TasksScreen(),
            secondLabel: l10n.tr('tab_routines'),
            secondIcon: Icons.repeat_rounded,
            secondChild: const RoutinesScreen(),
            initialIndex: 1,
          ),
        ),
      );
    } else if (uri.host == 'new_alarm') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AlarmEditScreen()),
      );
    } else if (uri.host == 'wind_down' || uri.host == 'ambient_wind_down') {
      _selectDockTab(1);
      SleepCycleSheet.show(context);
    } else if (uri.host == 'health') {
      _selectDockTab(1);
      HealthWellnessSheet.show(context);
    } else if (uri.host == 'hydration') {
      _selectDockTab(1);
      if (uri.queryParameters['action'] == 'add_glass') {
        _logQuickGlass();
      } else {
        HydrationSettingsSheet.show(context);
      }
    } else if (uri.host == 'play_sound') {
      _playQuickSound(
        uri.queryParameters['id'] ?? 'rain',
        int.tryParse(uri.queryParameters['minutes'] ?? '') ?? 30,
      );
    } else if (uri.host == 'seren') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SerenRelaxationScreen()),
      );
    } else if (uri.host == 'medication') {
      _selectDockTab(1);
      MedicationTrackerSheet.show(context);
    } else if (uri.host == 'mental_aid' || uri.host == 'mental_wellness') {
      _selectDockTab(1);
      final layer = int.tryParse(uri.queryParameters['layer'] ?? '') ??
          (uri.host == 'mental_aid' ? 1 : 0);
      final openUrgeSupport = uri.queryParameters['urge_support'] == '1';
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MentalWellnessScreen(
            initialLayer: layer,
            openUrgeSupportOnInit: openUrgeSupport,
          ),
        ),
      );
    } else if (uri.host == 'reading') {
      _selectDockTab(1);
      ReadingTrackerSheet.show(context);
    } else if (uri.host == 'bucket_list') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BucketListScreen()),
      );
    } else if (uri.host == 'location_reminders') {
      _selectDockTab(1);
      LocationRemindersSheet.show(context);
    } else if (uri.host == 'before_you_go') {
      _selectDockTab(1);
      BeforeYouGoSheet.show(
        context,
        initialPresetId: uri.queryParameters['presetId'],
        initialEventId: uri.queryParameters['eventId'],
      );
    } else if (uri.host == 'money') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TwillHouseScreen(initialTabIndex: 3),
        ),
      );
    } else if (uri.host == 'quick_capture') {
      final type = uri.queryParameters['type'];
      CaptureType? captureType;
      if (type == 'note') {
        captureType = CaptureType.note;
      } else if (type == 'task') {
        captureType = CaptureType.task;
      } else if (type == 'reminder') {
        captureType = CaptureType.reminder;
      } else if (type == 'journal' || type == 'diary') {
        captureType = CaptureType.journal;
      } else if (type == 'wishlist') {
        captureType = CaptureType.wishlist;
      }
      QuickCaptureSheet.show(context, initialType: captureType);
    } else if (uri.host == 'wellbeing' || uri.host == 'discipline') {
      final rawTab = int.tryParse(uri.queryParameters['tab'] ?? '');
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DigitalDisciplineScreen(initialTab: rawTab ?? 0),
        ),
      );
    } else if (uri.host == 'phone_modes') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PhoneModesScreen()),
      );
    } else if (uri.host == 'permissions') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PermissionCenterScreen()),
      );
    } else if (uri.host == 'automation') {
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AutomationHubScreen()),
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
      _selectDockTab(1);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InspirationScreen(initialTab: initialTab),
        ),
      );
    } else if (uri.host == 'house') {
      _selectDockTab(1);
      final bird = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final Widget? screen = switch (bird) {
        'roo' => const RooHouseScreen(),
        'scout' => const ScoutHouseScreen(),
        'seren' => const SerenHouseScreen(),
        'pippin' => const PippinHouseScreen(),
        'twill' => const TwillHouseScreen(),
        'echo' => const EchoHouseScreen(),
        _ => null,
      };
      if (screen != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );
      }
    }
  }

  /// Launcher shortcut `nestin://hydration?action=add_glass`: logs +250ml.
  Future<void> _logQuickGlass() async {
    try {
      final hydration = Provider.of<HydrationProvider>(context, listen: false);
      await hydration.addGlass();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('shortcut_water_logged')),
        ),
      );
    } catch (_) {}
  }

  /// Launcher shortcut `nestin://play_sound?id=rain&minutes=30`: instantly
  /// plays one Seren sound with a sleep timer.
  Future<void> _playQuickSound(String soundId, int minutes) async {
    try {
      final seren =
          Provider.of<SerenRelaxationProvider>(context, listen: false);
      await seren.playSingleSound(soundId);
      await seren.startPlaybackTimer(minutes);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('shortcut_sound_playing')),
        ),
      );
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

    final pages = [
      HomeDashboardScreen(
        onNavigateTab: _handleLegacyTabRoute,
      ),
      NestTreehouseScreen(
        isActive: _currentIndex == 1,
      ),
    ];

    return Scaffold(
      body: FadeThroughIndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _ThreeSlotBottomDock(
        currentIndex: _currentIndex,
        onSelectTab: _selectDockTab,
        onQuickCaptureTap: () => QuickCaptureSheet.show(context),
        onQuickCaptureLongPress: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const UniversalSearchScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _ThreeSlotBottomDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onQuickCaptureTap;
  final VoidCallback onQuickCaptureLongPress;

  const _ThreeSlotBottomDock({
    required this.currentIndex,
    required this.onSelectTab,
    required this.onQuickCaptureTap,
    required this.onQuickCaptureLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final selectedColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final unselectedColor = AppColors.textSecondary(context);
    final surfaceColor = AppColors.recessedSurface(context);

    return Material(
      color: surfaceColor,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: AppColors.border(context), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    // Left Slot: Dashboard
                    Expanded(
                      child: _DockTabItem(
                        itemKey: const Key('nav_slot_dashboard'),
                        icon: Icons.space_dashboard_outlined,
                        activeIcon: Icons.space_dashboard_rounded,
                        label: l10n.tr('nav_dashboard'),
                        isSelected: currentIndex == 0,
                        selectedColor: selectedColor,
                        unselectedColor: unselectedColor,
                        onTap: () => onSelectTab(0),
                      ),
                    ),
                    // Spacer reserving clean breathing room for center raised button
                    const SizedBox(width: 84),
                    // Right Slot: Nest
                    Expanded(
                      child: _DockTabItem(
                        itemKey: const Key('nav_slot_nest'),
                        icon: Icons.cottage_outlined,
                        activeIcon: Icons.cottage_rounded,
                        label: l10n.tr('nav_nest'),
                        isSelected: currentIndex == 1,
                        selectedColor: selectedColor,
                        unselectedColor: unselectedColor,
                        onTap: () => onSelectTab(1),
                      ),
                    ),
                  ],
                ),
                // Center Slot: Raised Nestin Crimson (+) Quick Capture Button
                Positioned(
                  top: -16,
                  child: Tooltip(
                    message: l10n.tr('nav_quick_capture_hint'),
                    child: Semantics(
                      button: true,
                      label: l10n.tr('quick_capture'),
                      child: GestureDetector(
                        key: const Key('nav_slot_quick_capture'),
                        onTap: onQuickCaptureTap,
                        onLongPress: onQuickCaptureLongPress,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(
                              color: surfaceColor,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: isDark ? 0.42 : 0.34),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockTabItem extends StatelessWidget {
  final Key itemKey;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _DockTabItem({
    required this.itemKey,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return InkWell(
      key: itemKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? selectedColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
