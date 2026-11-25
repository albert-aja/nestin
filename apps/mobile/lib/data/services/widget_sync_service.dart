import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/alarm.dart';
import '../models/hydration_data.dart';
import '../models/routine_item.dart';

/// Describes a mascot companion avatar rendered on an Android Glance AppWidget.
class WidgetMascotAvatar {
  final String widgetType;
  final String actionSlot;
  final String mascotName;
  final String domain;
  final String drawableKey;
  final String assetPath;
  final String moodLabel;

  const WidgetMascotAvatar({
    required this.widgetType,
    required this.actionSlot,
    required this.mascotName,
    required this.domain,
    required this.drawableKey,
    required this.assetPath,
    required this.moodLabel,
  });
}

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('com.nestin.app/widgets');

  static final WidgetSyncService instance = WidgetSyncService._();
  WidgetSyncService._();

  @visibleForTesting
  Future<dynamic> Function(String method, Map<String, dynamic> args)?
      methodInvoker;

  StreamController<Uri>? _deepLinkController;
  Stream<Uri> get deepLinkStream {
    _deepLinkController ??= StreamController<Uri>.broadcast();
    return _deepLinkController!.stream;
  }

  StreamController<void>? _hydrationUpdateController;
  Stream<void> get hydrationWidgetUpdates {
    _hydrationUpdateController ??= StreamController<void>.broadcast();
    return _hydrationUpdateController!.stream;
  }

  bool _initialized = false;
  bool _showMascotsEnabled = true;

  bool get showMascotsEnabled => _showMascotsEnabled;

  void setShowMascotsEnabled(bool enabled) {
    _showMascotsEnabled = enabled;
  }

  /// Dynamically toggles Android lock-screen bypass (`setShowWhenLocked` /
  /// `setTurnScreenOn` + `FLAG_KEEP_SCREEN_ON`) strictly while an alarm is
  /// actively ringing so normal app usage locks cleanly with the phone.
  Future<void> setAlarmLockScreenMode(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (methodInvoker != null) {
        await methodInvoker!('setAlarmLockScreenMode', {'enabled': enabled});
        return;
      }
      await _channel.invokeMethod<void>(
        'setAlarmLockScreenMode',
        {'enabled': enabled},
      );
    } catch (_) {}
  }

  static const List<WidgetMascotAvatar> quickCaptureMascots = [
    WidgetMascotAvatar(
      widgetType: 'quick_capture',
      actionSlot: 'capture',
      mascotName: 'Scout',
      domain: 'scout',
      drawableKey: 'scout_captured',
      assetPath: 'assets/mascots/sprites/scout/captured.png',
      moodLabel: 'Quick Capture',
    ),
    WidgetMascotAvatar(
      widgetType: 'quick_capture',
      actionSlot: 'note',
      mascotName: 'Twill',
      domain: 'twill',
      drawableKey: 'twill_noted',
      assetPath: 'assets/mascots/sprites/twill/noted.png',
      moodLabel: 'Note',
    ),
    WidgetMascotAvatar(
      widgetType: 'quick_capture',
      actionSlot: 'task',
      mascotName: 'Roo',
      domain: 'roo',
      drawableKey: 'roo_planning',
      assetPath: 'assets/mascots/sprites/roo/planning.png',
      moodLabel: 'Task',
    ),
    WidgetMascotAvatar(
      widgetType: 'quick_capture',
      actionSlot: 'alarm',
      mascotName: 'Roo',
      domain: 'roo',
      drawableKey: 'roo_alarm',
      assetPath: 'assets/mascots/sprites/roo/alarm.png',
      moodLabel: 'Alarm',
    ),
    WidgetMascotAvatar(
      widgetType: 'quick_capture',
      actionSlot: 'journal',
      mascotName: 'Echo',
      domain: 'echo',
      drawableKey: 'echo_reflect',
      assetPath: 'assets/mascots/sprites/echo/reflect.png',
      moodLabel: 'Journal',
    ),
  ];

  /// Selects Roo's mini avatar expression for the Next Alarm Android widget.
  static WidgetMascotAvatar resolveAlarmMascot(Alarm? alarm, {DateTime? now}) {
    if (alarm == null || !alarm.isEnabled) {
      return const WidgetMascotAvatar(
        widgetType: 'next_alarm',
        actionSlot: 'alarm',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_quiet',
        assetPath: 'assets/mascots/sprites/roo/quiet_day.png',
        moodLabel: 'Quiet Day',
      );
    }

    final ref = now ?? DateTime.now();
    final diff = alarm.nextOccurrence(ref).difference(ref);
    if (!diff.isNegative && diff.inMinutes <= 60) {
      return const WidgetMascotAvatar(
        widgetType: 'next_alarm',
        actionSlot: 'alarm',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_hurry',
        assetPath: 'assets/mascots/sprites/roo/hurry.png',
        moodLabel: 'Soon',
      );
    }

    return const WidgetMascotAvatar(
      widgetType: 'next_alarm',
      actionSlot: 'alarm',
      mascotName: 'Roo',
      domain: 'roo',
      drawableKey: 'roo_alarm',
      assetPath: 'assets/mascots/sprites/roo/alarm.png',
      moodLabel: 'Scheduled',
    );
  }

  /// Selects Roo's mini avatar expression for the Daily Habits Android widget.
  static WidgetMascotAvatar resolveHabitsMascot(RoutineItem? routine) {
    if (routine == null || routine.steps.isEmpty) {
      return const WidgetMascotAvatar(
        widgetType: 'habits',
        actionSlot: 'habits',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_quiet',
        assetPath: 'assets/mascots/sprites/roo/quiet_day.png',
        moodLabel: 'No Routines',
      );
    }

    if (routine.isCompletedToday) {
      return const WidgetMascotAvatar(
        widgetType: 'habits',
        actionSlot: 'habits',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_habit_done',
        assetPath: 'assets/mascots/sprites/roo/habit_done.png',
        moodLabel: 'Habit Done',
      );
    }

    if (routine.streakCount >= 3 && routine.completedStepIndices.isNotEmpty) {
      return const WidgetMascotAvatar(
        widgetType: 'habits',
        actionSlot: 'habits',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_on_fire',
        assetPath: 'assets/mascots/sprites/roo/on_fire.png',
        moodLabel: 'On Fire',
      );
    }

    if (routine.completedStepIndices.isNotEmpty) {
      return const WidgetMascotAvatar(
        widgetType: 'habits',
        actionSlot: 'habits',
        mascotName: 'Roo',
        domain: 'roo',
        drawableKey: 'roo_momentum',
        assetPath: 'assets/mascots/sprites/roo/momentum.png',
        moodLabel: 'In Progress',
      );
    }

    return const WidgetMascotAvatar(
      widgetType: 'habits',
      actionSlot: 'habits',
      mascotName: 'Roo',
      domain: 'roo',
      drawableKey: 'roo_planning',
      assetPath: 'assets/mascots/sprites/roo/planning.png',
      moodLabel: 'Ready',
    );
  }

  /// Selects Seren's mini avatar expression for the Hydration Home/Lock Screen widget.
  static WidgetMascotAvatar resolveHydrationMascot(HydrationData data) {
    if (data.isGoalMet) {
      return const WidgetMascotAvatar(
        widgetType: 'hydration',
        actionSlot: 'hydration',
        mascotName: 'Seren',
        domain: 'seren',
        drawableKey: 'seren_refreshed',
        assetPath: 'assets/mascots/sprites/seren/refreshed.png',
        moodLabel: 'Goal Met',
      );
    }

    if (data.progressFraction >= 0.5) {
      return const WidgetMascotAvatar(
        widgetType: 'hydration',
        actionSlot: 'hydration',
        mascotName: 'Seren',
        domain: 'seren',
        drawableKey: 'seren_you_go',
        assetPath: 'assets/mascots/sprites/seren/you_go.png',
        moodLabel: 'Keep Going',
      );
    }

    return const WidgetMascotAvatar(
      widgetType: 'hydration',
      actionSlot: 'hydration',
      mascotName: 'Seren',
      domain: 'seren',
      drawableKey: 'seren_hydrate',
      assetPath: 'assets/mascots/sprites/seren/hydrate.png',
      moodLabel: 'Hydrate',
    );
  }

  Future<dynamic> _invoke(String method, Map<String, dynamic> args) async {
    if (methodInvoker != null) {
      return methodInvoker!(method, args);
    }
    return _channel.invokeMethod(method, args);
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _deepLinkController ??= StreamController<Uri>.broadcast();
    _hydrationUpdateController ??= StreamController<void>.broadcast();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uriStr = call.arguments as String?;
        if (uriStr != null) {
          final uri = Uri.tryParse(uriStr);
          if (uri != null) {
            _deepLinkController?.add(uri);
          }
        }
      } else if (call.method == 'onHydrationUpdatedFromWidget') {
        _hydrationUpdateController?.add(null);
      }
    });

    _checkInitialUri();
    unawaited(syncQuickCapture());
  }

  Future<void> _checkInitialUri() async {
    try {
      final initialUriStr = await _channel.invokeMethod<String>('getInitialUri');
      if (initialUriStr != null && initialUriStr.isNotEmpty) {
        final uri = Uri.tryParse(initialUriStr);
        if (uri != null) {
          // Slight delay to ensure Flutter UI is ready to receive
          Future.delayed(const Duration(milliseconds: 350), () {
            _deepLinkController?.add(uri);
          });
        }
      }
    } catch (_) {
      // Ignored when platform channel is unavailable (e.g. tests or desktop)
    }
  }

  /// Syncs Next Alarm state and Roo mascot pose to native AppWidget.
  Future<void> syncNextAlarm(
    Alarm? alarm, {
    bool? showMascots,
    DateTime? now,
  }) async {
    final show = showMascots ?? _showMascotsEnabled;
    final ref = now ?? DateTime.now();
    final avatar = resolveAlarmMascot(alarm, now: ref);

    try {
      if (alarm == null || !alarm.isEnabled) {
        await _invoke('updateNextAlarm', {
          'hasAlarm': false,
          'time': '--:--',
          'ampm': '',
          'countdown': 'Off',
          'label': 'No upcoming alarms scheduled',
          'mascotPose': avatar.drawableKey,
          'showMascots': show,
        });
        return;
      }

      final nextTime = alarm.nextOccurrence(ref);
      final diff = nextTime.difference(ref);

      String countdown;
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        countdown = 'in ${diff.inHours}h ${mins}m';
      } else if (diff.inMinutes > 0) {
        countdown = 'in ${diff.inMinutes}m';
      } else {
        countdown = 'Now';
      }

      final formattedHour = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12;
      final timeStr =
          '${formattedHour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';
      final ampmStr = alarm.hour >= 12 ? 'PM' : 'AM';

      await _invoke('updateNextAlarm', {
        'hasAlarm': true,
        'time': timeStr,
        'ampm': ampmStr,
        'countdown': countdown,
        'label': '${alarm.title} • ${alarm.category.name}',
        'mascotPose': avatar.drawableKey,
        'showMascots': show,
      });
    } catch (_) {
      // Ignored when native channel is unavailable
    }
  }

  /// Syncs Habits & Routines status and Roo mascot pose to native AppWidget.
  Future<void> syncHabits(
    List<RoutineItem> routines, {
    bool? showMascots,
  }) async {
    final show = showMascots ?? _showMascotsEnabled;
    final primaryRoutine = routines.isNotEmpty ? routines.first : null;
    final avatar = resolveHabitsMascot(primaryRoutine);

    try {
      if (primaryRoutine == null) {
        await _invoke('updateHabits', {
          'title': 'Daily Habits & Routines',
          'streak': '0d',
          'progress': '0/0',
          'steps': <Map<String, dynamic>>[],
          'mascotPose': avatar.drawableKey,
          'showMascots': show,
        });
        return;
      }

      final totalSteps = primaryRoutine.steps.length;
      final completedSteps = primaryRoutine.completedStepIndices.length;
      final streak = '🔥 ${primaryRoutine.streakCount}d';
      final progress = '$completedSteps/$totalSteps';

      final stepList = <Map<String, dynamic>>[];
      for (int i = 0; i < primaryRoutine.steps.length && i < 4; i++) {
        stepList.add({
          'text': primaryRoutine.steps[i],
          'isDone': primaryRoutine.completedStepIndices.contains(i),
        });
      }

      await _invoke('updateHabits', {
        'title': primaryRoutine.title,
        'streak': streak,
        'progress': progress,
        'steps': stepList,
        'mascotPose': avatar.drawableKey,
        'showMascots': show,
      });
    } catch (_) {
      // Ignored when native channel is unavailable
    }
  }

  /// Syncs Quick Capture flock mascot companion visibility to native AppWidget.
  Future<void> syncQuickCapture({bool? showMascots}) async {
    final show = showMascots ?? _showMascotsEnabled;
    try {
      await _invoke('updateQuickCapture', {
        'showMascots': show,
        'mascots': {
          for (final item in quickCaptureMascots)
            item.actionSlot: item.drawableKey,
        },
      });
    } catch (_) {
      // Ignored when native channel is unavailable
    }
  }

  /// Syncs Seren Hydration progress and mascot mood to Android home/lock widget.
  Future<void> syncHydration(
    HydrationData data, {
    bool? showMascots,
  }) async {
    final show = showMascots ?? _showMascotsEnabled;
    final avatar = resolveHydrationMascot(data);

    try {
      await _invoke('updateHydration', {
        'glassesConsumed': data.glassesConsumed,
        'dailyGoalGlasses': data.dailyGoalGlasses,
        'currentMilliliters': data.currentMilliliters,
        'targetMilliliters': data.targetMilliliters,
        'isGoalMet': data.isGoalMet,
        'lastLoggedDate': data.lastLoggedDate,
        'mascotPose': avatar.drawableKey,
        'showMascots': show,
      });
    } catch (_) {
      // Ignored when native channel is unavailable
    }
  }
}
