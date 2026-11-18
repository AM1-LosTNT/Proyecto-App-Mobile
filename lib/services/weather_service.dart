import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherDayForecast {
  final String date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;
  final double windSpeedMax;

  WeatherDayForecast({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
    required this.windSpeedMax,
  });

  String get weatherDescription => WeatherService.getWeatherDescription(weatherCode);
  IconData get weatherIcon => WeatherService.getWeatherIcon(weatherCode);
}

class WeatherCurrentData {
  final double temperature;
  final int humidity;
  final double precipitation;
  final int weatherCode;
  final double windSpeed;

  WeatherCurrentData({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed,
  });

  String get weatherDescription => WeatherService.getWeatherDescription(weatherCode);
  IconData get weatherIcon => WeatherService.getWeatherIcon(weatherCode);
}

class WeatherForecastResult {
  final WeatherCurrentData current;
  final List<WeatherDayForecast> daily;

  WeatherForecastResult({
    required this.current,
    required this.daily,
  });
}

class WeatherService {
  static const double defaultLat = -17.7833;
  static const double defaultLng = -63.1821;

  // Cache para no saturar consultas en mapa y pantallas
  static WeatherForecastResult? _cachedResult;
  static DateTime? _lastFetchTime;

  static Future<WeatherForecastResult?> fetchForecast({
    double latitude = defaultLat,
    double longitude = defaultLng,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedResult != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 15) {
      return _cachedResult;
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,relative_humidity_2m,precipitation,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max'
        '&forecast_days=10&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return _cachedResult;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final currentMap = data['current'] as Map<String, dynamic>? ?? {};
      final current = WeatherCurrentData(
        temperature: (currentMap['temperature_2m'] as num?)?.toDouble() ?? 25.0,
        humidity: (currentMap['relative_humidity_2m'] as num?)?.toInt() ?? 60,
        precipitation: (currentMap['precipitation'] as num?)?.toDouble() ?? 0.0,
        weatherCode: (currentMap['weather_code'] as num?)?.toInt() ?? 0,
        windSpeed: (currentMap['wind_speed_10m'] as num?)?.toDouble() ?? 10.0,
      );

      final dailyMap = data['daily'] as Map<String, dynamic>? ?? {};
      final times = (dailyMap['time'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final codes = (dailyMap['weather_code'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final maxTemps = (dailyMap['temperature_2m_max'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
      final minTemps = (dailyMap['temperature_2m_min'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
      final precProbs = (dailyMap['precipitation_probability_max'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final windSpeeds = (dailyMap['wind_speed_10m_max'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

      final List<WeatherDayForecast> dailyList = [];
      for (int i = 0; i < times.length; i++) {
        dailyList.add(
          WeatherDayForecast(
            date: times[i],
            weatherCode: i < codes.length ? codes[i] : 0,
            tempMax: i < maxTemps.length ? maxTemps[i] : 28.0,
            tempMin: i < minTemps.length ? minTemps[i] : 20.0,
            precipitationProbability: i < precProbs.length ? precProbs[i] : 0,
            windSpeedMax: i < windSpeeds.length ? windSpeeds[i] : 10.0,
          ),
        );
      }

      final result = WeatherForecastResult(current: current, daily: dailyList);
      _cachedResult = result;
      _lastFetchTime = now;
      return result;
    } catch (_) {
      return _cachedResult;
    }
  }

  /// Busca el pronóstico de un día específico (formato YYYY-MM-DD o DateTime)
  static WeatherDayForecast? getForecastForDate(DateTime date, {WeatherForecastResult? forecastData}) {
    final data = forecastData ?? _cachedResult;
    if (data == null) return null;
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    for (final day in data.daily) {
      if (day.date == dateStr) {
        return day;
      }
    }
    return null;
  }

  static String getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Cielo despejado';
      case 1:
        return 'Mayormente despejado';
      case 2:
        return 'Parcialmente nublado';
      case 3:
        return 'Nublado';
      case 45:
      case 48:
        return 'Neblina';
      case 51:
      case 53:
      case 55:
        return 'Llovizna';
      case 61:
      case 63:
      case 65:
        return 'Lluvia';
      case 71:
      case 73:
      case 75:
        return 'Nieve';
      case 80:
      case 81:
      case 82:
        return 'Chubascos';
      case 95:
      case 96:
      case 99:
        return 'Tormenta eléctrica';
      default:
        return 'Clima agradable';
    }
  }

  static IconData getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 61:
      case 63:
      case 65:
        return Icons.umbrella_rounded;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on_rounded;
      default:
        return Icons.wb_sunny_outlined;
    }
  }
}
