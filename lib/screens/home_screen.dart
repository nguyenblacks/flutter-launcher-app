import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/widget_bottomsheet.dart';
import 'package:swavoti/screens/home_settings.dart';

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
  int _searchWidgetId = -1;
  bool _isGoogleSearchBound = false;

  // Grid Configuration
  final int _columns = 4;
  final int _rows = 5;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _setupGoogleSearchWidget();
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

  Future<void> _setupGoogleSearchWidget() async {
    final prefs = await SharedPreferences.getInstance();
    _searchWidgetId = prefs.getInt('google_search_widget_id') ?? -1;

    if (_searchWidgetId == -1) {
      // Find the Google Search widget provider
      final widgets = await LauncherService.getAllWidgets();
      Map<String, dynamic>? googleSearchProvider;

      for (var widget in widgets) {
        final pkg = widget['providerPackage'] as String;
        final cls = widget['providerClass'] as String;
        if (pkg.contains('googlequicksearchbox') &&
            (cls.contains('SearchWidget') || cls.contains('search'))) {
          googleSearchProvider = widget;
          break;
        }
      }

      if (googleSearchProvider != null) {
        final id = await LauncherService.allocateWidgetId();
        if (id != -1) {
          final success = await LauncherService.bindWidget(
            id,
            googleSearchProvider['providerPackage'],
            googleSearchProvider['providerClass'],
          );
          if (success) {
            _searchWidgetId = id;
            await prefs.setInt('google_search_widget_id', id);
            setState(() {
              _isGoogleSearchBound = true;
            });
          }
        }
      }
    } else {
      setState(() {
        _isGoogleSearchBound = true;
      });
    }
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
            // Google Search Widget Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: _isGoogleSearchBound && _searchWidgetId != -1
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: AndroidView(
                          viewType: 'widget_view',
                          creationParams: {'appWidgetId': _searchWidgetId},
                          creationParamsCodec: const StandardMessageCodec(),
                        ),
                      )
                    : InkWell(
                        onTap: () => LauncherService.openGoogleDiscover(),
                        borderRadius: BorderRadius.circular(28),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png',
                              height: 24,
                              errorBuilder: (_, __, ___) => const Icon(Icons.search, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Search...',
                              style: TextStyle(color: Colors.white60, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
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

            // Swipe Up Indicator / Dock area
            GestureDetector(
              onTap: widget.onOpenDrawer,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                width: double.infinity,
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Swipe up for Apps',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
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
      return FutureBuilder<Application?>(
        future: DeviceApps.getApp(item.packageName, true),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final app = snapshot.data as ApplicationWithIcon;
          final notificationCount = widget.notifications[item.packageName] ?? 0;

          return Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Image.memory(
                      app.icon,
                      width: 48,
                      height: 48,
                    ),
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
                  app.appName,
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
