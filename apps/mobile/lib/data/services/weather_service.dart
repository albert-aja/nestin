import 'package:flutter/foundation.dart';

/// Current local weather snapshot consumed by the dashboard and Scout BeforeYouGo.
class WeatherInfo {
  static const int rainProbabilityThresholdPercent = 40;
  static const int heavyRainProbabilityThresholdPercent = 65;
  static const double coolTempThresholdCelsius = 21.0;
  static const double coolLowTempThresholdCelsius = 19.0;
  static const double coldTempThresholdCelsius = 14.0;

  final double temperatureCelsius;
  final String condition;
  final String locationName;
  final double highTemp;
  final double lowTemp;
  final int rainChancePercent;
  final String advice;

  const WeatherInfo({
    required this.temperatureCelsius,
    required this.condition,
    required this.locationName,
    required this.highTemp,
    required this.lowTemp,
    required this.rainChancePercent,
    required this.advice,
  });

  /// True when rain is likely based on precipitation probability or sky condition.
  bool get isRainy {
    if (rainChancePercent >= rainProbabilityThresholdPercent) return true;
    final lower = condition.toLowerCase();
    return lower.contains('rain') ||
        lower.contains('drizzle') ||
        lower.contains('shower') ||
        lower.contains('storm') ||
        lower.contains('thunder') ||
        lower.contains('downpour') ||
        lower.contains('hujan') ||
        lower.contains('gerimis') ||
        lower.contains('badai');
  }

  /// True when heavy rain or storms warrant additional rain protection.
  bool get isHeavyRain {
    if (rainChancePercent >= heavyRainProbabilityThresholdPercent) return true;
    final lower = condition.toLowerCase();
    return lower.contains('heavy rain') ||
        lower.contains('storm') ||
        lower.contains('thunder') ||
        lower.contains('downpour') ||
        lower.contains('badai');
  }

  /// True when ambient or expected low temperature drops into cool-layer range.
  bool get isCool =>
      temperatureCelsius <= coolTempThresholdCelsius ||
      lowTemp <= coolLowTempThresholdCelsius;

  /// True when temperatures are cold enough for an extra insulating layer.
  bool get isCold =>
      temperatureCelsius <= coldTempThresholdCelsius || lowTemp <= 12.0;

  /// True whenever BeforeYouGo should check seasonal gear against the active checklist.
  bool get hasBeforeYouGoAdvisories => isRainy || isCool;
}

/// Offline forecast scenarios allowing deterministic simulation and quick preview
/// across sunny, rainy, cool, and stormy conditions alongside automatic time-of-day sensing.
enum LocalWeatherScenario {
  auto,
  clearWarm,
  rainyShowers,
  coolBreeze,
  coldStorm,
}

extension LocalWeatherScenarioExt on LocalWeatherScenario {
  String get id {
    switch (this) {
      case LocalWeatherScenario.auto:
        return 'auto';
      case LocalWeatherScenario.clearWarm:
        return 'clear_warm';
      case LocalWeatherScenario.rainyShowers:
        return 'rainy_showers';
      case LocalWeatherScenario.coolBreeze:
        return 'cool_breeze';
      case LocalWeatherScenario.coldStorm:
        return 'cold_storm';
    }
  }

  String localizedLabel(String languageCode) {
    final isId = languageCode.toLowerCase().startsWith('id');
    switch (this) {
      case LocalWeatherScenario.auto:
        return isId ? 'Otomatis' : 'Auto';
      case LocalWeatherScenario.clearWarm:
        return isId ? 'Cerah Hangat' : 'Clear & Warm';
      case LocalWeatherScenario.rainyShowers:
        return isId ? 'Hujan Ringan' : 'Rain Showers';
      case LocalWeatherScenario.coolBreeze:
        return isId ? 'Angin Sejuk' : 'Cool Breeze';
      case LocalWeatherScenario.coldStorm:
        return isId ? 'Hujan & Dingin' : 'Cold & Stormy';
    }
  }

  static LocalWeatherScenario fromId(String? raw) {
    if (raw == null || raw.isEmpty) return LocalWeatherScenario.auto;
    for (final value in LocalWeatherScenario.values) {
      if (value.id == raw) return value;
    }
    return LocalWeatherScenario.auto;
  }
}

abstract class WeatherProviderInterface {
  Future<WeatherInfo> getCurrentWeather();
}

class LocalWeatherService implements WeatherProviderInterface {
  final DateTime Function() _clock;
  WeatherInfo? _weatherOverride;
  LocalWeatherScenario _scenario;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  LocalWeatherService({
    DateTime Function()? clock,
    WeatherInfo? overrideWeather,
    LocalWeatherScenario initialScenario = LocalWeatherScenario.auto,
  })  : _clock = clock ?? DateTime.now,
        _weatherOverride = overrideWeather,
        _scenario = initialScenario;

  LocalWeatherScenario get scenario => _scenario;
  WeatherInfo? get overrideWeather => _weatherOverride;

  void addWeatherListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeWeatherListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyWeatherListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void setScenario(LocalWeatherScenario next) {
    if (_scenario == next && _weatherOverride == null) return;
    _weatherOverride = null;
    _scenario = next;
    _notifyWeatherListeners();
  }

  void setOverrideWeather(WeatherInfo? info) {
    _weatherOverride = info;
    _notifyWeatherListeners();
  }

  @override
  Future<WeatherInfo> getCurrentWeather() async {
    if (_weatherOverride != null) {
      return _weatherOverride!;
    }

    switch (_scenario) {
      case LocalWeatherScenario.clearWarm:
        return const WeatherInfo(
          temperatureCelsius: 28,
          condition: 'Partly Sunny',
          locationName: 'Local Area',
          highTemp: 30,
          lowTemp: 23,
          rainChancePercent: 10,
          advice: 'Warm and bright outside. Remember to stay hydrated.',
        );
      case LocalWeatherScenario.rainyShowers:
        return const WeatherInfo(
          temperatureCelsius: 23,
          condition: 'Passing Rain Showers',
          locationName: 'Local Area',
          highTemp: 25,
          lowTemp: 21,
          rainChancePercent: 75,
          advice: 'Rain showers expected. Pack an umbrella before heading out.',
        );
      case LocalWeatherScenario.coolBreeze:
        return const WeatherInfo(
          temperatureCelsius: 18,
          condition: 'Cool Breeze',
          locationName: 'Local Area',
          highTemp: 21,
          lowTemp: 15,
          rainChancePercent: 20,
          advice: 'Crisp temperatures today. A light jacket is recommended.',
        );
      case LocalWeatherScenario.coldStorm:
        return const WeatherInfo(
          temperatureCelsius: 13,
          condition: 'Cold Rain & Wind',
          locationName: 'Local Area',
          highTemp: 15,
          lowTemp: 11,
          rainChancePercent: 85,
          advice: 'Cold wet conditions ahead. Pack rain protection and warm layers.',
        );
      case LocalWeatherScenario.auto:
        return _weatherForLocalTime(_clock());
    }
  }

  WeatherInfo _weatherForLocalTime(DateTime now) {
    final hour = now.hour;
    if (hour >= 0 && hour < 6) {
      return const WeatherInfo(
        temperatureCelsius: 19,
        condition: 'Cool Early Dawn',
        locationName: 'Local Area',
        highTemp: 27,
        lowTemp: 17,
        rainChancePercent: 20,
        advice: 'Chilly pre-dawn air. Bring a light jacket if heading out.',
      );
    } else if (hour >= 6 && hour < 12) {
      return const WeatherInfo(
        temperatureCelsius: 24,
        condition: 'Clear Morning',
        locationName: 'Local Area',
        highTemp: 29,
        lowTemp: 22,
        rainChancePercent: 10,
        advice: 'Pleasant start to the day. Great for an early walk!',
      );
    } else if (hour >= 12 && hour < 17) {
      return const WeatherInfo(
        temperatureCelsius: 30,
        condition: 'Partly Sunny',
        locationName: 'Local Area',
        highTemp: 31,
        lowTemp: 23,
        rainChancePercent: 20,
        advice: 'Warm afternoon. Remember to stay hydrated.',
      );
    } else if (hour >= 17 && hour < 20) {
      return const WeatherInfo(
        temperatureCelsius: 24,
        condition: 'Calm Evening',
        locationName: 'Local Area',
        highTemp: 29,
        lowTemp: 20,
        rainChancePercent: 15,
        advice: 'Mild evening breeze settling in. Good time to unwind.',
      );
    } else {
      return const WeatherInfo(
        temperatureCelsius: 20,
        condition: 'Cool Night Air',
        locationName: 'Local Area',
        highTemp: 28,
        lowTemp: 18,
        rainChancePercent: 25,
        advice: 'Evening temperatures are cooling down. Bring a light jacket out.',
      );
    }
  }
}
