import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/hobby_item.dart';
import '../data/models/hobby_practice_session.dart';
import '../data/models/hobby_milestone.dart';
import '../data/services/storage_service.dart';

class HobbyProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<HobbyItem> _hobbies = [];
  List<HobbyPracticeSession> _sessions = [];

  HobbyProvider(this._storageService) {
    _loadFromStorage();
  }

  List<HobbyItem> get hobbies => List.unmodifiable(_hobbies);
  List<HobbyItem> get activeHobbies =>
      _hobbies.where((h) => !h.isArchived).toList();
  List<HobbyPracticeSession> get sessions => List.unmodifiable(_sessions);

  double get totalCumulativeHours =>
      _hobbies.fold(0.0, (sum, h) => sum + h.totalHoursPracticed);

  int get totalSessionsCount => _sessions.length;

  int get totalBadgesUnlocked {
    int count = 0;
    for (final h in _hobbies) {
      count += h.unlockedMilestones.length;
    }
    return count;
  }

  void _loadFromStorage() {
    _hobbies = _storageService.loadHobbies();
    _sessions = _storageService.loadHobbySessions();

    if (_hobbies.isEmpty) {
      final now = DateTime.now();
      final guitarId = 'hobby_guitar_${const Uuid().v4().substring(0, 8)}';
      final artId = 'hobby_art_${const Uuid().v4().substring(0, 8)}';

      _hobbies = [
        HobbyItem(
          id: guitarId,
          name: 'Acoustic Guitar',
          category: 'Music',
          iconEmoji: '🎸',
          colorHex: '#10B981',
          targetHours: 50,
          totalMinutesPracticed: 1560, // 26.0 hours (Quarter Century achieved, Half Century in progress!)
          notes: 'Focusing on fingerpicking patterns, chord transitions, and blues scales.',
          createdAt: now.subtract(const Duration(days: 30)),
          updatedAt: now,
        ),
        HobbyItem(
          id: artId,
          name: 'Digital Illustration',
          category: 'Art',
          iconEmoji: '🎨',
          colorHex: '#3B82F6',
          targetHours: 100,
          totalMinutesPracticed: 660, // 11.0 hours (Dedicated Start achieved)
          notes: 'Procreate color palettes, line art shading, and anatomy sketches.',
          createdAt: now.subtract(const Duration(days: 20)),
          updatedAt: now,
        ),
      ];

      // Sample starter practice sessions for the guitar
      _sessions = [
        HobbyPracticeSession(
          id: const Uuid().v4(),
          hobbyId: guitarId,
          hobbyName: 'Acoustic Guitar',
          durationMinutes: 60,
          sessionDate: now.subtract(const Duration(days: 1)),
          focusTag: 'Technique',
          notes: 'Scales in G Major and clean barre chord transitions.',
          rating: 5,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        HobbyPracticeSession(
          id: const Uuid().v4(),
          hobbyId: guitarId,
          hobbyName: 'Acoustic Guitar',
          durationMinutes: 45,
          sessionDate: now.subtract(const Duration(days: 3)),
          focusTag: 'Repertoire',
          notes: 'Practiced intro fingerstyle rhythm.',
          rating: 4,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        HobbyPracticeSession(
          id: const Uuid().v4(),
          hobbyId: artId,
          hobbyName: 'Digital Illustration',
          durationMinutes: 90,
          sessionDate: now.subtract(const Duration(days: 2)),
          focusTag: 'Creative Play',
          notes: 'Warm lighting landscape study in Procreate.',
          rating: 5,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveHobbies(_hobbies);
    await _storageService.saveHobbySessions(_sessions);
    notifyListeners();
  }

  // --- CRUD Operations ---

  Future<void> addHobby(HobbyItem hobby) async {
    _hobbies.add(hobby);
    await _save();
  }

  Future<void> updateHobby(HobbyItem hobby) async {
    final index = _hobbies.indexWhere((h) => h.id == hobby.id);
    if (index != -1) {
      _hobbies[index] = hobby.copyWith(updatedAt: DateTime.now());
      await _save();
    }
  }

  Future<void> deleteHobby(String id) async {
    _hobbies.removeWhere((h) => h.id == id);
    _sessions.removeWhere((s) => s.hobbyId == id);
    await _save();
  }

  Future<void> toggleArchive(String id) async {
    final index = _hobbies.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _hobbies[index];
      _hobbies[index] = h.copyWith(isArchived: !h.isArchived);
      await _save();
    }
  }

  // --- Practice Session Logging ---

  /// Logs a practice session and returns any newly unlocked milestone badges
  Future<List<HobbyMilestone>> logPracticeSession({
    required String hobbyId,
    required int durationMinutes,
    DateTime? sessionDate,
    String? focusTag,
    String? notes,
    int rating = 5,
  }) async {
    final index = _hobbies.indexWhere((h) => h.id == hobbyId);
    if (index == -1 || durationMinutes <= 0) return [];

    final hobby = _hobbies[index];
    final oldHours = hobby.totalHoursPracticed;
    final oldMilestoneIds = hobby.unlockedMilestones.map((m) => m.id).toSet();

    final now = DateTime.now();
    final newSession = HobbyPracticeSession(
      id: const Uuid().v4(),
      hobbyId: hobbyId,
      hobbyName: hobby.name,
      durationMinutes: durationMinutes,
      sessionDate: sessionDate ?? now,
      focusTag: focusTag,
      notes: notes,
      rating: rating,
      createdAt: now,
    );

    _sessions.insert(0, newSession);

    final newMinutes = hobby.totalMinutesPracticed + durationMinutes;
    final updatedHobby = hobby.copyWith(
      totalMinutesPracticed: newMinutes,
      updatedAt: now,
    );

    _hobbies[index] = updatedHobby;

    // Detect newly unlocked milestones
    final newHours = updatedHobby.totalHoursPracticed;
    final newlyUnlocked = HobbyMilestone.standardMilestones
        .where((m) => m.isUnlocked(newHours) && !oldMilestoneIds.contains(m.id))
        .toList();

    await _save();
    return newlyUnlocked;
  }

  Future<void> deleteSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _sessions[sessionIndex];
    final hobbyIndex = _hobbies.indexWhere((h) => h.id == session.hobbyId);

    if (hobbyIndex != -1) {
      final hobby = _hobbies[hobbyIndex];
      final newMinutes =
          (hobby.totalMinutesPracticed - session.durationMinutes).clamp(0, 9999999);
      _hobbies[hobbyIndex] = hobby.copyWith(
        totalMinutesPracticed: newMinutes,
        updatedAt: DateTime.now(),
      );
    }

    _sessions.removeAt(sessionIndex);
    await _save();
  }

  List<HobbyPracticeSession> getSessionsForHobby(String hobbyId) {
    return _sessions.where((s) => s.hobbyId == hobbyId).toList();
  }
}

