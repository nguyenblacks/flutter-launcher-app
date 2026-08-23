import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final int weatherCode;

  WeatherData({required this.temperature, required this.weatherCode});
}

class WeatherService {
  // Free IP geolocation API (HTTPS enabled)
  static const _ipApiUrl = 'https://ipinfo.io/json';

  // Open-Meteo API (requires no API key)
  static const _weatherApiUrl = 'https://api.open-meteo.com/v1/forecast';

  static Future<WeatherData?> getCurrentWeather() async {
    try {
      // 1. Get approximate location from IP
      final locationResponse = await http.get(Uri.parse(_ipApiUrl));
      if (locationResponse.statusCode != 200) return null;

      final locationData = jsonDecode(locationResponse.body);
      final String? loc = locationData['loc'];
      if (loc == null) return null;

      final parts = loc.split(',');
      if (parts.length != 2) return null;

      final double? lat = double.tryParse(parts[0]);
      final double? lon = double.tryParse(parts[1]);

      if (lat == null || lon == null) return null;

      // 2. Fetch weather for those coordinates
      final weatherUrl = Uri.parse(
        '$_weatherApiUrl?latitude=$lat&longitude=$lon&current_weather=true',
      );
      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode != 200) return null;

      final weatherData = jsonDecode(weatherResponse.body);
      final current = weatherData['current_weather'];

      return WeatherData(
        temperature: (current['temperature'] as num).toDouble(),
        weatherCode: (current['weathercode'] as num).toInt(),
      );
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }
}
