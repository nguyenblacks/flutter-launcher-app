import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/services/app_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatefulWidget {
  final Map<String, int> notifications;
  final VoidCallback onClose;
  final void Function(Map<String, dynamic>)? onAddToHomeScreen;
  final ScrollController scrollController;

  const AppDrawer({
    super.key,
    required this.notifications,
    required this.onClose,
    this.onAddToHomeScreen,
    required this.scrollController,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _WorkspaceItemData {
  final String packageName;
  final String label;
  final String type;

  _WorkspaceItemData({
    required this.packageName,
    required this.label,
    this.type = 'app',
  });

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

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList('hidden_apps') ?? [];
    final showHidden = prefs.getBool('show_hidden_apps') ?? false;

    List<AppInfo> filterApps(List<AppInfo> apps) {
      if (showHidden) return apps;
      return apps.where((a) => !hidden.contains(a.packageName)).toList();
    }

    final cachedApps = filterApps(await AppDatabaseService.getAllApps());
    if (cachedApps.isNotEmpty) {
      if (mounted) {
        setState(() {
          _apps = cachedApps;
          _filteredApps = cachedApps;
          _isLoading = false;
        });
      }
    }

    final freshApps = filterApps(await AppDatabaseService.syncAppsBackground());
    if (freshApps.isNotEmpty && mounted) {
      setState(() {
        _apps = freshApps;
        final query = _searchController.text.toLowerCase();
        _filteredApps = _apps
            .where((app) => app.name.toLowerCase().contains(query))
            .toList();
        _isLoading = false;
      });
    } else if (cachedApps.isEmpty && mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Pull handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_searchController.text.isEmpty &&
                    _filteredApps.length >= 4) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _filteredApps.take(4).map((app) {
                        final notificationCount =
                            widget.notifications[app.packageName] ?? 0;
                        return Expanded(
                          child: _AppDrawerItem(
                            app: app,
                            notificationCount: notificationCount,
                            onCloseDrawer: widget.onClose,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (_filteredApps.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No apps found.')),
              ),
            )
          else
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final app = _filteredApps[index];
                final notificationCount =
                    widget.notifications[app.packageName] ?? 0;
                return _AppDrawerItem(
                  app: app,
                  notificationCount: notificationCount,
                  onCloseDrawer: widget.onClose,
                );
              }, childCount: _filteredApps.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _AppDrawerItem extends StatefulWidget {
  final AppInfo app;
  final int notificationCount;
  final VoidCallback onCloseDrawer;

  const _AppDrawerItem({
    required this.app,
    required this.notificationCount,
    required this.onCloseDrawer,
  });

  @override
  State<_AppDrawerItem> createState() => _AppDrawerItemState();
}

class _AppDrawerItemState extends State<_AppDrawerItem>
    with AutomaticKeepAliveClientMixin {
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
      delay: const Duration(milliseconds: 150),
      onDragStarted: widget.onCloseDrawer, // Closes drawer when dragged!
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
        // Removed onLongPress so LongPressDraggable can work natively without conflict
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
