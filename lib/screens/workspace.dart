import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/home_screen.dart';
import 'package:swavoti/screens/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Workspace extends StatefulWidget {
  final SharedPreferences prefs;
  final Map<String, AppInfo> appCache;
  const Workspace({super.key, required this.prefs, required this.appCache});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  Map<String, int> _notifications = {};
  StreamSubscription<Map<String, int>>? _notificationSubscription;

  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _drawerExtent = 0.0;

  @override
  void initState() {
    super.initState();

    try {
      _notificationSubscription = LauncherService.notificationsStream.listen(
        (data) {
          if (mounted) setState(() => _notifications = data);
        },
        onError: (e) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  void _closeDrawer() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Home Screen
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -10) {
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutExpo,
                  );
                }
              }
            },
            child: HomeScreen(
              key: _homeScreenKey,
              prefs: widget.prefs,
              appCache: widget.appCache,
              notifications: _notifications,
              onSettingsChanged: () {},
            ),
          ),

          // 2. Dynamic Blur (based on drawer extent)
          if (_drawerExtent > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _drawerExtent * 15,
                    sigmaY: _drawerExtent * 15,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: _drawerExtent * 0.4),
                  ),
                ),
              ),
            ),

          // 3. App Drawer as DraggableScrollableSheet
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              setState(() {
                _drawerExtent = notification.extent;
              });
              return true;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.0,
              minChildSize: 0.0,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.0, 1.0],
              builder: (context, scrollController) {
                return AppDrawer(
                  notifications: _notifications,
                  onClose: _closeDrawer,
                  scrollController: scrollController,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
