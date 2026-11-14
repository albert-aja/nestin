import 'dart:async';
import 'package:flutter/services.dart';
import '../models/alarm.dart';
import '../models/routine_item.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('com.nestin.app/widgets');

  static final WidgetSyncService instance = WidgetSyncService._();
  WidgetSyncService._();

  StreamController<Uri>? _deepLinkController;
  Stream<Uri> get deepLinkStream {
    _deepLinkController ??= StreamController<Uri>.broadcast();
    return _deepLinkController!.stream;
  }

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _deepLinkController ??= StreamController<Uri>.broadcast();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uriStr = call.arguments as String?;
        if (uriStr != null) {
          final uri = Uri.tryParse(uriStr);
          if (uri != null) {
            _deepLinkController?.add(uri);
          }
        }
      }
    });

    _checkInitialUri();
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

  /// Syncs Next Alarm state to native AppWidget
  Future<void> syncNextAlarm(Alarm? alarm) async {
    try {
      if (alarm == null || !alarm.isEnabled) {
        await _channel.invokeMethod('updateNextAlarm', {
          'hasAlarm': false,
          'time': '--:--',
          'ampm': '',
          'countdown': 'Off',
          'label': 'No upcoming alarms scheduled',
        });
        return;
      }

      final now = DateTime.now();
      final nextTime = alarm.nextOccurrence(now);
      final diff = nextTime.difference(now);

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

      await _channel.invokeMethod('updateNextAlarm', {
        'hasAlarm': true,
        'time': timeStr,
        'ampm': ampmStr,
        'countdown': countdown,
        'label': '${alarm.title} • ${alarm.category.name}',
      });
    } catch (_) {
      // Ignored
    }
  }

  /// Syncs Habits & Routines status to native AppWidget
  Future<void> syncHabits(List<RoutineItem> routines) async {
    try {
      if (routines.isEmpty) {
        await _channel.invokeMethod('updateHabits', {
          'title': 'Daily Habits & Routines',
          'streak': '0d',
          'progress': '0/0',
          'steps': <Map<String, dynamic>>[],
        });
        return;
      }

      final primaryRoutine = routines.first;
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

      await _channel.invokeMethod('updateHabits', {
        'title': primaryRoutine.title,
        'streak': streak,
        'progress': progress,
        'steps': stepList,
      });
    } catch (_) {
      // Ignored
    }
  }
}

