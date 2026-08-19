import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/home_screen.dart';
import 'package:swavoti/screens/app_drawer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _currentPage = 1;
  Map<String, int> _notifications = {};
  StreamSubscription<Map<String, int>>? _notificationSubscription;
  late WebViewController _webViewController;
  bool _isNewsLoading = true;
  bool _hasWebError = false;

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
            if (mounted) setState(() { 
              _isNewsLoading = true; 
              _hasWebError = false; 
            });
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isNewsLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() {
              _isNewsLoading = false;
              _hasWebError = true;
            });
          },
        ),
      );
    
    _loadFeedProvider();
    
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _drawerAnimation = CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInCubic,
    );
    _drawerController.addStatusListener((status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.completed) {
        if (!_isDrawerOpen && mounted) setState(() => _isDrawerOpen = true);
      } else if (status == AnimationStatus.reverse ||
          status == AnimationStatus.dismissed) {
        if (_isDrawerOpen && mounted) setState(() => _isDrawerOpen = false);
      }
    });

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

  Future<void> _loadFeedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('feed_provider') ?? 'msn';
    final url = provider == 'yahoo' ? 'https://www.yahoo.com' : 'https://www.msn.com';
    if (mounted) {
      _webViewController.loadRequest(Uri.parse(url));
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _openDrawer() {
    setState(() => _isDrawerOpen = true);
    _drawerController.animateTo(1.0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutExpo);
  }

  void _closeDrawer() {
    _drawerController.animateTo(0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInCubic).then((_) {
      if (mounted) setState(() => _isDrawerOpen = false);
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    // Only handle upward drag to open, downward to close
    final delta = -(details.primaryDelta! / _drawerHeight);
    _drawerController.value = (_drawerController.value + delta).clamp(0.0, 1.0);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Use physics-based fling like AOSP Launcher3
    if (velocity < -500 || (_drawerController.value > 0.3 && velocity <= 0)) {
      // Fast upward fling or past threshold -> open
      _drawerController.fling(velocity: 2.0);
      setState(() => _isDrawerOpen = true);
    } else if (velocity > 500 || (_drawerController.value < 0.7 && velocity >= 0)) {
      // Fast downward fling or below threshold -> close
      _drawerController.fling(velocity: -2.0).then((_) {
        if (mounted) setState(() => _isDrawerOpen = false);
      });
    } else {
      // Snap based on position
      if (_drawerController.value > 0.5) {
        _openDrawer();
      } else {
        _closeDrawer();
      }
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
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: _isDrawerOpen ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            children: [
              // MSN News page (silent background loading or error)
              Stack(
                children: [
                  if (_hasWebError)
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            const Text('No Internet Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => _hasWebError = false);
                                _webViewController.reload();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    WebViewWidget(controller: _webViewController),
                  if (_isNewsLoading && !_hasWebError)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
              // Home Screen page — wrap in GestureDetector only here
              GestureDetector(
                onVerticalDragUpdate: _handleVerticalDragUpdate,
                onVerticalDragEnd: _handleVerticalDragEnd,
                child: HomeScreen(
                  notifications: _notifications,
                  onOpenDrawer: _openDrawer,
                  onSettingsChanged: _loadFeedProvider,
                  onAddAppToHomeScreen: (data) {
                    // HomeScreen handles this directly, just a pass-through
                  },
                ),
              ),
            ],
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
              onAddToHomeScreen: (data) {
                // Close drawer, HomeScreen listens for drops
                _closeDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }
}
