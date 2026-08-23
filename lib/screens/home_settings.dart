import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swavoti/services/launcher_service.dart';

class HomeSettings extends StatefulWidget {
  const HomeSettings({super.key});

  @override
  State<HomeSettings> createState() => _HomeSettingsState();
}

class _HomeSettingsState extends State<HomeSettings> {
  bool _notificationDotsEnabled = false;
  bool _isLoading = true;
  String _feedProvider = 'msn';
  bool _showTimeWeather = true;
  int _gridColumns = 4;
  bool _showHiddenApps = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationDotsEnabled = prefs.getBool('notification_dots_enabled') ?? false;
        _feedProvider = prefs.getString('feed_provider') ?? 'msn';
        _showTimeWeather = prefs.getBool('show_time_weather') ?? true;
        _gridColumns = prefs.getInt('grid_columns') ?? 4;
        _showHiddenApps = prefs.getBool('show_hidden_apps') ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotificationDots(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_dots_enabled', value);
    setState(() {
      _notificationDotsEnabled = value;
    });

    if (value) {
      // Prompt user to enable notification listener permission
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Grant Notification Access'),
              content: const Text(
                'To display notification dots on app icons, Go Launcher 7 requires Notification Access. '
                'Please locate Go Launcher 7 in the next screen and turn on the permission.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    LauncherService.openNotificationSettings();
                  },
                  child: const Text('Grant'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _toggleTimeWeather(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_time_weather', value);
    setState(() => _showTimeWeather = value);
  }

  Future<void> _toggleShowHiddenApps(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_hidden_apps', value);
    setState(() => _showHiddenApps = value);
  }

  void _selectGridColumns() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Workspace Grid Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [3, 4, 5, 6].map((cols) => ListTile(
              title: Text('$cols Columns'),
              trailing: _gridColumns == cols ? const Icon(Icons.check) : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('grid_columns', cols);
                setState(() => _gridColumns = cols);
                if (mounted) Navigator.pop(context);
              },
            )).toList(),
          ),
        );
      },
    );
  }

  void _selectFeedProvider() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Feed Provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('MSN'),
                trailing: _feedProvider == 'msn' ? const Icon(Icons.check) : null,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('feed_provider', 'msn');
                  setState(() => _feedProvider = 'msn');
                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Yahoo'),
                trailing: _feedProvider == 'yahoo' ? const Icon(Icons.check) : null,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('feed_provider', 'yahoo');
                  setState(() => _feedProvider = 'yahoo');
                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Home Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Notification Dots'),
                  subtitle: const Text('Show a dot on app icons when there are unread notifications'),
                  value: _notificationDotsEnabled,
                  onChanged: _toggleNotificationDots,
                  secondary: const Icon(Icons.notification_important),
                ),
                SwitchListTile(
                  title: const Text('Show Time & Weather'),
                  subtitle: const Text('Display the time and weather widget on the home screen'),
                  value: _showTimeWeather,
                  onChanged: _toggleTimeWeather,
                  secondary: const Icon(Icons.access_time),
                ),
                ListTile(
                  title: const Text('Feed Provider'),
                  subtitle: Text(_feedProvider.toUpperCase()),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectFeedProvider,
                  leading: const Icon(Icons.article_outlined),
                ),
                ListTile(
                  title: const Text('Workspace Grid Size'),
                  subtitle: Text('$_gridColumns Columns'),
                  leading: const Icon(Icons.grid_on),
                  onTap: _selectGridColumns,
                ),
                SwitchListTile(
                  title: const Text('Show Hidden Apps'),
                  subtitle: const Text('View apps that you have hidden from the app drawer'),
                  secondary: const Icon(Icons.visibility),
                  value: _showHiddenApps,
                  onChanged: _toggleShowHiddenApps,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Go Launcher 7'),
                  subtitle: const Text('Version 1.0.0 (co.za.launcher3.swavoti)'),
                ),
              ],
            ),
    );
  }
}
