import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/reading_goal_data.dart';
import '../data/models/reading_item.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';

class ReadingProvider extends ChangeNotifier {
  static const int eveningReminderNotificationId = 7310;
  static const int previewReminderNotificationId = 7311;
  static const String reminderPayload = 'pippin_reading_goal';

  final StorageService _storageService;
  final NotificationService? notificationService;
  final DateTime Function() _clock;

  List<ReadingItem> _items = [];
  ReadingGoalData _goalData = ReadingGoalData.initial();
  final Map<String, int> _persistedPagesByBook = {};
  int _reminderSyncEpoch = 0;

  ReadingProvider(
    this._storageService, {
    this.notificationService,
    DateTime Function()? clock,
    bool seedDefaults = true,
  }) : _clock = clock ?? DateTime.now {
    _loadFromStorage(seedDefaults: seedDefaults);
  }

  List<ReadingItem> get items => List.unmodifiable(_items);
  ReadingGoalData get goalData => _goalData;

  List<ReadingItem> get currentlyReadingItems => _items
      .where((item) => item.status == ReadingStatus.currentlyReading)
      .toList();

  List<ReadingItem> get wantToReadItems =>
      _items.where((item) => item.status == ReadingStatus.wantToRead).toList();

  List<ReadingItem> get finishedItems =>
      _items.where((item) => item.status == ReadingStatus.finished).toList();

  ReadingItem? get primaryActiveBook {
    final active = currentlyReadingItems;
    if (active.isNotEmpty) {
      active.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return active.first;
    }
    final queued = wantToReadItems;
    if (queued.isNotEmpty) {
      return queued.first;
    }
    return _items.isNotEmpty ? _items.first : null;
  }

  int get totalBooksCount => _items.length;
  int get currentlyReadingCount => currentlyReadingItems.length;
  int get wantToReadCount => wantToReadItems.length;
  int get finishedBooksCount => finishedItems.length;

  int get totalPagesRead =>
      _items.fold(0, (sum, item) => sum + item.safeCurrentPage);

  int get totalPagesAcrossLibrary => _items.fold(
      0, (sum, item) => sum + (item.totalPages > 0 ? item.totalPages : 0));

  double get overallCompletionFraction {
    final total = totalPagesAcrossLibrary;
    if (total <= 0) return 0.0;
    return (totalPagesRead / total).clamp(0.0, 1.0);
  }

  int get overallCompletionPercentage =>
      (overallCompletionFraction * 100).round().clamp(0, 100);

  // Daily goal, streak & sparkline getters
  int get dailyPageGoal => _goalData.dailyPageGoal;
  bool get eveningReminderEnabled => _goalData.eveningReminderEnabled;
  int get reminderHour => _goalData.reminderHour;
  int get reminderMinute => _goalData.reminderMinute;
  String get formattedReminderTime => _goalData.formattedReminderTime;
  Map<String, int> get dailyPagesHistory =>
      Map.unmodifiable(_goalData.dailyPagesHistory);

  int get todayPagesRead => _goalData.todayPages(_clock());
  int get dailyPagesRemaining => _goalData.pagesRemainingToday(_clock());
  double get dailyGoalProgressFraction =>
      _goalData.todayProgressFraction(_clock());
  bool get isDailyGoalMet => _goalData.isTodayGoalMet(_clock());
  int get currentStreak => _goalData.getCurrentStreak(_clock());
  int get bestStreak => _goalData.getBestStreak();

  List<DateTime> get weeklyDates => _goalData.getWeeklyDates(_clock());
  List<int> get weeklyPagesRead => _goalData.getWeeklyPages(_clock());
  int get weeklyTotalPages => _goalData.getWeeklyTotalPages(_clock());
  int get weeklyDaysMetCount => _goalData.getWeeklyDaysMetCount(_clock());
  double get weeklyAveragePages => _goalData.getWeeklyAveragePages(_clock());

  ReadingItem? findById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _rebuildPageBaselines() {
    _persistedPagesByBook
      ..clear()
      ..addEntries(
        _items.map((item) => MapEntry(item.id, item.safeCurrentPage)),
      );
  }

  void _loadFromStorage({required bool seedDefaults}) {
    _items = _storageService.loadReadingItems();
    if (_items.isEmpty && seedDefaults) {
      final now = _clock();
      _items = [
        ReadingItem(
          id: 'book_${const Uuid().v4().substring(0, 8)}',
          title: 'Atomic Habits',
          author: 'James Clear',
          category: 'Self-Growth',
          format: ReadingFormat.book,
          currentPage: 144,
          totalPages: 320,
          status: ReadingStatus.currentlyReading,
          notes: 'Tiny 1% daily improvements compound remarkably over time.',
          startedAt: now.subtract(const Duration(days: 6)),
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now,
        ),
        ReadingItem(
          id: 'book_${const Uuid().v4().substring(0, 8)}',
          title: 'The Creative Act',
          author: 'Rick Rubin',
          category: 'Creativity',
          format: ReadingFormat.book,
          currentPage: 0,
          totalPages: 406,
          status: ReadingStatus.wantToRead,
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(days: 3)),
        ),
        ReadingItem(
          id: 'book_${const Uuid().v4().substring(0, 8)}',
          title: 'Deep Work',
          author: 'Cal Newport',
          category: 'Productivity',
          format: ReadingFormat.book,
          currentPage: 296,
          totalPages: 296,
          status: ReadingStatus.finished,
          rating: 5,
          notes: 'Schedule distraction-free focus blocks on your calendar.',
          startedAt: now.subtract(const Duration(days: 24)),
          finishedAt: now.subtract(const Duration(days: 8)),
          createdAt: now.subtract(const Duration(days: 24)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
      ];
      _storageService.saveReadingItems(_items);
    }
    _rebuildPageBaselines();
    _goalData = _storageService.loadReadingGoalData();
    syncEveningReminder();
  }

  Future<void> reloadFromStorage() async {
    _items = _storageService.loadReadingItems();
    _rebuildPageBaselines();
    _goalData = _storageService.loadReadingGoalData();
    await syncEveningReminder();
    notifyListeners();
  }

  Future<void> _save() async {
    await _storageService.saveReadingItems(_items);
    notifyListeners();
  }

  Future<void> _applyDailyPageDelta(int delta, {DateTime? now}) async {
    if (delta == 0) return;
    final key = ReadingGoalData.dateKey(now ?? _clock());
    final updatedHistory = Map<String, int>.from(_goalData.dailyPagesHistory);
    final current = updatedHistory[key] ?? 0;
    final nextTotal = (current + delta).clamp(0, 999999);
    if (nextTotal == 0) {
      updatedHistory.remove(key);
    } else {
      updatedHistory[key] = nextTotal;
    }

    _goalData = _goalData.copyWith(dailyPagesHistory: updatedHistory);
    await _storageService.saveReadingGoalData(_goalData);
    await syncEveningReminder();
  }

  ReadingItem _normalizeItem(ReadingItem item, {DateTime? now}) {
    final ts = now ?? _clock();
    final safeTotal = item.totalPages < 1 ? 1 : item.totalPages;
    final safePage = item.currentPage.clamp(0, safeTotal);

    var status = item.status;
    DateTime? startedAt = item.startedAt;
    DateTime? finishedAt = item.finishedAt;

    if (safePage >= safeTotal) {
      status = ReadingStatus.finished;
      startedAt ??= ts;
      finishedAt ??= ts;
    } else if (safePage > 0 && status == ReadingStatus.wantToRead) {
      status = ReadingStatus.currentlyReading;
      startedAt ??= ts;
      finishedAt = null;
    } else if (status == ReadingStatus.finished && safePage < safeTotal) {
      status = ReadingStatus.currentlyReading;
      startedAt ??= ts;
      finishedAt = null;
    } else if (status == ReadingStatus.currentlyReading) {
      startedAt ??= ts;
      finishedAt = null;
    }

    return item.copyWith(
      totalPages: safeTotal,
      currentPage: safePage,
      status: status,
      startedAt: startedAt,
      clearStartedAt: startedAt == null,
      finishedAt: finishedAt,
      clearFinishedAt: finishedAt == null,
      updatedAt: ts,
    );
  }

  Future<void> addBook(ReadingItem item) async {
    final normalized = _normalizeItem(item);
    _items.insert(0, normalized);
    _persistedPagesByBook[normalized.id] = normalized.safeCurrentPage;
    await _save();
  }

  Future<void> updateBook(ReadingItem item) async {
    final index = _items.indexWhere((b) => b.id == item.id);
    if (index == -1) return;
    final baseline =
        _persistedPagesByBook[item.id] ?? _items[index].safeCurrentPage;
    final normalized = _normalizeItem(item);
    _items[index] = normalized;
    _persistedPagesByBook[normalized.id] = normalized.safeCurrentPage;
    await _applyDailyPageDelta(normalized.safeCurrentPage - baseline);
    await _save();
  }

  Future<void> deleteBook(String id) async {
    _items.removeWhere((b) => b.id == id);
    _persistedPagesByBook.remove(id);
    await _save();
  }

  /// Updates [currentPage] for [id] and syncs reading status & timestamps.
  /// Set [persist] to false during high-frequency slider dragging, then true on
  /// drag end. Returns true if the item transitioned to [ReadingStatus.finished].
  Future<bool> updatePageProgress(
    String id,
    int newPage, {
    bool persist = true,
  }) async {
    final index = _items.indexWhere((b) => b.id == id);
    if (index == -1) return false;

    final current = _items[index];
    final baseline = _persistedPagesByBook[id] ?? current.safeCurrentPage;
    final wasFinished = current.isCompleted;
    final maxPages = current.totalPages > 0 ? current.totalPages : 0;
    final clampedPage = maxPages > 0 ? newPage.clamp(0, maxPages) : 0;
    final now = _clock();

    ReadingStatus nextStatus;
    DateTime? startedAt = current.startedAt;
    DateTime? finishedAt = current.finishedAt;

    if (maxPages > 0 && clampedPage >= maxPages) {
      nextStatus = ReadingStatus.finished;
      startedAt ??= now;
      finishedAt ??= now;
    } else if (clampedPage > 0) {
      nextStatus = ReadingStatus.currentlyReading;
      startedAt ??= now;
      finishedAt = null;
    } else {
      nextStatus = current.status == ReadingStatus.finished
          ? ReadingStatus.wantToRead
          : current.status;
      finishedAt = null;
    }

    final updated = current.copyWith(
      currentPage: clampedPage,
      status: nextStatus,
      startedAt: startedAt,
      clearStartedAt: startedAt == null,
      finishedAt: finishedAt,
      clearFinishedAt: finishedAt == null,
      updatedAt: now,
    );

    _items[index] = updated;
    if (persist) {
      _persistedPagesByBook[id] = updated.safeCurrentPage;
      await _storageService.saveReadingItems(_items);
      await _applyDailyPageDelta(updated.safeCurrentPage - baseline, now: now);
    }
    notifyListeners();

    return !wasFinished && updated.status == ReadingStatus.finished;
  }

  Future<bool> incrementPages(String id, int deltaPages) async {
    final current = findById(id);
    if (current == null) return false;
    return updatePageProgress(id, current.safeCurrentPage + deltaPages);
  }

  Future<void> setStatus(String id, ReadingStatus status) async {
    final index = _items.indexWhere((b) => b.id == id);
    if (index == -1) return;

    final current = _items[index];
    final baseline = _persistedPagesByBook[id] ?? current.safeCurrentPage;
    final now = _clock();
    final maxPages = current.totalPages > 0 ? current.totalPages : 0;

    int nextPage = current.safeCurrentPage;
    DateTime? startedAt = current.startedAt;
    DateTime? finishedAt = current.finishedAt;
    var skipHistoryDeduction = false;

    switch (status) {
      case ReadingStatus.wantToRead:
        if (current.status == ReadingStatus.finished) {
          nextPage = 0;
          skipHistoryDeduction = true;
        }
        finishedAt = null;
        break;
      case ReadingStatus.currentlyReading:
        startedAt ??= now;
        if (maxPages > 0 && nextPage >= maxPages) {
          nextPage = (maxPages - 1).clamp(0, maxPages);
        }
        finishedAt = null;
        break;
      case ReadingStatus.finished:
        startedAt ??= now;
        finishedAt ??= now;
        nextPage = maxPages;
        break;
    }

    _items[index] = current.copyWith(
      currentPage: nextPage,
      status: status,
      startedAt: startedAt,
      clearStartedAt: startedAt == null,
      finishedAt: finishedAt,
      clearFinishedAt: finishedAt == null,
      updatedAt: now,
    );
    _persistedPagesByBook[id] = nextPage;
    if (!skipHistoryDeduction && nextPage != baseline) {
      await _applyDailyPageDelta(nextPage - baseline, now: now);
    }
    await _save();
  }

  Future<void> updateNotesAndRating(
    String id, {
    String? notes,
    int? rating,
  }) async {
    final index = _items.indexWhere((b) => b.id == id);
    if (index == -1) return;

    final current = _items[index];
    _items[index] = current.copyWith(
      notes: notes,
      clearNotes: notes != null && notes.trim().isEmpty,
      rating: rating?.clamp(1, 5),
      updatedAt: _clock(),
    );
    await _save();
  }

  // --- Daily Reading Goal, Sparkline History & Evening Pippin Nudge ---

  Future<void> setDailyPageGoal(int pages) async {
    final clamped = pages.clamp(
      ReadingGoalData.minDailyGoal,
      ReadingGoalData.maxDailyGoal,
    );
    _goalData = _goalData.copyWith(dailyPageGoal: clamped);
    await _storageService.saveReadingGoalData(_goalData);
    await syncEveningReminder();
    notifyListeners();
  }

  Future<void> toggleEveningReminder(bool enabled) async {
    _goalData = _goalData.copyWith(eveningReminderEnabled: enabled);
    await _storageService.saveReadingGoalData(_goalData);
    await syncEveningReminder();
    notifyListeners();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    _goalData = _goalData.copyWith(
      reminderHour: hour.clamp(0, 23),
      reminderMinute: minute.clamp(0, 59),
    );
    await _storageService.saveReadingGoalData(_goalData);
    await syncEveningReminder();
    notifyListeners();
  }

  /// Logs explicit page delta (positive or negative) for [date] (defaults today).
  Future<void> logDailyPages(int deltaPages, {DateTime? date}) async {
    if (deltaPages == 0) return;
    await _applyDailyPageDelta(deltaPages, now: date);
    notifyListeners();
  }

  /// Sets the exact pages read count for a YYYY-MM-DD [dateKey].
  Future<void> recordHistoricalPages(String dateKey, int pages) async {
    final updatedHistory = Map<String, int>.from(_goalData.dailyPagesHistory);
    final sanitized = pages.clamp(0, 999999);
    if (sanitized == 0) {
      updatedHistory.remove(dateKey);
    } else {
      updatedHistory[dateKey] = sanitized;
    }
    _goalData = _goalData.copyWith(dailyPagesHistory: updatedHistory);
    await _storageService.saveReadingGoalData(_goalData);
    await syncEveningReminder();
    notifyListeners();
  }

  /// Next scheduled evening reminder timestamp, or `null` when reminders are OFF.
  ///
  /// When today's goal is already met or today's configured evening time has
  /// passed, Pippin automatically advances the next nudge to tomorrow evening.
  DateTime? computeNextReminderDateTime([DateTime? referenceNow]) {
    if (!_goalData.eveningReminderEnabled) return null;
    final now = referenceNow ?? _clock();
    final todaySlot = DateTime(
      now.year,
      now.month,
      now.day,
      _goalData.reminderHour,
      _goalData.reminderMinute,
    );
    if (_goalData.isTodayGoalMet(now) || !todaySlot.isAfter(now)) {
      return todaySlot.add(const Duration(days: 1));
    }
    return todaySlot;
  }

  String buildEveningReminderBody({DateTime? forDate}) {
    final now = _clock();
    final targetDate = forDate ?? computeNextReminderDateTime(now) ?? now;
    final isTodayTarget =
        ReadingGoalData.dateKey(targetDate) == ReadingGoalData.dateKey(now);
    final goal = _goalData.dailyPageGoal;
    final book = primaryActiveBook;
    final bookSuffix =
        book != null && !book.isCompleted ? ' in "${book.title}"' : '';
    final streak = _goalData.getCurrentStreak(now);

    if (isTodayTarget) {
      final todayRead = _goalData.todayPages(now);
      final remaining = _goalData.pagesRemainingToday(now);
      if (todayRead <= 0) {
        if (streak > 0) {
          return 'Read $goal pages today$bookSuffix to keep your $streak-day reading streak alive!';
        }
        return 'Read $goal pages today$bookSuffix!';
      }
      if (remaining > 0) {
        if (streak > 0) {
          return '$remaining pages left to hit your $goal-page goal$bookSuffix & protect your $streak-day streak!';
        }
        return '$remaining pages left to hit your $goal-page goal today$bookSuffix!';
      }
    }

    if (streak > 0) {
      return 'Read $goal pages today$bookSuffix to keep your $streak-day reading streak going!';
    }
    return 'Read $goal pages today$bookSuffix!';
  }

  Future<void> syncEveningReminder([DateTime? referenceNow]) async {
    final notif = notificationService;
    if (notif == null) return;

    final syncEpoch = ++_reminderSyncEpoch;
    final nextSlot = computeNextReminderDateTime(referenceNow);
    final body =
        nextSlot != null ? buildEveningReminderBody(forDate: nextSlot) : null;

    await notif.cancel(eveningReminderNotificationId);
    if (syncEpoch != _reminderSyncEpoch || nextSlot == null || body == null) {
      return;
    }

    await notif.scheduleReadingNotification(
      id: eveningReminderNotificationId,
      title: '🦜 Pippin — Daily Reading Goal',
      body: body,
      scheduledDate: nextSlot,
      payload: reminderPayload,
    );
  }

  Future<void> testSendEveningNudgeNow() async {
    final notif = notificationService;
    if (notif == null) return;
    final now = _clock();
    await notif.showReadingNotification(
      id: previewReminderNotificationId,
      title: '🦜 Pippin — Daily Reading Nudge',
      body: buildEveningReminderBody(forDate: now),
      payload: reminderPayload,
    );
  }
}
