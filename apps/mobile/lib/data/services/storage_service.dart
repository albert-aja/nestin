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
import '../models/focus_session_log.dart';
import '../models/wearable_config.dart';
import '../models/wearable_sync_record.dart';
import '../models/hydration_data.dart';
import '../models/bedtime_wind_down_config.dart';
import '../models/oem_hardening_data.dart';
import '../models/medication_item.dart';
import '../models/medication_log.dart';
import '../models/medication_snooze.dart';
import '../models/hobby_item.dart';
import '../models/hobby_practice_session.dart';
import '../models/sleep_log.dart';
import '../models/daily_health_activity.dart';
import '../models/vital_log.dart';
import '../models/reading_item.dart';
import '../models/reading_goal_data.dart';
import '../models/saved_place.dart';
import '../models/location_reminder.dart';
import '../models/before_you_go.dart';
import '../models/money_account.dart';
import '../models/money_category.dart';
import '../models/money_transaction.dart';
import '../models/money_budget.dart';
import '../models/recurring_transaction.dart';
import '../models/money_settings.dart';
import '../models/caffeine_data.dart';
import '../models/device_capability.dart';
import '../models/digital_wellbeing.dart';
import '../models/phone_mode.dart';
import '../models/automation_rule.dart';
import '../models/entity_link.dart';

class StorageService {
  static const String _legacyKeyPrefix = 'roodoo_';
  static const String _nestinKeyPrefix = 'nestin_';

  // Core Alarm, Reminder, Timer & Preferences Keys
  static const String _keyAlarms = 'nestin_alarms_v1';
  static const String _keyReminders = 'nestin_reminders_v1';
  static const String _keyTimers = 'nestin_timers_v1';
  static const String _keyPreferences = 'nestin_preferences_v1';
  static const String _keyCustomSounds = 'nestin_custom_sounds_v1';

  // Expansion Keys
  static const String _keyEvents = 'nestin_events_v1';
  static const String _keyTasks = 'nestin_tasks_v1';
  static const String _keyRoutines = 'nestin_routines_v1';
  static const String _keyNotes = 'nestin_notes_v1';
  static const String _keyCollections = 'nestin_collections_v1';
  static const String _keyWishlist = 'nestin_wishlist_v1';
  static const String _keyJournal = 'nestin_journal_v1';
  static const String _keyMemories = 'nestin_memories_v1';
  static const String _keyDashboardConfig = 'nestin_dashboard_config_v1';
  static const String _keyFocusLogs = 'nestin_focus_logs_v1';
  static const String _keyWearableConfig = 'nestin_wearable_config_v1';
  static const String _keyWearableLatestSync = 'nestin_wearable_sync_v1';
  static const String _keyHydrationData = 'nestin_hydration_data_v1';
  static const String _keyCaffeineEntries = 'nestin_caffeine_entries_v1';
  static const String _keyCaffeineConfig = 'nestin_caffeine_config_v1';
  static const String _keyBedtimeWindDownConfig = 'nestin_bedtime_wind_down_v1';
  static const String _keyOemHardeningConfig = 'nestin_oem_hardening_v1';
  static const String _keyMedications = 'nestin_medications_v1';
  static const String _keyMedicationLogs = 'nestin_medication_logs_v1';
  static const String _keyMedicationSnoozes = 'nestin_medication_snoozes_v1';
  static const String _keyHobbies = 'nestin_hobbies_v1';
  static const String _keyHobbySessions = 'nestin_hobby_sessions_v1';
  static const String _keySleepLogs = 'nestin_sleep_logs_v1';
  static const String _keyDailyHealthActivities = 'nestin_daily_health_v1';
  static const String _keyVitalLogs = 'nestin_vital_logs_v1';
  static const String _keyHealthGoals = 'nestin_health_goals_v1';
  static const String _keyReadingItems = 'nestin_reading_items_v1';
  static const String _keyReadingGoalData = 'nestin_reading_goal_v1';
  static const String _keySavedPlaces = 'nestin_saved_places_v1';
  static const String _keyLocationReminders = 'nestin_location_reminders_v1';
  static const String _keyGeofenceLogs = 'nestin_geofence_logs_v1';

  // Scout BeforeYouGo Departure Checklist & Heads-Up Keys
  static const String _keyDeparturePresets = 'nestin_departure_presets_v1';
  static const String _keyDepartureEvents = 'nestin_departure_events_v1';
  static const String _keyDepartureSnoozes = 'nestin_departure_snoozes_v1';
  static const String _keyDepartureActivePreset =
      'nestin_departure_active_preset_v1';

  // Twill Money Management Keys & Schema Migration Version
  static const String _keyMoneySchemaVersion = 'nestin_money_schema_v';
  static const String _keyMoneyAccounts = 'nestin_money_accounts_v1';
  static const String _keyMoneyCategories = 'nestin_money_categories_v1';
  static const String _keyMoneyTransactions = 'nestin_money_transactions_v1';
  static const String _keyMoneyBudgets = 'nestin_money_budgets_v1';
  static const String _keyMoneyRecurring = 'nestin_money_recurring_v1';
  static const String _keyMoneySettings = 'nestin_money_settings_v1';
  static const String _keyTrackedAppRules = 'nestin_tracked_app_rules_v1';
  static const String _keyAppInterventionLogs =
      'nestin_app_intervention_logs_v1';
  static const String _keyPhoneModeProfiles = 'nestin_phone_mode_profiles_v1';
  static const String _keyActivePhoneModeId = 'nestin_active_phone_mode_id_v1';
  static const String _keyStateRestorationSnapshot =
      'nestin_state_restoration_snapshot_v1';
  static const String _keyPermissionHistory = 'nestin_permission_history_v1';
  static const String _keyAutomationRules = 'nestin_automation_rules_v1';
  static const String _keyAutomationLogs = 'nestin_automation_logs_v1';
  static const String _keyEntityLinks = 'nestin_entity_links_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Exposes the initialized SharedPreferences handle for companion metadata
  /// stores (such as guest identity and optional auth session metadata).
  SharedPreferences get prefs => _prefs;

  /// Read-only summary of local record counts across Nestin modules.
  /// Contains counts only (zero personal content) and never mutates storage.
  Map<String, int> collectLocalRecordCounts() {
    return {
      'alarms': loadAlarms().length,
      'reminders': loadReminders().length,
      'timers': loadTimers().length,
      'events': loadEvents().length,
      'tasks': loadTasks().length,
      'routines': loadRoutines().length,
      'notes': loadNotes().length,
      'collections': loadCollections().length,
      'wishlist': loadWishlist().length,
      'journalEntries': loadJournal().length,
      'memories': loadMemories().length,
      'medications': loadMedications().length,
      'hobbies': loadHobbies().length,
      'readingItems': loadReadingItems().length,
      'moneyTransactions': loadMoneyTransactions().length,
    };
  }

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service.migrateLegacyStorageKeysIfNeeded();
    return service;
  }

  /// One-time migration moving legacy `roodoo_*` SharedPreferences keys into
  /// `nestin_*` keys without losing existing user data.
  Future<void> migrateLegacyStorageKeysIfNeeded() async {
    final legacyKeys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_legacyKeyPrefix))
        .toList(growable: false);
    for (final legacyKey in legacyKeys) {
      final newKey =
          '$_nestinKeyPrefix${legacyKey.substring(_legacyKeyPrefix.length)}';
      if (!_prefs.containsKey(newKey)) {
        final value = _prefs.get(legacyKey);
        if (value is String) {
          await _prefs.setString(newKey, value);
        } else if (value is bool) {
          await _prefs.setBool(newKey, value);
        } else if (value is int) {
          await _prefs.setInt(newKey, value);
        } else if (value is double) {
          await _prefs.setDouble(newKey, value);
        } else if (value is List<String>) {
          await _prefs.setStringList(newKey, value);
        }
      }
      await _prefs.remove(legacyKey);
    }
  }

  /// Syncs cached SharedPreferences with background isolate writes.
  Future<void> reloadPrefs() async {
    try {
      await _prefs.reload();
    } catch (_) {}
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

  // Focus History Logs (Pomodoro)
  Future<void> saveFocusLogs(List<FocusSessionLog> logs) async {
    final list = logs.map((l) => l.toJson()).toList();
    await _prefs.setString(_keyFocusLogs, jsonEncode(list));
  }

  List<FocusSessionLog> loadFocusLogs() {
    final raw = _prefs.getString(_keyFocusLogs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => FocusSessionLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Wearable Health Integration
  Future<void> saveWearableConfig(WearableConfig config) async {
    await _prefs.setString(_keyWearableConfig, jsonEncode(config.toJson()));
  }

  WearableConfig loadWearableConfig() {
    final raw = _prefs.getString(_keyWearableConfig);
    if (raw == null || raw.isEmpty) return const WearableConfig();
    try {
      return WearableConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const WearableConfig();
    }
  }

  Future<void> saveLatestWearableSync(WearableSyncRecord record) async {
    await _prefs.setString(_keyWearableLatestSync, jsonEncode(record.toJson()));
  }

  WearableSyncRecord? loadLatestWearableSync() {
    final raw = _prefs.getString(_keyWearableLatestSync);
    if (raw == null || raw.isEmpty) return null;
    try {
      return WearableSyncRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHydrationData(HydrationData data) async {
    await _prefs.setString(_keyHydrationData, jsonEncode(data.toJson()));
  }

  HydrationData loadHydrationData() {
    final raw = _prefs.getString(_keyHydrationData);
    if (raw == null || raw.isEmpty) return HydrationData.initial();
    try {
      return HydrationData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return HydrationData.initial();
    }
  }

  Future<void> saveBedtimeWindDownConfig(BedtimeWindDownConfig config) async {
    await _prefs.setString(
        _keyBedtimeWindDownConfig, jsonEncode(config.toJson()));
  }

  BedtimeWindDownConfig loadBedtimeWindDownConfig() {
    final raw = _prefs.getString(_keyBedtimeWindDownConfig);
    if (raw == null || raw.isEmpty) return BedtimeWindDownConfig.initial();
    try {
      return BedtimeWindDownConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return BedtimeWindDownConfig.initial();
    }
  }

  Future<void> saveCaffeineEntries(List<CaffeineEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCaffeineEntries, encoded);
  }

  List<CaffeineEntry> loadCaffeineEntries() {
    final raw = _prefs.getString(_keyCaffeineEntries);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CaffeineEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCaffeineConfig(CaffeineConfig config) async {
    await _prefs.setString(_keyCaffeineConfig, jsonEncode(config.toJson()));
  }

  CaffeineConfig loadCaffeineConfig() {
    final raw = _prefs.getString(_keyCaffeineConfig);
    if (raw == null || raw.isEmpty) return CaffeineConfig.initial();
    try {
      return CaffeineConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return CaffeineConfig.initial();
    }
  }

  // OEM Hardening & Background Reliability
  Future<void> saveOemHardeningConfig(OemHardeningConfig config) async {
    await _prefs.setString(
        _keyOemHardeningConfig, jsonEncode(config.toJson()));
  }

  OemHardeningConfig loadOemHardeningConfig() {
    final raw = _prefs.getString(_keyOemHardeningConfig);
    if (raw == null || raw.isEmpty) return const OemHardeningConfig();
    try {
      return OemHardeningConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const OemHardeningConfig();
    }
  }

  Future<void> saveMedications(List<MedicationItem> list) async {
    await _prefs.setString(
        _keyMedications, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  List<MedicationItem> loadMedications() {
    final raw = _prefs.getString(_keyMedications);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((i) => MedicationItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMedicationLogs(List<MedicationLog> list) async {
    await _prefs.setString(
        _keyMedicationLogs, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  List<MedicationLog> loadMedicationLogs() {
    final raw = _prefs.getString(_keyMedicationLogs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((i) => MedicationLog.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMedicationSnoozes(List<MedicationSnooze> list) =>
      _saveJsonList(_keyMedicationSnoozes, list, (e) => e.toJson());

  List<MedicationSnooze> loadMedicationSnoozes() =>
      _loadJsonList(_keyMedicationSnoozes, MedicationSnooze.fromJson);

  Future<void> saveHobbies(List<HobbyItem> list) async {
    await _prefs.setString(
        _keyHobbies, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  List<HobbyItem> loadHobbies() {
    final raw = _prefs.getString(_keyHobbies);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((i) => HobbyItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHobbySessions(List<HobbyPracticeSession> list) async {
    await _prefs.setString(
        _keyHobbySessions, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  List<HobbyPracticeSession> loadHobbySessions() {
    final raw = _prefs.getString(_keyHobbySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((i) => HobbyPracticeSession.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Seren Personal Health & Activity Tracking ---

  Future<void> _saveJsonList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await _prefs.setString(key, jsonEncode(items.map(toJson).toList()));
  }

  List<T> _loadJsonList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((i) => fromJson(i as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSleepLogs(List<SleepLog> logs) =>
      _saveJsonList(_keySleepLogs, logs, (e) => e.toJson());

  List<SleepLog> loadSleepLogs() =>
      _loadJsonList(_keySleepLogs, SleepLog.fromJson);

  Future<void> saveVitalLogs(List<VitalLog> logs) =>
      _saveJsonList(_keyVitalLogs, logs, (e) => e.toJson());

  List<VitalLog> loadVitalLogs() =>
      _loadJsonList(_keyVitalLogs, VitalLog.fromJson);

  Future<void> saveDailyHealthActivities(
      Map<String, DailyHealthActivity> activities) async {
    final encoded =
        activities.map((key, value) => MapEntry(key, value.toJson()));
    await _prefs.setString(_keyDailyHealthActivities, jsonEncode(encoded));
  }

  Map<String, DailyHealthActivity> loadDailyHealthActivities() {
    final raw = _prefs.getString(_keyDailyHealthActivities);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(
          key, DailyHealthActivity.fromJson(value as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveHealthGoals(HealthGoalsConfig goals) async {
    await _prefs.setString(_keyHealthGoals, jsonEncode(goals.toJson()));
  }

  HealthGoalsConfig loadHealthGoals() {
    final raw = _prefs.getString(_keyHealthGoals);
    if (raw == null || raw.isEmpty) return const HealthGoalsConfig();
    try {
      return HealthGoalsConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const HealthGoalsConfig();
    }
  }

  // --- Pippin Reading Progress Tracker ---

  Future<void> saveReadingItems(List<ReadingItem> items) =>
      _saveJsonList(_keyReadingItems, items, (e) => e.toJson());

  List<ReadingItem> loadReadingItems() =>
      _loadJsonList(_keyReadingItems, ReadingItem.fromJson);

  Future<void> saveReadingGoalData(ReadingGoalData data) async {
    await _prefs.setString(_keyReadingGoalData, jsonEncode(data.toJson()));
  }

  ReadingGoalData loadReadingGoalData() {
    final raw = _prefs.getString(_keyReadingGoalData);
    if (raw == null || raw.isEmpty) return ReadingGoalData.initial();
    try {
      return ReadingGoalData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ReadingGoalData.initial();
    }
  }

  // --- Scout Location-Based Reminders & Geofences ---

  Future<void> saveSavedPlaces(List<SavedPlace> places) =>
      _saveJsonList(_keySavedPlaces, places, (e) => e.toJson());

  List<SavedPlace> loadSavedPlaces() =>
      _loadJsonList(_keySavedPlaces, SavedPlace.fromJson);

  Future<void> saveLocationReminders(List<LocationReminder> reminders) =>
      _saveJsonList(_keyLocationReminders, reminders, (e) => e.toJson());

  List<LocationReminder> loadLocationReminders() =>
      _loadJsonList(_keyLocationReminders, LocationReminder.fromJson);

  Future<void> saveGeofenceLogs(List<GeofenceTriggerLog> logs) =>
      _saveJsonList(_keyGeofenceLogs, logs, (e) => e.toJson());

  List<GeofenceTriggerLog> loadGeofenceLogs() =>
      _loadJsonList(_keyGeofenceLogs, GeofenceTriggerLog.fromJson);

  // --- Scout BeforeYouGo Checklists, Presets & Scheduled Departures ---

  Future<void> saveDeparturePresets(List<DeparturePreset> presets) =>
      _saveJsonList(_keyDeparturePresets, presets, (e) => e.toJson());

  List<DeparturePreset> loadDeparturePresets() =>
      _loadJsonList(_keyDeparturePresets, DeparturePreset.fromJson);

  Future<void> saveDepartureEvents(List<DepartureEvent> events) =>
      _saveJsonList(_keyDepartureEvents, events, (e) => e.toJson());

  List<DepartureEvent> loadDepartureEvents() =>
      _loadJsonList(_keyDepartureEvents, DepartureEvent.fromJson);

  Future<void> saveDepartureSnoozes(List<DepartureSnooze> snoozes) =>
      _saveJsonList(_keyDepartureSnoozes, snoozes, (e) => e.toJson());

  List<DepartureSnooze> loadDepartureSnoozes() =>
      _loadJsonList(_keyDepartureSnoozes, DepartureSnooze.fromJson);

  Future<void> saveActiveDeparturePresetId(String presetId) async {
    await _prefs.setString(_keyDepartureActivePreset, presetId);
  }

  String? loadActiveDeparturePresetId() =>
      _prefs.getString(_keyDepartureActivePreset);

  // --- Twill Money Management & Schema Migration ---

  int get moneySchemaVersion => _prefs.getInt(_keyMoneySchemaVersion) ?? 0;

  Future<void> migrateMoneySchemaIfNeeded() async {
    final currentVersion = moneySchemaVersion;
    if (currentVersion >= MoneySettings.currentSchemaVersion) {
      return;
    }

    // Migration v0 -> v1: normalize records, enforce default userId, verify balance invariant.
    final accounts = loadMoneyAccounts();
    final categories = loadMoneyCategories();
    final transactions = loadMoneyTransactions();
    final budgets = loadMoneyBudgets();
    final recurring = loadMoneyRecurring();

    if (accounts.isNotEmpty) {
      final reconciledAccounts = <MoneyAccount>[];
      for (final acct in accounts) {
        var balanceMinor = acct.initialBalanceMinor;
        for (final tx in transactions) {
          if (tx.userId != acct.userId || tx.isArchived) continue;
          if (tx.type == MoneyTransactionType.income && tx.accountId == acct.id) {
            balanceMinor += tx.amountMinor;
          } else if (tx.type == MoneyTransactionType.expense &&
              tx.accountId == acct.id) {
            balanceMinor -= tx.amountMinor;
          } else if (tx.type == MoneyTransactionType.transfer) {
            if (tx.accountId == acct.id) balanceMinor -= tx.amountMinor;
            if (tx.toAccountId == acct.id) balanceMinor += tx.amountMinor;
          }
        }
        reconciledAccounts.add(acct.copyWith(currentBalanceMinor: balanceMinor));
      }
      await saveMoneyAccounts(reconciledAccounts);
    }

    if (categories.isNotEmpty) await saveMoneyCategories(categories);
    if (transactions.isNotEmpty) await saveMoneyTransactions(transactions);
    if (budgets.isNotEmpty) await saveMoneyBudgets(budgets);
    if (recurring.isNotEmpty) await saveMoneyRecurring(recurring);

    await _prefs.setInt(
      _keyMoneySchemaVersion,
      MoneySettings.currentSchemaVersion,
    );
  }

  Future<void> saveMoneyAccounts(List<MoneyAccount> accounts) =>
      _saveJsonList(_keyMoneyAccounts, accounts, (e) => e.toJson());

  List<MoneyAccount> loadMoneyAccounts() =>
      _loadJsonList(_keyMoneyAccounts, MoneyAccount.fromJson);

  Future<void> saveMoneyCategories(List<MoneyCategory> categories) =>
      _saveJsonList(_keyMoneyCategories, categories, (e) => e.toJson());

  List<MoneyCategory> loadMoneyCategories() =>
      _loadJsonList(_keyMoneyCategories, MoneyCategory.fromJson);

  Future<void> saveMoneyTransactions(List<MoneyTransaction> transactions) =>
      _saveJsonList(_keyMoneyTransactions, transactions, (e) => e.toJson());

  List<MoneyTransaction> loadMoneyTransactions() =>
      _loadJsonList(_keyMoneyTransactions, MoneyTransaction.fromJson);

  Future<void> saveMoneyBudgets(List<MoneyBudget> budgets) =>
      _saveJsonList(_keyMoneyBudgets, budgets, (e) => e.toJson());

  List<MoneyBudget> loadMoneyBudgets() =>
      _loadJsonList(_keyMoneyBudgets, MoneyBudget.fromJson);

  Future<void> saveMoneyRecurring(List<RecurringTransaction> items) =>
      _saveJsonList(_keyMoneyRecurring, items, (e) => e.toJson());

  List<RecurringTransaction> loadMoneyRecurring() =>
      _loadJsonList(_keyMoneyRecurring, RecurringTransaction.fromJson);

  Future<void> saveMoneySettings(MoneySettings settings) async {
    await _prefs.setString(_keyMoneySettings, jsonEncode(settings.toJson()));
  }

  MoneySettings loadMoneySettings() {
    final raw = _prefs.getString(_keyMoneySettings);
    if (raw == null || raw.isEmpty) return const MoneySettings();
    try {
      return MoneySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MoneySettings();
    }
  }

  // Scout Digital Wellbeing, Phone Modes & Permission Center
  bool hasSavedTrackedAppRules() => _prefs.containsKey(_keyTrackedAppRules);

  Future<void> saveTrackedAppRules(List<TrackedAppRule> items) =>
      _saveJsonList(_keyTrackedAppRules, items, (e) => e.toJson());

  List<TrackedAppRule> loadTrackedAppRules() =>
      _loadJsonList(_keyTrackedAppRules, TrackedAppRule.fromJson);

  Future<void> saveAppInterventionLogs(List<AppInterventionLog> items) =>
      _saveJsonList(_keyAppInterventionLogs, items, (e) => e.toJson());

  List<AppInterventionLog> loadAppInterventionLogs() =>
      _loadJsonList(_keyAppInterventionLogs, AppInterventionLog.fromJson);

  bool hasSavedPhoneModeProfiles() =>
      _prefs.containsKey(_keyPhoneModeProfiles);

  Future<void> savePhoneModeProfiles(List<PhoneModeProfile> items) =>
      _saveJsonList(_keyPhoneModeProfiles, items, (e) => e.toJson());

  List<PhoneModeProfile> loadPhoneModeProfiles() =>
      _loadJsonList(_keyPhoneModeProfiles, PhoneModeProfile.fromJson);

  Future<void> saveActivePhoneModeId(String? modeId) async {
    if (modeId == null || modeId.isEmpty) {
      await _prefs.remove(_keyActivePhoneModeId);
    } else {
      await _prefs.setString(_keyActivePhoneModeId, modeId);
    }
  }

  String? loadActivePhoneModeId() => _prefs.getString(_keyActivePhoneModeId);

  Future<void> saveStateRestorationSnapshot(
      StateRestorationSnapshot? snapshot) async {
    if (snapshot == null) {
      await _prefs.remove(_keyStateRestorationSnapshot);
    } else {
      await _prefs.setString(
        _keyStateRestorationSnapshot,
        jsonEncode(snapshot.toJson()),
      );
    }
  }

  StateRestorationSnapshot? loadStateRestorationSnapshot() {
    final raw = _prefs.getString(_keyStateRestorationSnapshot);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StateRestorationSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePermissionHistory(List<PermissionEntry> items) =>
      _saveJsonList(_keyPermissionHistory, items, (e) => e.toJson());

  List<PermissionEntry> loadPermissionHistory() =>
      _loadJsonList(_keyPermissionHistory, PermissionEntry.fromJson);

  // Shared Automation Engine
  bool hasSavedAutomationRules() => _prefs.containsKey(_keyAutomationRules);

  Future<void> saveAutomationRules(List<AutomationRule> items) =>
      _saveJsonList(_keyAutomationRules, items, (e) => e.toJson());

  List<AutomationRule> loadAutomationRules() =>
      _loadJsonList(_keyAutomationRules, AutomationRule.fromJson);

  Future<void> saveAutomationLogs(List<AutomationExecutionLog> items) =>
      _saveJsonList(_keyAutomationLogs, items, (e) => e.toJson());

  List<AutomationExecutionLog> loadAutomationLogs() =>
      _loadJsonList(_keyAutomationLogs, AutomationExecutionLog.fromJson);

  // Unified Cross-Module Entity Linking
  Future<void> saveEntityLinks(List<EntityLink> items) =>
      _saveJsonList(_keyEntityLinks, items, (e) => e.toJson());

  List<EntityLink> loadEntityLinks() =>
      _loadJsonList(_keyEntityLinks, EntityLink.fromJson);

  /// Persists accounts and transactions together with snapshot rollback on failure.
  Future<void> commitMoneyLedgerAtomically({
    required List<MoneyAccount> accounts,
    required List<MoneyTransaction> transactions,
    List<RecurringTransaction>? recurring,
  }) async {
    final prevAccountsRaw = _prefs.getString(_keyMoneyAccounts);
    final prevTransactionsRaw = _prefs.getString(_keyMoneyTransactions);
    final prevRecurringRaw = _prefs.getString(_keyMoneyRecurring);

    try {
      await saveMoneyAccounts(accounts);
      await saveMoneyTransactions(transactions);
      if (recurring != null) {
        await saveMoneyRecurring(recurring);
      }
    } catch (e) {
      // Restore prior persisted payloads atomically if any write fails.
      if (prevAccountsRaw != null) {
        await _prefs.setString(_keyMoneyAccounts, prevAccountsRaw);
      } else {
        await _prefs.remove(_keyMoneyAccounts);
      }
      if (prevTransactionsRaw != null) {
        await _prefs.setString(_keyMoneyTransactions, prevTransactionsRaw);
      } else {
        await _prefs.remove(_keyMoneyTransactions);
      }
      if (recurring != null) {
        if (prevRecurringRaw != null) {
          await _prefs.setString(_keyMoneyRecurring, prevRecurringRaw);
        } else {
          await _prefs.remove(_keyMoneyRecurring);
        }
      }
      rethrow;
    }
  }

  // Raw Backup Export / Import (Local-First Portability)
  String exportFullBackupJson() {
    final backup = {
      'version': 3,
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
      'focusLogs': loadFocusLogs().map((e) => e.toJson()).toList(),
      'wearableConfig': loadWearableConfig().toJson(),
      'latestWearableSync': loadLatestWearableSync()?.toJson(),
      'hydrationData': loadHydrationData().toJson(),
      'caffeineEntries': loadCaffeineEntries().map((e) => e.toJson()).toList(),
      'caffeineConfig': loadCaffeineConfig().toJson(),
      'bedtimeWindDownConfig': loadBedtimeWindDownConfig().toJson(),
      'oemHardeningConfig': loadOemHardeningConfig().toJson(),
      'medications': loadMedications().map((e) => e.toJson()).toList(),
      'medicationLogs': loadMedicationLogs().map((e) => e.toJson()).toList(),
      'medicationSnoozes':
          loadMedicationSnoozes().map((e) => e.toJson()).toList(),
      'hobbies': loadHobbies().map((e) => e.toJson()).toList(),
      'hobbySessions': loadHobbySessions().map((e) => e.toJson()).toList(),
      'sleepLogs': loadSleepLogs().map((e) => e.toJson()).toList(),
      'dailyHealthActivities': loadDailyHealthActivities()
          .map((key, value) => MapEntry(key, value.toJson())),
      'vitalLogs': loadVitalLogs().map((e) => e.toJson()).toList(),
      'healthGoals': loadHealthGoals().toJson(),
      'readingItems': loadReadingItems().map((e) => e.toJson()).toList(),
      'readingGoalData': loadReadingGoalData().toJson(),
      'savedPlaces': loadSavedPlaces().map((e) => e.toJson()).toList(),
      'locationReminders': loadLocationReminders().map((e) => e.toJson()).toList(),
      'geofenceLogs': loadGeofenceLogs().map((e) => e.toJson()).toList(),
      'departurePresets': loadDeparturePresets().map((e) => e.toJson()).toList(),
      'departureEvents': loadDepartureEvents().map((e) => e.toJson()).toList(),
      'departureSnoozes': loadDepartureSnoozes().map((e) => e.toJson()).toList(),
      'activeDeparturePresetId': loadActiveDeparturePresetId(),
      'moneySchemaVersion': moneySchemaVersion,
      'moneySettings': loadMoneySettings().toJson(),
      'moneyAccounts': loadMoneyAccounts().map((e) => e.toJson()).toList(),
      'moneyCategories': loadMoneyCategories().map((e) => e.toJson()).toList(),
      'moneyTransactions':
          loadMoneyTransactions().map((e) => e.toJson()).toList(),
      'moneyBudgets': loadMoneyBudgets().map((e) => e.toJson()).toList(),
      'moneyRecurring': loadMoneyRecurring().map((e) => e.toJson()).toList(),
      'trackedAppRules': loadTrackedAppRules().map((e) => e.toJson()).toList(),
      'appInterventionLogs':
          loadAppInterventionLogs().map((e) => e.toJson()).toList(),
      'phoneModeProfiles':
          loadPhoneModeProfiles().map((e) => e.toJson()).toList(),
      'activePhoneModeId': loadActivePhoneModeId(),
      'stateRestorationSnapshot': loadStateRestorationSnapshot()?.toJson(),
      'permissionHistory':
          loadPermissionHistory().map((e) => e.toJson()).toList(),
      'automationRules': loadAutomationRules().map((e) => e.toJson()).toList(),
      'automationLogs': loadAutomationLogs().map((e) => e.toJson()).toList(),
      'entityLinks': loadEntityLinks().map((e) => e.toJson()).toList(),
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
      if (map['timers'] != null) {
        final list = (map['timers'] as List).map((i) => CountdownTimer.fromJson(i)).toList();
        await saveTimers(list);
      }
      if (map['preferences'] != null) {
        await savePreferences(
          UserPreferences.fromJson(map['preferences'] as Map<String, dynamic>),
        );
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
      if (map['collections'] != null) {
        final list = (map['collections'] as List)
            .map((i) => CollectionItem.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveCollections(list);
      }
      if (map['focusLogs'] != null) {
        final list = (map['focusLogs'] as List).map((i) => FocusSessionLog.fromJson(i)).toList();
        await saveFocusLogs(list);
      }
      if (map['wearableConfig'] != null) {
        await saveWearableConfig(
            WearableConfig.fromJson(map['wearableConfig'] as Map<String, dynamic>));
      }
      if (map['latestWearableSync'] != null) {
        await saveLatestWearableSync(
            WearableSyncRecord.fromJson(map['latestWearableSync'] as Map<String, dynamic>));
      }
      if (map['hydrationData'] != null) {
        await saveHydrationData(
            HydrationData.fromJson(map['hydrationData'] as Map<String, dynamic>));
      }
      if (map['caffeineEntries'] != null) {
        final list = (map['caffeineEntries'] as List)
            .map((i) => CaffeineEntry.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveCaffeineEntries(list);
      }
      if (map['caffeineConfig'] != null) {
        await saveCaffeineConfig(
            CaffeineConfig.fromJson(map['caffeineConfig'] as Map<String, dynamic>));
      }
      if (map['bedtimeWindDownConfig'] != null) {
        await saveBedtimeWindDownConfig(
            BedtimeWindDownConfig.fromJson(
                map['bedtimeWindDownConfig'] as Map<String, dynamic>));
      }
      if (map['oemHardeningConfig'] != null) {
        await saveOemHardeningConfig(
            OemHardeningConfig.fromJson(
                map['oemHardeningConfig'] as Map<String, dynamic>));
      }
      if (map['trackedAppRules'] != null) {
        final list = (map['trackedAppRules'] as List)
            .map((i) => TrackedAppRule.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveTrackedAppRules(list);
      }
      if (map['appInterventionLogs'] != null) {
        final list = (map['appInterventionLogs'] as List)
            .map((i) => AppInterventionLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveAppInterventionLogs(list);
      }
      if (map['phoneModeProfiles'] != null) {
        final list = (map['phoneModeProfiles'] as List)
            .map((i) => PhoneModeProfile.fromJson(i as Map<String, dynamic>))
            .toList();
        await savePhoneModeProfiles(list);
      }
      if (map.containsKey('activePhoneModeId')) {
        await saveActivePhoneModeId(map['activePhoneModeId'] as String?);
      }
      if (map['stateRestorationSnapshot'] != null) {
        await saveStateRestorationSnapshot(
          StateRestorationSnapshot.fromJson(
            map['stateRestorationSnapshot'] as Map<String, dynamic>,
          ),
        );
      }
      if (map['permissionHistory'] != null) {
        final list = (map['permissionHistory'] as List)
            .map((i) => PermissionEntry.fromJson(i as Map<String, dynamic>))
            .toList();
        await savePermissionHistory(list);
      }
      if (map['automationRules'] != null) {
        final list = (map['automationRules'] as List)
            .map((i) => AutomationRule.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveAutomationRules(list);
      }
      if (map['automationLogs'] != null) {
        final list = (map['automationLogs'] as List)
            .map((i) =>
                AutomationExecutionLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveAutomationLogs(list);
      }
      if (map['entityLinks'] != null) {
        final list = (map['entityLinks'] as List)
            .map((i) => EntityLink.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveEntityLinks(list);
      }
      if (map['medications'] != null) {
        final list = (map['medications'] as List)
            .map((i) => MedicationItem.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMedications(list);
      }
      if (map['medicationLogs'] != null) {
        final list = (map['medicationLogs'] as List)
            .map((i) => MedicationLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMedicationLogs(list);
      }
      if (map['medicationSnoozes'] != null) {
        final list = (map['medicationSnoozes'] as List)
            .map((i) => MedicationSnooze.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMedicationSnoozes(list);
      }
      if (map['hobbies'] != null) {
        final list = (map['hobbies'] as List)
            .map((i) => HobbyItem.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveHobbies(list);
      }
      if (map['hobbySessions'] != null) {
        final list = (map['hobbySessions'] as List)
            .map((i) => HobbyPracticeSession.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveHobbySessions(list);
      }
      if (map['sleepLogs'] != null) {
        final list = (map['sleepLogs'] as List)
            .map((i) => SleepLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveSleepLogs(list);
      }
      if (map['dailyHealthActivities'] != null) {
        final rawMap = map['dailyHealthActivities'] as Map<String, dynamic>;
        final restoredMap = rawMap.map((k, v) => MapEntry(
            k, DailyHealthActivity.fromJson(v as Map<String, dynamic>)));
        await saveDailyHealthActivities(restoredMap);
      }
      if (map['vitalLogs'] != null) {
        final list = (map['vitalLogs'] as List)
            .map((i) => VitalLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveVitalLogs(list);
      }
      if (map['healthGoals'] != null) {
        await saveHealthGoals(HealthGoalsConfig.fromJson(
            map['healthGoals'] as Map<String, dynamic>));
      }
      if (map['readingItems'] != null) {
        final list = (map['readingItems'] as List)
            .map((i) => ReadingItem.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveReadingItems(list);
      }
      if (map['readingGoalData'] != null) {
        await saveReadingGoalData(ReadingGoalData.fromJson(
            map['readingGoalData'] as Map<String, dynamic>));
      }
      if (map['savedPlaces'] != null) {
        final list = (map['savedPlaces'] as List)
            .map((i) => SavedPlace.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveSavedPlaces(list);
      }
      if (map['locationReminders'] != null) {
        final list = (map['locationReminders'] as List)
            .map((i) => LocationReminder.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveLocationReminders(list);
      }
      if (map['geofenceLogs'] != null) {
        final list = (map['geofenceLogs'] as List)
            .map((i) => GeofenceTriggerLog.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveGeofenceLogs(list);
      }
      if (map['departurePresets'] != null) {
        final list = (map['departurePresets'] as List)
            .map((i) => DeparturePreset.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveDeparturePresets(list);
      }
      if (map['departureEvents'] != null) {
        final list = (map['departureEvents'] as List)
            .map((i) => DepartureEvent.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveDepartureEvents(list);
      }
      if (map['departureSnoozes'] != null) {
        final list = (map['departureSnoozes'] as List)
            .map((i) => DepartureSnooze.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveDepartureSnoozes(list);
      }
      if (map['activeDeparturePresetId'] is String) {
        await saveActiveDeparturePresetId(
            map['activeDeparturePresetId'] as String);
      }
      if (map['moneySettings'] != null) {
        await saveMoneySettings(MoneySettings.fromJson(
            map['moneySettings'] as Map<String, dynamic>));
      }
      if (map['moneyAccounts'] != null) {
        final list = (map['moneyAccounts'] as List)
            .map((i) => MoneyAccount.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMoneyAccounts(list);
      }
      if (map['moneyCategories'] != null) {
        final list = (map['moneyCategories'] as List)
            .map((i) => MoneyCategory.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMoneyCategories(list);
      }
      if (map['moneyTransactions'] != null) {
        final list = (map['moneyTransactions'] as List)
            .map((i) => MoneyTransaction.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMoneyTransactions(list);
      }
      if (map['moneyBudgets'] != null) {
        final list = (map['moneyBudgets'] as List)
            .map((i) => MoneyBudget.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMoneyBudgets(list);
      }
      if (map['moneyRecurring'] != null) {
        final list = (map['moneyRecurring'] as List)
            .map((i) => RecurringTransaction.fromJson(i as Map<String, dynamic>))
            .toList();
        await saveMoneyRecurring(list);
      }
      return true;
    } catch (_) {
      return false;
    }
  }


}
