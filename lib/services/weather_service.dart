import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class LiveWeatherData {
  final String location;
  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double windSpeedKmH;
  final String condition;
  final IconData icon;

  const LiveWeatherData({
    required this.location,
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windSpeedKmH,
    required this.condition,
    required this.icon,
  });

  static const LiveWeatherData defaultFallback = LiveWeatherData(
    location: 'Laguna, Philippines',
    tempC: 28.0,
    feelsLikeC: 30.0,
    humidity: 80,
    windSpeedKmH: 10.0,
    condition: 'Partly Cloudy',
    icon: CupertinoIcons.cloud_sun_fill,
  );
}

/// Real-time live weather service powered by Open-Meteo & IP Geolocation.
/// Provides real-time temperature, humidity, wind, and city/municipality location.
class WeatherService {
  static LiveWeatherData _current = LiveWeatherData.defaultFallback;
  static DateTime? _lastFetch;
  static double _lastLat = 14.0741;
  static double _lastLon = 121.3298;
  static String _lastCity = 'Laguna, Philippines';
  static bool _locationResolved = false;

  static LiveWeatherData get current => _current;

  /// Fetches live location and real weather data.
  /// Caches responses within 5 seconds to avoid unnecessary requests.
  static Future<LiveWeatherData> fetchWeather({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastFetch != null && now.difference(_lastFetch!).inSeconds < 5) {
      return _current;
    }

    try {
      // 1. Resolve Location if not yet resolved or if forced
      if (!_locationResolved || force) {
        try {
          final locUri = Uri.parse('http://ip-api.com/json/?fields=status,city,regionName,lat,lon');
          final locRes = await http.get(locUri).timeout(const Duration(seconds: 4));
          if (locRes.statusCode == 200) {
            final locData = jsonDecode(locRes.body) as Map<String, dynamic>;
            if (locData['status'] == 'success') {
              final city = locData['city'] as String? ?? '';
              final region = locData['regionName'] as String? ?? '';
              if (city.isNotEmpty) {
                _lastCity = region.isNotEmpty ? '$city, $region' : city;
              }
              if (locData['lat'] != null && locData['lon'] != null) {
                _lastLat = (locData['lat'] as num).toDouble();
                _lastLon = (locData['lon'] as num).toDouble();
              }
              _locationResolved = true;
            }
          }
        } catch (_) {
          // Keep previous or fallback coordinates
        }
      }

      // 2. Fetch live weather from Open-Meteo
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lastLat&longitude=$_lastLon&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
      );
      final res = await http.get(weatherUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final currentMap = data['current'] as Map<String, dynamic>?;
        if (currentMap != null) {
          final temp = (currentMap['temperature_2m'] as num?)?.toDouble() ?? 28.0;
          final feelsLike = (currentMap['apparent_temperature'] as num?)?.toDouble() ?? (temp + 2.0);
          final humidity = (currentMap['relative_humidity_2m'] as num?)?.toInt() ?? 80;
          final wind = (currentMap['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
          final code = (currentMap['weather_code'] as num?)?.toInt() ?? 1;

          final conditionAndIcon = _interpretWeatherCode(code);

          _current = LiveWeatherData(
            location: _lastCity,
            tempC: temp,
            feelsLikeC: feelsLike,
            humidity: humidity,
            windSpeedKmH: wind,
            condition: conditionAndIcon.$1,
            icon: conditionAndIcon.$2,
          );
          _lastFetch = now;
        }
      }
    } catch (_) {
      // Graceful fallback to existing _current
    }

    return _current;
  }

  static (String, IconData) _interpretWeatherCode(int code) {
    switch (code) {
      case 0:
        return ('Clear Sky', CupertinoIcons.sun_max_fill);
      case 1:
        return ('Mainly Clear', CupertinoIcons.sun_max_fill);
      case 2:
        return ('Partly Cloudy', CupertinoIcons.cloud_sun_fill);
      case 3:
        return ('Overcast', CupertinoIcons.cloud_fill);
      case 45:
      case 48:
        return ('Foggy', CupertinoIcons.cloud_fog_fill);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', CupertinoIcons.cloud_drizzle_fill);
      case 61:
      case 63:
      case 65:
        return ('Rainy', CupertinoIcons.cloud_rain_fill);
      case 80:
      case 81:
      case 82:
        return ('Rain Showers', CupertinoIcons.cloud_heavyrain_fill);
      case 95:
      case 96:
      case 99:
        return ('Thunderstorm', CupertinoIcons.cloud_bolt_rain_fill);
      default:
        return ('Cloudy', CupertinoIcons.cloud_fill);
    }
  }
}
