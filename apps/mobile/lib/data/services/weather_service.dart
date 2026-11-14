class WeatherInfo {
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
}

abstract class WeatherProviderInterface {
  Future<WeatherInfo> getCurrentWeather();
}

class LocalWeatherService implements WeatherProviderInterface {
  @override
  Future<WeatherInfo> getCurrentWeather() async {
    // Sensible local default providing immediate everyday context
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
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
    } else {
      return const WeatherInfo(
        temperatureCelsius: 26,
        condition: 'Calm Evening',
        locationName: 'Local Area',
        highTemp: 30,
        lowTemp: 22,
        rainChancePercent: 15,
        advice: 'Cool breeze settling in. Good time to unwind.',
      );
    }
  }
}

