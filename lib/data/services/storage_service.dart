import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';
import '../models/reminder.dart';
import '../models/countdown_timer.dart';
import '../models/user_preferences.dart';
import '../models/custom_sound.dart';
import '../models/calendar_event.dart';
import '../models/task_item.dart';
import '../models/routine_item.dart';
import '../models/note_item.dart';
import '../models/collection_item.dart';
import '../models/wishlist_item.dart';
import '../models/journal_entry.dart';
import '../models/memory_item.dart';
import '../models/dashboard_config.dart';

class StorageService {
  // Existing Preserved Keys
  static const String _keyAlarms = 'roodoo_alarms_v1';
  static const String _keyReminders = 'roodoo_reminders_v1';
  static const String _keyTimers = 'roodoo_timers_v1';
  static const String _keyPreferences = 'roodoo_preferences_v1';
  static const String _keyCustomSounds = 'roodoo_custom_sounds_v1';

  // Expansion Keys
  static const String _keyEvents = 'roodoo_events_v1';
  static const String _keyTasks = 'roodoo_tasks_v1';
  static const String _keyRoutines = 'roodoo_routines_v1';
  static const String _keyNotes = 'roodoo_notes_v1';
  static const String _keyCollections = 'roodoo_collections_v1';
  static const String _keyWishlist = 'roodoo_wishlist_v1';
  static const String _keyJournal = 'roodoo_journal_v1';
  static const String _keyMemories = 'roodoo_memories_v1';
  static const String _keyDashboardConfig = 'roodoo_dashboard_config_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- PRESERVED EXISTING METHODS ---

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

  // --- EXPANSION MODULE PERSISTENCE ---

  // Calendar Events
  Future<void> saveEvents(List<CalendarEvent> events) async {
    final list = events.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyEvents, jsonEncode(list));
  }

  List<CalendarEvent> loadEvents() {
    final raw = _prefs.getString(_keyEvents);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Tasks
  Future<void> saveTasks(List<TaskItem> tasks) async {
    final list = tasks.map((t) => t.toJson()).toList();
    await _prefs.setString(_keyTasks, jsonEncode(list));
  }

  List<TaskItem> loadTasks() {
    final raw = _prefs.getString(_keyTasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Routines & Habits
  Future<void> saveRoutines(List<RoutineItem> routines) async {
    final list = routines.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyRoutines, jsonEncode(list));
  }

  List<RoutineItem> loadRoutines() {
    final raw = _prefs.getString(_keyRoutines);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => RoutineItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Notes
  Future<void> saveNotes(List<NoteItem> notes) async {
    final list = notes.map((n) => n.toJson()).toList();
    await _prefs.setString(_keyNotes, jsonEncode(list));
  }

  List<NoteItem> loadNotes() {
    final raw = _prefs.getString(_keyNotes);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => NoteItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Collections & Lists
  Future<void> saveCollections(List<CollectionItem> collections) async {
    final list = collections.map((c) => c.toJson()).toList();
    await _prefs.setString(_keyCollections, jsonEncode(list));
  }

  List<CollectionItem> loadCollections() {
    final raw = _prefs.getString(_keyCollections);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CollectionItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Wishlist
  Future<void> saveWishlist(List<WishlistItem> items) async {
    final list = items.map((w) => w.toJson()).toList();
    await _prefs.setString(_keyWishlist, jsonEncode(list));
  }

  List<WishlistItem> loadWishlist() {
    final raw = _prefs.getString(_keyWishlist);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => WishlistItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Journal
  Future<void> saveJournal(List<JournalEntry> entries) async {
    final list = entries.map((j) => j.toJson()).toList();
    await _prefs.setString(_keyJournal, jsonEncode(list));
  }

  List<JournalEntry> loadJournal() {
    final raw = _prefs.getString(_keyJournal);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Memories
  Future<void> saveMemories(List<MemoryItem> memories) async {
    final list = memories.map((m) => m.toJson()).toList();
    await _prefs.setString(_keyMemories, jsonEncode(list));
  }

  List<MemoryItem> loadMemories() {
    final raw = _prefs.getString(_keyMemories);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => MemoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Dashboard Config
  Future<void> saveDashboardConfig(DashboardConfig config) async {
    await _prefs.setString(_keyDashboardConfig, jsonEncode(config.toJson()));
  }

  DashboardConfig loadDashboardConfig() {
    final raw = _prefs.getString(_keyDashboardConfig);
    if (raw == null || raw.isEmpty) return const DashboardConfig();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DashboardConfig.fromJson(map);
    } catch (e) {
      return const DashboardConfig();
    }
  }

  // Raw Backup Export / Import (Local-First Portability)
  String exportFullBackupJson() {
    final backup = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'alarms': loadAlarms().map((e) => e.toJson()).toList(),
      'reminders': loadReminders().map((e) => e.toJson()).toList(),
      'timers': loadTimers().map((e) => e.toJson()).toList(),
      'preferences': loadPreferences().toJson(),
      'events': loadEvents().map((e) => e.toJson()).toList(),
      'tasks': loadTasks().map((e) => e.toJson()).toList(),
      'routines': loadRoutines().map((e) => e.toJson()).toList(),
      'notes': loadNotes().map((e) => e.toJson()).toList(),
      'collections': loadCollections().map((e) => e.toJson()).toList(),
      'wishlist': loadWishlist().map((e) => e.toJson()).toList(),
      'journal': loadJournal().map((e) => e.toJson()).toList(),
      'memories': loadMemories().map((e) => e.toJson()).toList(),
      'dashboardConfig': loadDashboardConfig().toJson(),
    };
    return jsonEncode(backup);
  }

  Future<bool> restoreFullBackupJson(String rawJson) async {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      if (map['alarms'] != null) {
        final list = (map['alarms'] as List).map((i) => Alarm.fromJson(i)).toList();
        await saveAlarms(list);
      }
      if (map['reminders'] != null) {
        final list = (map['reminders'] as List).map((i) => Reminder.fromJson(i)).toList();
        await saveReminders(list);
      }
      if (map['events'] != null) {
        final list = (map['events'] as List).map((i) => CalendarEvent.fromJson(i)).toList();
        await saveEvents(list);
      }
      if (map['tasks'] != null) {
        final list = (map['tasks'] as List).map((i) => TaskItem.fromJson(i)).toList();
        await saveTasks(list);
      }
      if (map['notes'] != null) {
        final list = (map['notes'] as List).map((i) => NoteItem.fromJson(i)).toList();
        await saveNotes(list);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
