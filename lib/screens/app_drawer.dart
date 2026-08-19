import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/services/app_database_service.dart';

class AppDrawer extends StatefulWidget {
  final Map<String, int> notifications;
  final VoidCallback onClose;
  final void Function(Map<String, dynamic>)? onAddToHomeScreen;

  const AppDrawer({
    super.key,
    required this.notifications,
    required this.onClose,
    this.onAddToHomeScreen,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _WorkspaceItemData {
  final String packageName;
  final String label;
  final String type;

  _WorkspaceItemData({required this.packageName, required this.label, this.type = 'app'});

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'label': label,
        'type': type,
      };
}

class _AppDrawerState extends State<AppDrawer> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    // 1. Instantly load from local SQLite cache
    final cachedApps = await AppDatabaseService.getAllApps();
    if (cachedApps.isNotEmpty) {
      if (mounted) {
        setState(() {
          _apps = cachedApps;
          _filteredApps = cachedApps;
          _isLoading = false;
        });
      }
    }

    // 2. Silently sync in background to catch new installs/uninstalls
    final freshApps = await AppDatabaseService.syncAppsBackground();
    if (freshApps.isNotEmpty && mounted) {
      setState(() {
        _apps = freshApps;
        // Re-apply filter if user was searching
        final query = _searchController.text.toLowerCase();
        _filteredApps = _apps
            .where((app) => app.name.toLowerCase().contains(query))
            .toList();
        _isLoading = false;
      });
    } else if (cachedApps.isEmpty && mounted) {
      // Edge case: no apps in cache and sync returned empty
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _apps
          .where((app) => app.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _showAppOptions(AppInfo app) {
    final isSystemApp = app.isSystemApp ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (app.icon != null)
                      Image.memory(app.icon!, width: 40, height: 40)
                    else
                      const Icon(Icons.android, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_to_home_screen),
                title: const Text('Add to Home Screen'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddToHomeScreen?.call({
                    'type': 'app',
                    'packageName': app.packageName,
                    'label': app.name,
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Info'),
                onTap: () {
                  Navigator.pop(ctx);
                  LauncherService.openAppInfo(app.packageName);
                },
              ),
              if (!isSystemApp)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Uninstall', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    LauncherService.uninstallApp(app.packageName);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Column(
        children: [
          // Search box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Apps...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const SizedBox.shrink() // Show blank while loading apps
                : _filteredApps.isEmpty
                    ? const Center(child: Text('No apps found.'))
                    : NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          // Only close drawer when: at the very top AND dragging downward
                          if (_scrollController.position.pixels <= 0 &&
                              notification.scrollDelta != null &&
                              notification.scrollDelta! < -15) {
                            widget.onClose();
                            return true;
                          }
                          return false;
                        },
                        child: GridView.builder(
                        controller: _scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final notificationCount = widget.notifications[app.packageName] ?? 0;
                          return _AppDrawerItem(
                            app: app,
                            notificationCount: notificationCount,
                            onCloseDrawer: widget.onClose,
                            onShowOptions: () => _showAppOptions(app),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawerItem extends StatefulWidget {
  final AppInfo app;
  final int notificationCount;
  final VoidCallback onCloseDrawer;
  final VoidCallback onShowOptions;

  const _AppDrawerItem({
    required this.app,
    required this.notificationCount,
    required this.onCloseDrawer,
    required this.onShowOptions,
  });

  @override
  State<_AppDrawerItem> createState() => _AppDrawerItemState();
}

class _AppDrawerItemState extends State<_AppDrawerItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = widget.app;
    final icon = app.icon;
    final appItemData = _WorkspaceItemData(
      packageName: app.packageName,
      label: app.name,
    ).toMap();

    return LongPressDraggable<Map<String, dynamic>>(
      data: appItemData,
      onDragStarted: widget.onCloseDrawer,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Image.memory(icon, width: 56, height: 56)
              else
                const Icon(Icons.android, size: 56),
              const SizedBox(height: 4),
              Text(
                app.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Column(
          children: [
            if (icon != null)
              Image.memory(icon, width: 48, height: 48)
            else
              const Icon(Icons.android, size: 48),
            const SizedBox(height: 4),
            Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => LauncherService.startApp(app.packageName),
        onLongPress: widget.onShowOptions,
        child: Column(
          children: [
            Stack(
              children: [
                if (icon != null)
                  Image.memory(icon, width: 48, height: 48)
                else
                  const Icon(Icons.android, size: 48),
                if (widget.notificationCount > 0)
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
                        '${widget.notificationCount}',
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
