import 'package:flutter/material.dart';
import '../data/models/dashboard_config.dart';
import '../data/services/storage_service.dart';

class DashboardProvider extends ChangeNotifier {
  final StorageService _storageService;
  late DashboardConfig _config;

  DashboardProvider(this._storageService) {
    _config = _storageService.loadDashboardConfig();
  }

  DashboardConfig get config => _config;

  Future<void> updateConfig(DashboardConfig newConfig) async {
    _config = newConfig;
    await _storageService.saveDashboardConfig(_config);
    notifyListeners();
  }

  Future<void> toggleWeather(bool val) async {
    await updateConfig(_config.copyWith(showWeather: val));
  }

  Future<void> toggleNextAlarm(bool val) async {
    await updateConfig(_config.copyWith(showNextAlarm: val));
  }

  Future<void> toggleTodayAgenda(bool val) async {
    await updateConfig(_config.copyWith(showTodayAgenda: val));
  }

  Future<void> toggleLocationReminders(bool val) async {
    await updateConfig(_config.copyWith(showLocationReminders: val));
  }

  Future<void> toggleBeforeYouGo(bool val) async {
    await updateConfig(_config.copyWith(showBeforeYouGo: val));
  }

  Future<void> toggleTodayTasks(bool val) async {
    await updateConfig(_config.copyWith(showTodayTasks: val));
  }

  Future<void> toggleRoutines(bool val) async {
    await updateConfig(_config.copyWith(showRoutines: val));
  }

  Future<void> toggleHydration(bool val) async {
    await updateConfig(_config.copyWith(showHydration: val));
  }

  Future<void> toggleWellness(bool val) async {
    await updateConfig(_config.copyWith(showWellness: val));
  }

  Future<void> toggleReading(bool val) async {
    await updateConfig(_config.copyWith(showReading: val));
  }

  Future<void> toggleMoney(bool val) async {
    await updateConfig(_config.copyWith(showMoney: val));
  }

  Future<void> toggleQuickJournal(bool val) async {
    await updateConfig(_config.copyWith(showQuickJournal: val));
  }

  Future<void> reorderSections(int oldIndex, int newIndex) async {
    final list = List<String>.from(_config.sectionOrder);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await updateConfig(_config.copyWith(sectionOrder: list));
  }

  Future<void> setSectionOrder(List<String> newOrder) async {
    await updateConfig(_config.copyWith(sectionOrder: newOrder));
  }

  Future<void> resetSectionOrder() async {
    await updateConfig(
      _config.copyWith(sectionOrder: DashboardConfig.defaultSectionOrder),
    );
  }
}
