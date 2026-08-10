import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/widget_bottomsheet.dart';
import 'package:swavoti/screens/home_settings.dart';
import 'package:swavoti/services/weather_service.dart';
import 'package:swavoti/widgets/weather_icon.dart';
import 'package:swavoti/screens/workspace.dart';
import 'dart:async';

class LauncherItem {
  final String id;
  final String type; // 'app' or 'widget'
  final String packageName;
  final String? className; // for widgets
  final int? appWidgetId;
  int x;
  int y;
  int spanX;
  int spanY;
  final String label;

  LauncherItem({
    required this.id,
    required this.type,
    required this.packageName,
    this.className,
    this.appWidgetId,
    required this.x,
    required this.y,
    this.spanX = 1,
    this.spanY = 1,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'packageName': packageName,
        'className': className,
        'appWidgetId': appWidgetId,
        'x': x,
        'y': y,
        'spanX': spanX,
        'spanY': spanY,
        'label': label,
      };

  factory LauncherItem.fromJson(Map<String, dynamic> json) => LauncherItem(
        id: json['id'],
        type: json['type'],
        packageName: json['packageName'],
        className: json['className'],
        appWidgetId: json['appWidgetId'],
        x: json['x'],
        y: json['y'],
        spanX: json['spanX'] ?? 1,
        spanY: json['spanY'] ?? 1,
        label: json['label'] ?? '',
      );
}

class HomeScreen extends StatefulWidget {
  final Map<String, int> notifications;
  final VoidCallback onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.notifications,
    required this.onOpenDrawer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LauncherItem> _items = [];
  List<AppInfo> _dockApps = [];
  WeatherData? _weatherData;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Grid Configuration
  final int _columns = 4;
  final int _rows = 5;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadWeather();
    _loadDockApps();
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

  Future<void> _loadDockApps() async {
    // Wait a bit for globalAppCache to populate
    while (globalAppCache == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || globalAppCache == null) return;
    
    // Pick first 4 apps for the dock (or specific ones if available)
    final apps = globalAppCache!;
    final dockApps = <AppInfo>[];
    
    // Try to find common apps
    final commonPackages = ['com.google.android.dialer', 'com.android.phone', 'com.google.android.apps.messaging', 'com.android.chrome', 'com.google.android.camera'];
    for (var pkg in commonPackages) {
      try {
        final app = apps.firstWhere((a) => a.packageName == pkg);
        if (dockApps.length < 4) dockApps.add(app);
      } catch (_) {}
    }
    
    // Fill the rest with whatever is available
    for (var app in apps) {
      if (dockApps.length >= 4) break;
      if (!dockApps.any((d) => d.packageName == app.packageName)) dockApps.add(app);
    }
    
    setState(() {
      _dockApps = dockApps;
    });
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('launcher_items') ?? [];
    setState(() {
      _items = data.map((item) => LauncherItem.fromJson(jsonDecode(item))).toList();
    });
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('launcher_items', data);
  }



  void _showWorkspaceMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMenuButton(
                    icon: Icons.wallpaper,
                    label: 'Wallpaper',
                    onTap: () {
                      Navigator.pop(context);
                      LauncherService.changeWallpaper();
                    },
                  ),
                  _buildMenuButton(
                    icon: Icons.widgets,
                    label: 'Widgets',
                    onTap: () {
                      Navigator.pop(context);
                      _openWidgetsSheet();
                    },
                  ),
                  _buildMenuButton(
                    icon: Icons.settings,
                    label: 'Home Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeSettings()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openWidgetsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WidgetBottomSheet(
        onWidgetSelected: (widgetData) async {
          Navigator.pop(context);
          final id = await LauncherService.allocateWidgetId();
          if (id != -1) {
            final success = await LauncherService.bindWidget(
              id,
              widgetData['providerPackage'],
              widgetData['providerClass'],
            );
            if (success) {
              // Add to workspace at first available slot
              _addNewItem(LauncherItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: 'widget',
                packageName: widgetData['providerPackage'],
                className: widgetData['providerClass'],
                appWidgetId: id,
                x: 0,
                y: 2,
                spanX: 4,
                spanY: 2,
                label: widgetData['label'],
              ));
            }
          }
        },
      ),
    );
  }

  void _addNewItem(LauncherItem item) {
    setState(() {
      _items.add(item);
    });
    _saveItems();
  }

  void _removeItem(LauncherItem item) {
    if (item.appWidgetId != null) {
      LauncherService.deleteWidgetId(item.appWidgetId!);
    }
    setState(() {
      _items.remove(item);
    });
    _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onLongPress: _showWorkspaceMenu,
      child: Container(
        color: Colors.transparent, // Capture taps across screen
        child: Column(
          children: [
            SizedBox(height: statusBarHeight + 16),
            // Time & Weather Widget Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentTime.hour}:${_currentTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          shadows: [Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(2, 2))],
                        ),
                      ),
                      Text(
                        '${_currentTime.day}/${_currentTime.month}/${_currentTime.year}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          shadows: const [Shadow(blurRadius: 5.0, color: Colors.black54)],
                        ),
                      ),
                    ],
                  ),
                  if (_weatherData != null)
                    Row(
                      children: [
                        Text(
                          '${_weatherData!.temperature.round()}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w400,
                            shadows: [Shadow(blurRadius: 8.0, color: Colors.black54, offset: Offset(2, 2))],
                          ),
                        ),
                        const SizedBox(width: 8),
                        WeatherIcon(weatherCode: _weatherData!.weatherCode, size: 56),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Workspace Grid (Apps & Widgets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / _columns;
                    final cellHeight = constraints.maxHeight / _rows;

                    return Stack(
                      children: [
                        // Grid lines or drag targets
                        for (int y = 0; y < _rows; y++)
                          for (int x = 0; x < _columns; x++)
                            Positioned(
                              left: x * cellWidth,
                              top: y * cellHeight,
                              width: cellWidth,
                              height: cellHeight,
                              child: DragTarget<Map<String, dynamic>>(
                                onWillAccept: (data) => true,
                                onAccept: (data) {
                                  if (data['type'] == 'app') {
                                    _addNewItem(LauncherItem(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      type: 'app',
                                      packageName: data['packageName'],
                                      label: data['label'],
                                      x: x,
                                      y: y,
                                    ));
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  return Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: candidateData.isNotEmpty
                                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  );
                                },
                              ),
                            ),

                        // Placed Items
                        ..._items.map((item) {
                          return Positioned(
                            left: item.x * cellWidth,
                            top: item.y * cellHeight,
                            width: item.spanX * cellWidth,
                            height: item.spanY * cellHeight,
                            child: LongPressDraggable<LauncherItem>(
                              data: item,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Opacity(
                                  opacity: 0.7,
                                  child: _buildItemContent(item, cellWidth, cellHeight),
                                ),
                              ),
                              childWhenDragging: const SizedBox.shrink(),
                              onDragEnd: (details) {
                                // Simple repositioning logic on drop
                                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                final localOffset = renderBox.globalToLocal(details.offset);
                                final newX = (localOffset.dx / cellWidth).round().clamp(0, _columns - item.spanX);
                                final newY = (localOffset.dy / cellHeight).round().clamp(0, _rows - item.spanY);
                                setState(() {
                                  item.x = newX;
                                  item.y = newY;
                                });
                                _saveItems();
                              },
                              child: GestureDetector(
                                onLongPress: () => _showItemContextMenu(item),
                                child: _buildItemContent(item, cellWidth, cellHeight),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),

            // App Dock
            GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! < -5) {
                   widget.onOpenDrawer();
                }
              },
              onTap: widget.onOpenDrawer,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _dockApps.isEmpty 
                    ? [const CircularProgressIndicator(color: Colors.white)]
                    : _dockApps.map((app) {
                    return GestureDetector(
                      onTap: () => LauncherService.startApp(app.packageName),
                      child: app.icon != null
                          ? Image.memory(app.icon!, width: 56, height: 56)
                          : const Icon(Icons.android, size: 56, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildItemContent(LauncherItem item, double cellWidth, double cellHeight) {
    if (item.type == 'widget' && item.appWidgetId != null) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AndroidView(
            viewType: 'widget_view',
            creationParams: {'appWidgetId': item.appWidgetId},
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      );
    } else {
      // App icon
      return FutureBuilder<AppInfo?>(
        future: InstalledApps.getAppInfo(item.packageName),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final app = snapshot.data!;
          final notificationCount = widget.notifications[item.packageName] ?? 0;

          return Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    if (app.icon != null)
                      Image.memory(
                        app.icon!,
                        width: 48,
                        height: 48,
                      )
                    else
                      const Icon(Icons.android, size: 48),
                    if (notificationCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black54,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showItemContextMenu(LauncherItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.label.isNotEmpty ? item.label : 'Item Actions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Info'),
                onTap: () {
                  Navigator.pop(context);
                  LauncherService.openAppInfo(item.packageName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove from Home', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeItem(item);
                },
              ),
              if (item.type == 'app')
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Uninstall App', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    LauncherService.uninstallApp(item.packageName);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
