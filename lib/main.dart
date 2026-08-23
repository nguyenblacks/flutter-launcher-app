import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:swavoti/screens/workspace.dart';
import 'package:swavoti/services/app_database_service.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Make status bar and navigation bar transparent for edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();

  // Pre-warm icon cache from SQLite so icons show on first frame (no jank on unlock)
  final List<AppInfo> cachedApps = await AppDatabaseService.getAllApps();
  final Map<String, AppInfo> appCache = {
    for (final app in cachedApps) app.packageName: app
  };

  // Sync fresh apps in background (won't block startup)
  AppDatabaseService.syncAppsBackground();

  runApp(SwavotiApp(prefs: prefs, appCache: appCache));
}

class SwavotiApp extends StatelessWidget {
  final SharedPreferences prefs;
  final Map<String, AppInfo> appCache;
  const SwavotiApp({super.key, required this.prefs, required this.appCache});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Fallback to default colors
          lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Go Launcher 7',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: Colors.transparent,
            useMaterial3: true,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadePageTransitionsBuilder(),
                TargetPlatform.iOS: FadePageTransitionsBuilder(),
              },
            ),
          ),
          themeMode: ThemeMode.system,
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: Colors.transparent,
            useMaterial3: true,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadePageTransitionsBuilder(),
                TargetPlatform.iOS: FadePageTransitionsBuilder(),
              },
            ),
          ),
          home: PopScope(
            canPop: false,
            child: Workspace(prefs: prefs, appCache: appCache),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
