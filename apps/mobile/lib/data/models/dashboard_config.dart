class DashboardConfig {
  final bool showWeather;
  final bool showNextAlarm;
  final bool showTodayAgenda;
  final bool showTodayTasks;
  final bool showRoutines;
  final bool showLocationReminders;
  final bool showBeforeYouGo;
  final bool showHydration;
  final bool showWellness;
  final bool showReading;
  final bool showMoney;
  final bool showQuickJournal;
  final List<String> sectionOrder;

  static const String sectionWeather = 'weather';
  static const String sectionNextAlarm = 'next_alarm';
  static const String sectionAgenda = 'agenda';
  static const String sectionLocationReminders = 'location_reminders';
  static const String sectionBeforeYouGo = 'before_you_go';
  static const String sectionTasks = 'tasks';
  static const String sectionRoutines = 'routines';
  static const String sectionHydration = 'hydration';
  static const String sectionWellness = 'wellness';
  static const String sectionReading = 'reading';
  static const String sectionMoney = 'money';
  static const String sectionMood = 'mood';

  static const List<String> defaultSectionOrder = [
    sectionWeather,
    sectionNextAlarm,
    sectionAgenda,
    sectionLocationReminders,
    sectionBeforeYouGo,
    sectionTasks,
    sectionRoutines,
    sectionHydration,
    sectionWellness,
    sectionReading,
    sectionMoney,
    sectionMood,
  ];

  const DashboardConfig({
    this.showWeather = true,
    this.showNextAlarm = true,
    this.showTodayAgenda = true,
    this.showLocationReminders = true,
    this.showBeforeYouGo = true,
    this.showTodayTasks = true,
    this.showRoutines = true,
    this.showHydration = true,
    this.showWellness = true,
    this.showReading = true,
    this.showMoney = true,
    this.showQuickJournal = true,
    this.sectionOrder = defaultSectionOrder,
  });

  DashboardConfig copyWith({
    bool? showWeather,
    bool? showNextAlarm,
    bool? showTodayAgenda,
    bool? showLocationReminders,
    bool? showBeforeYouGo,
    bool? showTodayTasks,
    bool? showRoutines,
    bool? showHydration,
    bool? showWellness,
    bool? showReading,
    bool? showMoney,
    bool? showQuickJournal,
    List<String>? sectionOrder,
  }) {
    return DashboardConfig(
      showWeather: showWeather ?? this.showWeather,
      showNextAlarm: showNextAlarm ?? this.showNextAlarm,
      showTodayAgenda: showTodayAgenda ?? this.showTodayAgenda,
      showLocationReminders:
          showLocationReminders ?? this.showLocationReminders,
      showBeforeYouGo: showBeforeYouGo ?? this.showBeforeYouGo,
      showTodayTasks: showTodayTasks ?? this.showTodayTasks,
      showRoutines: showRoutines ?? this.showRoutines,
      showHydration: showHydration ?? this.showHydration,
      showWellness: showWellness ?? this.showWellness,
      showReading: showReading ?? this.showReading,
      showMoney: showMoney ?? this.showMoney,
      showQuickJournal: showQuickJournal ?? this.showQuickJournal,
      sectionOrder: sectionOrder ?? this.sectionOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'showWeather': showWeather,
        'showNextAlarm': showNextAlarm,
        'showTodayAgenda': showTodayAgenda,
        'showLocationReminders': showLocationReminders,
        'showBeforeYouGo': showBeforeYouGo,
        'showTodayTasks': showTodayTasks,
        'showRoutines': showRoutines,
        'showHydration': showHydration,
        'showWellness': showWellness,
        'showReading': showReading,
        'showMoney': showMoney,
        'showQuickJournal': showQuickJournal,
        'sectionOrder': sectionOrder,
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['sectionOrder'] as List<dynamic>?;
    final order = rawOrder != null
        ? rawOrder.map((e) => e.toString()).toList()
        : List<String>.from(defaultSectionOrder);
    if (!order.contains(sectionLocationReminders)) {
      final agendaIdx = order.indexOf(sectionAgenda);
      if (agendaIdx != -1) {
        order.insert(agendaIdx + 1, sectionLocationReminders);
      } else {
        order.add(sectionLocationReminders);
      }
    }
    if (!order.contains(sectionBeforeYouGo)) {
      final locIdx = order.indexOf(sectionLocationReminders);
      if (locIdx != -1) {
        order.insert(locIdx + 1, sectionBeforeYouGo);
      } else {
        order.add(sectionBeforeYouGo);
      }
    }
    if (!order.contains(sectionWellness)) {
      final hydrationIdx = order.indexOf(sectionHydration);
      if (hydrationIdx != -1) {
        order.insert(hydrationIdx + 1, sectionWellness);
      } else {
        order.add(sectionWellness);
      }
    }
    if (!order.contains(sectionReading)) {
      final wellnessIdx = order.indexOf(sectionWellness);
      if (wellnessIdx != -1) {
        order.insert(wellnessIdx + 1, sectionReading);
      } else {
        order.add(sectionReading);
      }
    }
    if (!order.contains(sectionMoney)) {
      final readingIdx = order.indexOf(sectionReading);
      if (readingIdx != -1) {
        order.insert(readingIdx + 1, sectionMoney);
      } else {
        order.add(sectionMoney);
      }
    }

    return DashboardConfig(
      showWeather: json['showWeather'] as bool? ?? true,
      showNextAlarm: json['showNextAlarm'] as bool? ?? true,
      showTodayAgenda: json['showTodayAgenda'] as bool? ?? true,
      showLocationReminders: json['showLocationReminders'] as bool? ?? true,
      showBeforeYouGo: json['showBeforeYouGo'] as bool? ?? true,
      showTodayTasks: json['showTodayTasks'] as bool? ?? true,
      showRoutines: json['showRoutines'] as bool? ?? true,
      showHydration: json['showHydration'] as bool? ?? true,
      showWellness: json['showWellness'] as bool? ?? true,
      showReading: json['showReading'] as bool? ?? true,
      showMoney: json['showMoney'] as bool? ?? true,
      showQuickJournal: json['showQuickJournal'] as bool? ?? true,
      sectionOrder: order,
    );
  }
}
