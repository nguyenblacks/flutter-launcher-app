import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:installed_apps/app_category.dart';

class AppDatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDb();
    return _database!;
  }

  static Future<Database> initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'apps_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE apps(
            packageName TEXT PRIMARY KEY,
            name TEXT,
            icon BLOB
          )
        ''');
      },
    );
  }

  /// Instantly get all apps from the local SQLite cache
  static Future<List<AppInfo>> getAllApps() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('apps');

    return List.generate(maps.length, (i) {
      return AppInfo(
        name: maps[i]['name'] as String,
        icon: maps[i]['icon'],
        packageName: maps[i]['packageName'] as String,
        versionName: "",
        versionCode: 0,
        platformType: PlatformType.nativeOrOthers,
        installedTimestamp: 0,
        isSystemApp: false,
        isLaunchableApp: true,
        category: AppCategory.undefined,
      );
    });
  }

  /// Scan system for apps in background and update the SQLite cache
  /// Returns the updated list of apps
  static Future<List<AppInfo>> syncAppsBackground() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final db = await database;
      final batch = db.batch();

      // Clear the table and insert the new list
      // We do this to handle uninstalled apps easily
      batch.delete('apps');
      for (final app in apps) {
        batch.insert('apps', {
          'packageName': app.packageName,
          'name': app.name,
          'icon': app.icon,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return apps;
    } catch (e) {
      print('Error syncing apps: $e');
      return [];
    }
  }
}
