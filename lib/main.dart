import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:swavoti/screens/workspace.dart';
import 'package:flutter/services.dart';

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

  runApp(SwavotiApp(prefs: prefs));
}

class SwavotiApp extends StatelessWidget {
  final SharedPreferences prefs;
  const SwavotiApp({super.key, required this.prefs});

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
          title: 'Swavoti Launcher',
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
          home: Workspace(prefs: prefs),
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
