import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:swavoti/screens/home_screen.dart';
import 'package:swavoti/screens/app_drawer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Workspace extends StatefulWidget {
  final SharedPreferences prefs;
  const Workspace({super.key, required this.prefs});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  Map<String, int> _notifications = {};
  StreamSubscription<Map<String, int>>? _notificationSubscription;
  late WebViewController _webViewController;
  bool _isNewsLoading = true;
  bool _hasWebError = false;
  
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _drawerExtent = 0.0;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _isNewsLoading = progress < 100);
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

  Future<void> _loadFeedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('feed_provider') ?? 'msn';
    final url = provider == 'yahoo' ? 'https://www.yahoo.com' : 'https://www.msn.com';
    if (mounted) {
      _webViewController.loadRequest(Uri.parse(url));
    }
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

  Widget _buildDiscoverPage() {
    return Stack(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Show device wallpaper
      body: Stack(
        children: [
          // 1. Home Screen (Includes Discover Page natively)
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -10) {
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutExpo);
                }
              }
            },
            child: HomeScreen(
              key: _homeScreenKey,
              prefs: widget.prefs,
              notifications: _notifications,
              onSettingsChanged: _loadFeedProvider,
              discoverPage: _buildDiscoverPage(),
            ),
          ),

          // 2. Dynamic Blur (Based on drawer extent)
          if (_drawerExtent > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _drawerExtent * 15,
                    sigmaY: _drawerExtent * 15,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(_drawerExtent * 0.4),
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
