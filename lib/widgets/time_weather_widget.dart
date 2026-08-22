import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swavoti/services/weather_service.dart';
import 'package:swavoti/widgets/weather_icon.dart';
import 'package:swavoti/services/launcher_service.dart';

class TimeWeatherWidget extends StatefulWidget {
  final VoidCallback onRemove;

  const TimeWeatherWidget({super.key, required this.onRemove});

  @override
  State<TimeWeatherWidget> createState() => _TimeWeatherWidgetState();
}

class _TimeWeatherWidgetState extends State<TimeWeatherWidget> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  WeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final weather = await WeatherService.getCurrentWeather();
    if (mounted && weather != null) {
      setState(() => _weatherData = weather);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Time & Weather?'),
            content: const Text('You can re-enable this later in Home Settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onRemove();
                },
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Time & Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentTime.hour}:${_currentTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  '${_currentTime.day}/${_currentTime.month}/${_currentTime.year}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Right: small weather info, tappable
            if (_weatherData != null)
              GestureDetector(
                onTap: () {
                  LauncherService.launchGoogleWeather();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    WeatherIcon(
                      weatherCode: _weatherData!.weatherCode,
                      size: 32,
                      isNight: _currentTime.hour < 6 || _currentTime.hour >= 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_weatherData!.temperature.round()}°',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
