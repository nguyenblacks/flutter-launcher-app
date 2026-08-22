import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/widget_bottomsheet.dart';
import 'package:swavoti/screens/home_settings.dart';
import 'package:swavoti/screens/wallpaper_page.dart';
import 'package:swavoti/widgets/time_weather_widget.dart';
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
  int page;
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
    this.page = 0,
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
        'page': page,
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
        page: json['page'] ?? 0,
        label: json['label'] ?? '',
      );
}

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final Map<String, int> notifications;
  final VoidCallback onSettingsChanged;
  final Widget discoverPage;
  final void Function(Map<String, dynamic>)? onAddAppToHomeScreen;

  const HomeScreen({
    super.key,
    required this.prefs,
    required this.notifications,
    required this.onSettingsChanged,
    required this.discoverPage,
    this.onAddAppToHomeScreen,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<LauncherItem> _items = [];
  final Map<String, AppInfo> _appCache = {};
  bool _showTimeWeather = true;
  bool _isDragging = false; // tracks active drag for remove zone

  // Grid Configuration
  final int _columns = 4;
  final int _rows = 5;
  int _currentWorkspacePage = 1;
  final PageController _workspaceController = PageController(initialPage: 1);

  int get _totalPages {
    if (_items.isEmpty) return 2;
    int maxPage = _items.fold<int>(0, (max, item) => item.page > max ? item.page : max);
    return maxPage + 2; 
  }

  @override
  void initState() {
    super.initState();
    LauncherService.preloadWidgets();
    _loadItemsSync();
    _loadSettingsSync();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  void _loadSettingsSync() {
    _showTimeWeather = widget.prefs.getBool('show_time_weather') ?? true;
  }

  void _loadItemsSync() {
    final data = widget.prefs.getStringList('launcher_items') ?? [];
    final loadedItems = data.map((item) => LauncherItem.fromJson(jsonDecode(item))).toList();
    
    if (!loadedItems.any((i) => i.page == -1)) {
       final common = ['com.google.android.dialer', 'com.google.android.apps.messaging', 'com.android.chrome', 'com.google.android.camera'];
       for (int i = 0; i < 4; i++) {
         loadedItems.add(LauncherItem(id: 'dock_$i', type: 'app', packageName: common[i], label: 'App', x: i, y: 0, page: -1));
       }
    }
    _items = loadedItems;
  }

  Future<AppInfo?> _getAppInfo(String packageName) async {
    if (_appCache.containsKey(packageName)) return _appCache[packageName];
    final info = await InstalledApps.getAppInfo(packageName);
    if (info != null && mounted) setState(() => _appCache[packageName] = info);
    return info;
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WallpaperPage()),
                      );
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
                      ).then((_) {
                        widget.onSettingsChanged();
                        setState(() {
                          _loadSettingsSync();
                        });
                      });
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
              addWidgetToWorkspace(widgetData, id);
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

  void addAppToWorkspace(String packageName, String label) {
    // Find the first empty 1x1 slot on the current page
    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _columns; x++) {
        // Check if any item occupies (x, y) on _currentWorkspacePage
        final isOccupied = _items.any((item) =>
            item.page == _currentWorkspacePage &&
            x >= item.x && x < item.x + item.spanX &&
            y >= item.y && y < item.y + item.spanY);

        if (!isOccupied) {
          _addNewItem(LauncherItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'app',
            packageName: packageName,
            label: label,
            x: x,
            y: y,
            page: _currentWorkspacePage,
          ));
          return;
        }
      }
    }
    // If no space, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No space left on this workspace page!')),
    );
  }

  void addWidgetToWorkspace(Map<String, dynamic> widgetData, int widgetId) {
    // Try to find a 4x2 space on the current page
    final spanX = 4;
    final spanY = 2;
    
    for (int y = 0; y <= _rows - spanY; y++) {
      for (int x = 0; x <= _columns - spanX; x++) {
        // Check if any item occupies any cell in this span
        bool isOccupied = false;
        for (final item in _items) {
          if (item.page == _currentWorkspacePage) {
            // Check overlap
            if (x < item.x + item.spanX && x + spanX > item.x &&
                y < item.y + item.spanY && y + spanY > item.y) {
              isOccupied = true;
              break;
            }
          }
        }

        if (!isOccupied) {
          _addNewItem(LauncherItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'widget',
            packageName: widgetData['providerPackage'],
            className: widgetData['providerClass'],
            appWidgetId: widgetId,
            x: x,
            y: y,
            spanX: spanX,
            spanY: spanY,
            page: _currentWorkspacePage,
            label: widgetData['label'],
          ));
          return;
        }
      }
    }
    
    // If no space, we can't place it. Should probably delete the widget ID to prevent leaks.
    LauncherService.deleteWidgetId(widgetId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not enough space for this widget (requires 4x2). Try a blank page!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onLongPress: _showWorkspaceMenu, // open workspace menu for wallpapers, widgets, settings
      child: Container(
        color: Colors.transparent, // Capture taps across screen
        child: Column(
          children: [
            SizedBox(height: statusBarHeight + 16),
            // Time & Weather Widget Area
            if (_showTimeWeather)
              TimeWeatherWidget(
                onRemove: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_time_weather', false);
                  setState(() => _showTimeWeather = false);
                },
              ),

            // Workspace Grid (Apps & Widgets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / _columns;
                    final cellHeight = constraints.maxHeight / _rows;

                    return PageView.builder(
                      physics: const BouncingScrollPhysics(),
                      controller: _workspaceController,
                      itemCount: _totalPages + 1, // Discover + Workspaces
                      onPageChanged: (index) => setState(() => _currentWorkspacePage = index),
                      itemBuilder: (context, index) {
                        if (index == 0) return widget.discoverPage;
                        
                        final pageIndex = index - 1;
                        final pageItems = _items.where((i) => i.page == pageIndex).toList();

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
                                    onWillAcceptWithDetails: (details) => true,
                                    onAcceptWithDetails: (details) {
                                      final data = details.data;
                                      final spanX = data['spanX'] as int? ?? 1;
                                      final spanY = data['spanY'] as int? ?? 1;
                                      final targetX = x.clamp(0, _columns - spanX);
                                      final targetY = y.clamp(0, _rows - spanY);

                                      if (data['id'] != null) {
                                        // Move existing item
                                        final itemId = data['id'] as String;
                                        setState(() {
                                          final item = _items.firstWhere((i) => i.id == itemId);
                                          item.x = targetX;
                                          item.y = targetY;
                                          item.page = pageIndex;
                                        });
                                        _saveItems();
                                      } else if (data['type'] == 'app') {
                                        // Add new app
                                        _addNewItem(LauncherItem(
                                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                                          type: 'app',
                                          packageName: data['packageName'],
                                          label: data['label'],
                                          x: targetX,
                                          y: targetY,
                                          page: pageIndex,
                                        ));
                                      } else if (data['type'] == 'widget_preview') {
                                        LauncherService.allocateWidgetId().then((id) {
                                          if (id != -1) {
                                            LauncherService.bindWidget(
                                              id,
                                              data['providerPackage'],
                                              data['providerClass'],
                                            ).then((success) {
                                              if (success) {
                                                _addNewItem(LauncherItem(
                                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                  type: 'widget',
                                                  packageName: data['providerPackage'],
                                                  className: data['providerClass'],
                                                  appWidgetId: id,
                                                  x: targetX,
                                                  y: targetY,
                                                  spanX: 4,
                                                  spanY: 2,
                                                  page: pageIndex,
                                                  label: data['label'],
                                                ));
                                              }
                                            });
                                          }
                                        });
                                      }
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: candidateData.isNotEmpty
                                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                            // Placed Items on this page
                            ...pageItems.map((item) {
                              return Positioned(
                                left: item.x * cellWidth,
                                top: item.y * cellHeight,
                                width: item.spanX * cellWidth,
                                height: item.spanY * cellHeight,
                                child: LongPressDraggable<Map<String, dynamic>>(
                                  data: item.toJson(),
                                  delay: const Duration(milliseconds: 150),
                                  onDragStarted: () => setState(() => _isDragging = true),
                                  onDragEnd: (_) => setState(() => _isDragging = false),
                                  onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Opacity(
                                      opacity: 0.7,
                                      child: _buildItemContent(item, cellWidth, cellHeight),
                                    ),
                                  ),
                                  childWhenDragging: const SizedBox.shrink(),
                                  child: GestureDetector(
                                    onLongPress: () => _showItemContextMenu(item),
                                    child: _buildItemContent(item, cellWidth, cellHeight),
                                  ),
                                ),
                              );
                            }),

                            // Edge drag to previous page
                            if (_isDragging && pageIndex > 0)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 24,
                                child: DragTarget<Map<String, dynamic>>(
                                  onWillAcceptWithDetails: (_) {
                                    _workspaceController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                    return false;
                                  },
                                  builder: (context, candidateData, _) {
                                    return Container(color: candidateData.isNotEmpty ? Colors.white.withOpacity(0.2) : Colors.transparent);
                                  },
                                ),
                              ),

                            // Edge drag to next page
                            if (_isDragging && pageIndex < _totalPages - 1)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: 24,
                                child: DragTarget<Map<String, dynamic>>(
                                  onWillAcceptWithDetails: (_) {
                                    _workspaceController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                    return false;
                                  },
                                  builder: (context, candidateData, _) {
                                    return Container(color: candidateData.isNotEmpty ? Colors.white.withOpacity(0.2) : Colors.transparent);
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Workspace Page Indicator (At bottom)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentWorkspacePage == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Persistent Remove Zone — only visible while dragging
            if (_isDragging)
              DragTarget<Map<String, dynamic>>(
                onAcceptWithDetails: (details) {
                  final id = details.data['id'] as String?;
                  if (id != null) {
                    final item = _items.firstWhere((i) => i.id == id);
                    _removeItem(item);
                  }
                  setState(() => _isDragging = false);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHovered ? Colors.red.withOpacity(0.85) : Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: isHovered ? Colors.white : Colors.white70,
                      size: 32,
                    ),
                  );
                },
              ),

            // App Dock
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 4;
                  final dockItems = _items.where((i) => i.page == -1).toList();
                  
                  return Stack(
                    children: [
                      // Drop targets for the 4 dock slots
                      for (int x = 0; x < 4; x++)
                        Positioned(
                          left: x * cellWidth,
                          top: 0,
                          width: cellWidth,
                          height: 90,
                          child: DragTarget<Map<String, dynamic>>(
                            onWillAcceptWithDetails: (details) => true,
                            onAcceptWithDetails: (details) {
                              final data = details.data;
                              if (data['id'] != null) {
                                setState(() {
                                  final item = _items.firstWhere((i) => i.id == data['id']);
                                  item.x = x;
                                  item.y = 0;
                                  item.page = -1;
                                });
                                _saveItems();
                              } else if (data['type'] == 'app') {
                                _addNewItem(LauncherItem(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  type: 'app',
                                  packageName: data['packageName'],
                                  label: data['label'],
                                  x: x,
                                  y: 0,
                                  page: -1,
                                ));
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Dock Items
                      ...dockItems.map((item) {
                        return Positioned(
                          left: item.x * cellWidth,
                          top: 0,
                          width: cellWidth,
                          height: 90,
                          child: LongPressDraggable<Map<String, dynamic>>(
                            data: item.toJson(),
                            delay: const Duration(milliseconds: 150),
                            onDragStarted: () => setState(() => _isDragging = true),
                            onDragEnd: (_) => setState(() => _isDragging = false),
                            onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(opacity: 0.7, child: _buildItemContent(item, cellWidth, 90)),
                            ),
                            childWhenDragging: const SizedBox.shrink(),
                            child: GestureDetector(
                              onTap: () => LauncherService.startApp(item.packageName),
                              onLongPress: () => _showItemContextMenu(item),
                              child: _buildItemContent(item, cellWidth, 90),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
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
        future: _getAppInfo(item.packageName),
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
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    item.label.isNotEmpty ? item.label : 'Item Actions',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove from Home'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeItem(item);
                  },
                ),
                if (item.type == 'app') ...[
                  ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: const Text('Share App'),
                    onTap: () {
                      Navigator.pop(context);
                      LauncherService.shareApp(item.packageName);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App Info'),
                    onTap: () {
                      Navigator.pop(context);
                      LauncherService.openAppInfo(item.packageName);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Uninstall', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      LauncherService.uninstallApp(item.packageName);
                    },
                  ),
                ],
                if (item.type == 'widget') ...[
                  ListTile(
                    leading: const Icon(Icons.aspect_ratio),
                    title: const Text('Resize Widget'),
                    onTap: () {
                      Navigator.pop(context);
                      _showResizeDialog(item);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResizeDialog(LauncherItem item) {
    int currentSpanX = item.spanX;
    int currentSpanY = item.spanY;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Resize Widget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Width:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: currentSpanX > 1
                                ? () => setDialogState(() => currentSpanX--)
                                : null,
                          ),
                          Text('$currentSpanX'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (item.x + currentSpanX) < _columns
                                ? () => setDialogState(() => currentSpanX++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Height:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: currentSpanY > 1
                                ? () => setDialogState(() => currentSpanY--)
                                : null,
                          ),
                          Text('$currentSpanY'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (item.y + currentSpanY) < _rows
                                ? () => setDialogState(() => currentSpanY++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      item.spanX = currentSpanX;
                      item.spanY = currentSpanY;
                    });
                    _saveItems();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

