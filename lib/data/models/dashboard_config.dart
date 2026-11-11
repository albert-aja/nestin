class DashboardConfig {
  final bool showWeather;
  final bool showNextAlarm;
  final bool showTodayAgenda;
  final bool showTodayTasks;
  final bool showRoutines;
  final bool showQuickJournal;
  final List<String> sectionOrder;

  static const String sectionWeather = 'weather';
  static const String sectionNextAlarm = 'next_alarm';
  static const String sectionAgenda = 'agenda';
  static const String sectionTasks = 'tasks';
  static const String sectionRoutines = 'routines';
  static const String sectionMood = 'mood';

  static const List<String> defaultSectionOrder = [
    sectionWeather,
    sectionNextAlarm,
    sectionAgenda,
    sectionTasks,
    sectionRoutines,
    sectionMood,
  ];

  const DashboardConfig({
    this.showWeather = true,
    this.showNextAlarm = true,
    this.showTodayAgenda = true,
    this.showTodayTasks = true,
    this.showRoutines = true,
    this.showQuickJournal = true,
    this.sectionOrder = defaultSectionOrder,
  });

  DashboardConfig copyWith({
    bool? showWeather,
    bool? showNextAlarm,
    bool? showTodayAgenda,
    bool? showTodayTasks,
    bool? showRoutines,
    bool? showQuickJournal,
    List<String>? sectionOrder,
  }) {
    return DashboardConfig(
      showWeather: showWeather ?? this.showWeather,
      showNextAlarm: showNextAlarm ?? this.showNextAlarm,
      showTodayAgenda: showTodayAgenda ?? this.showTodayAgenda,
      showTodayTasks: showTodayTasks ?? this.showTodayTasks,
      showRoutines: showRoutines ?? this.showRoutines,
      showQuickJournal: showQuickJournal ?? this.showQuickJournal,
      sectionOrder: sectionOrder ?? this.sectionOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'showWeather': showWeather,
        'showNextAlarm': showNextAlarm,
        'showTodayAgenda': showTodayAgenda,
        'showTodayTasks': showTodayTasks,
        'showRoutines': showRoutines,
        'showQuickJournal': showQuickJournal,
        'sectionOrder': sectionOrder,
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['sectionOrder'] as List<dynamic>?;
    final order = rawOrder != null
        ? rawOrder.map((e) => e.toString()).toList()
        : defaultSectionOrder;

    return DashboardConfig(
      showWeather: json['showWeather'] as bool? ?? true,
      showNextAlarm: json['showNextAlarm'] as bool? ?? true,
      showTodayAgenda: json['showTodayAgenda'] as bool? ?? true,
      showTodayTasks: json['showTodayTasks'] as bool? ?? true,
      showRoutines: json['showRoutines'] as bool? ?? true,
      showQuickJournal: json['showQuickJournal'] as bool? ?? true,
      sectionOrder: order,
    );
  }
}
