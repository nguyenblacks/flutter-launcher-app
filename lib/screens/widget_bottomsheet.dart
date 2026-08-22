import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swavoti/services/launcher_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class WidgetBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onWidgetSelected;

  const WidgetBottomSheet({super.key, required this.onWidgetSelected});

  @override
  State<WidgetBottomSheet> createState() => _WidgetBottomSheetState();
}

class _WidgetBottomSheetState extends State<WidgetBottomSheet> {
  // Map of packageName to list of widgets
  final Map<String, List<Map<String, dynamic>>> _groupedWidgets = {};
  bool _loadingDone = false;

  @override
  void initState() {
    super.initState();
    // Sheet opens instantly (no await before setState), then we stream items in
    _loadWidgetsIncremental();
  }

  Future<void> _loadWidgetsIncremental() async {
    final all = await LauncherService.getAllWidgets();
    if (!mounted) return;
    
    setState(() {
      for (final w in all) {
        final pkg = w['providerPackage'] as String? ?? 'Unknown';
        _groupedWidgets.putIfAbsent(pkg, () => []).add(w);
      }
      _loadingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Choose Widget', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _groupedWidgets.isEmpty && _loadingDone
                ? const Center(child: Text('No widgets found on this device.'))
                : ListView.builder(
                    itemCount: _groupedWidgets.length,
                    itemBuilder: (context, index) {
                      final pkg = _groupedWidgets.keys.elementAt(index);
                      final widgetsForApp = _groupedWidgets[pkg]!;
                      
                      // Try to get app name from the first widget's label, or just use package name
                      final firstLabel = widgetsForApp.first['label'] as String? ?? 'App';
                      final appName = firstLabel.split(' ').first; // Rough heuristic for app name if package name is ugly

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ExpansionTile(
                          leading: FutureBuilder<AppInfo?>(
                            future: InstalledApps.getAppInfo(pkg),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data?.icon != null) {
                                return Image.memory(snapshot.data!.icon!, width: 48, height: 48);
                              }
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.widgets, color: cs.onPrimaryContainer, size: 28),
                              );
                            },
                          ),
                          title: Text(
                            appName.isNotEmpty ? appName : pkg,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${widgetsForApp.length} widgets', style: const TextStyle(fontSize: 12)),
                          children: widgetsForApp.map((widgetData) {
                            final label = widgetData['label'] as String? ?? 'Widget';
                            final previewBytes = widgetData['preview'] as Uint8List?;

                            final dragData = {
                              'type': 'widget_preview',
                              'providerPackage': widgetData['providerPackage'],
                              'providerClass': widgetData['providerClass'],
                              'label': label,
                            };

                            final widgetCard = ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: previewBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        previewBytes,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.scaleDown,
                                      ),
                                    )
                                  : const Icon(Icons.crop_square, size: 32),
                              title: Text(label, style: const TextStyle(fontSize: 14)),
                              trailing: Icon(Icons.add_circle_outline, color: cs.primary, size: 20),
                              onTap: () => widget.onWidgetSelected(widgetData),
                            );

                            return LongPressDraggable<Map<String, dynamic>>(
                              data: dragData,
                              delay: const Duration(milliseconds: 150),
                              onDragStarted: () => Navigator.pop(context),
                              feedback: Material(
                                color: Colors.transparent,
                                child: Opacity(
                                  opacity: 0.85,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width - 64,
                                    child: Card(child: widgetCard),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.3, child: widgetCard),
                              child: widgetCard,
                            );
                          }).toList(),
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
