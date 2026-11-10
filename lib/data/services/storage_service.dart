import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';
import '../models/reminder.dart';
import '../models/countdown_timer.dart';
import '../models/user_preferences.dart';
import '../models/custom_sound.dart';

class StorageService {
  static const String _keyAlarms = 'roodoo_alarms_v1';
  static const String _keyReminders = 'roodoo_reminders_v1';
  static const String _keyTimers = 'roodoo_timers_v1';
  static const String _keyPreferences = 'roodoo_preferences_v1';
  static const String _keyCustomSounds = 'roodoo_custom_sounds_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Alarms
  Future<void> saveAlarms(List<Alarm> alarms) async {
    final list = alarms.map((a) => a.toJson()).toList();
    await _prefs.setString(_keyAlarms, jsonEncode(list));
  }

  List<Alarm> loadAlarms() {
    final raw = _prefs.getString(_keyAlarms);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => Alarm.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Reminders
  Future<void> saveReminders(List<Reminder> reminders) async {
    final list = reminders.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyReminders, jsonEncode(list));
  }

  List<Reminder> loadReminders() {
    final raw = _prefs.getString(_keyReminders);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => Reminder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Timers
  Future<void> saveTimers(List<CountdownTimer> timers) async {
    final list = timers.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyTimers, jsonEncode(list));
  }

  List<CountdownTimer> loadTimers() {
    final raw = _prefs.getString(_keyTimers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CountdownTimer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // User Preferences
  Future<void> savePreferences(UserPreferences prefs) async {
    await _prefs.setString(_keyPreferences, jsonEncode(prefs.toJson()));
  }

  UserPreferences loadPreferences() {
    final raw = _prefs.getString(_keyPreferences);
    if (raw == null || raw.isEmpty) {
      return UserPreferences.defaults();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserPreferences.fromJson(map);
    } catch (e) {
      return UserPreferences.defaults();
    }
  }

  // Custom Imported Sounds
  Future<void> saveCustomSounds(List<CustomSound> sounds) async {
    final list = sounds.map((s) => s.toJson()).toList();
    await _prefs.setString(_keyCustomSounds, jsonEncode(list));
  }

  List<CustomSound> loadCustomSounds() {
    final raw = _prefs.getString(_keyCustomSounds);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CustomSound.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

