import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/home_screen.dart';
import 'package:swavoti/screens/app_drawer.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _drawerController;
  late Animation<double> _drawerAnimation;
  
  double _drawerHeight = 0.0;
  bool _isDrawerOpen = false;
  Map<String, int> _notifications = {};
  StreamSubscription<Map<String, int>>? _notificationSubscription;
  late WebViewController _webViewController;
  bool _isNewsLoading = true;

  @override
  void initState() {
    super.initState();
    // Default to index 1 (HomeScreen). Index 0 is News page.
    _pageController = PageController(initialPage: 1);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _isNewsLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isNewsLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isNewsLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.msn.com/en-za'));
    
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _drawerAnimation = CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Listen to notification dots — guarded so a missing/denied
    // NotificationListenerService permission does NOT crash the app.
    try {
      _notificationSubscription = LauncherService.notificationsStream.listen(
        (data) {
          if (mounted) {
            setState(() {
              _notifications = data;
            });
          }
        },
        onError: (e) {
          // Permission not granted or service unavailable — silently ignore.
        },
        cancelOnError: false,
      );
    } catch (_) {
      // Stream setup failed (e.g. service not bound) — dots just won't show.
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _pageController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // If we wanted to trigger an external intent, we'd do it here.
    // Since we are using WebView at index 0, no action is needed.
  }

  void _openDrawer() {
    _drawerController.forward();
    setState(() {
      _isDrawerOpen = true;
    });
  }

  void _closeDrawer() {
    _drawerController.reverse();
    setState(() {
      _isDrawerOpen = false;
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isDrawerOpen) {
      _drawerController.value -= details.primaryDelta! / _drawerHeight;
    } else {
      // Swipe up to open drawer
      if (details.primaryDelta! < 0) {
        _drawerController.value -= details.primaryDelta! / _drawerHeight;
      }
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_drawerController.value > 0.4) {
      _openDrawer();
    } else {
      _closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    _drawerHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent, // Show device wallpaper
      body: Stack(
        children: [
          // Background PageView (Discover Placeholder & HomeScreen)
          GestureDetector(
            onVerticalDragUpdate: _handleVerticalDragUpdate,
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: _isDrawerOpen ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              children: [
                // MSN News page (silent background loading)
                Stack(
                  children: [
                    WebViewWidget(controller: _webViewController),
                    if (_isNewsLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
                // Home Screen page
                HomeScreen(
                  notifications: _notifications,
                  onOpenDrawer: _openDrawer,
                ),
              ],
            ),
          ),

          // Sliding App Drawer Overlay
          AnimatedBuilder(
            animation: _drawerAnimation,
            builder: (context, child) {
              final yOffset = _drawerHeight * (1.0 - _drawerAnimation.value);
              return Positioned(
                top: yOffset,
                left: 0,
                right: 0,
                bottom: -yOffset,
                child: child!,
              );
            },
            child: AppDrawer(
              notifications: _notifications,
              onClose: _closeDrawer,
            ),
          ),
        ],
      ),
    );
  }
}
