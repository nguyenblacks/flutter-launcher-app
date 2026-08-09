import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:swavoti/services/launcher_service.dart';

class AppDrawer extends StatefulWidget {
  final Map<String, int> notifications;
  final VoidCallback onClose;

  const AppDrawer({
    super.key,
    required this.notifications,
    required this.onClose,
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
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    // Sort apps alphabetically
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _apps = apps;
        _filteredApps = apps;
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(app.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Info'),
                onTap: () {
                  Navigator.pop(context);
                  LauncherService.openAppInfo(app.packageName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Uninstall', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  LauncherService.uninstallApp(app.packageName);
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Drawer handle
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? const Center(child: Text('No apps found.'))
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
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
                          final icon = app.icon;

                          final appItemData = _WorkspaceItemData(
                            packageName: app.packageName,
                            label: app.name,
                          ).toMap();

                          return LongPressDraggable<Map<String, dynamic>>(
                            data: appItemData,
                            onDragStarted: () {
                              // Instantly close drawer when drag starts so user sees the homescreen targets
                              widget.onClose();
                            },
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
                              onTap: () => InstalledApps.startApp(app.packageName),
                              onLongPress: () => _showAppOptions(app),
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      if (icon != null)
                                        Image.memory(icon, width: 48, height: 48)
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
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
