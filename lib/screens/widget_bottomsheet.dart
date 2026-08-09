import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:swavoti/services/launcher_service.dart';

class WidgetBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onWidgetSelected;

  const WidgetBottomSheet({super.key, required this.onWidgetSelected});

  @override
  State<WidgetBottomSheet> createState() => _WidgetBottomSheetState();
}

class _WidgetBottomSheetState extends State<WidgetBottomSheet> {
  List<Map<String, dynamic>> _widgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWidgets();
  }

  Future<void> _loadWidgets() async {
    final widgets = await LauncherService.getAllWidgets();
    if (mounted) {
      setState(() {
        _widgets = widgets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Widget',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _widgets.isEmpty
                    ? const Center(child: Text('No widgets found on this device.'))
                    : ListView.builder(
                        itemCount: _widgets.length,
                        itemBuilder: (context, index) {
                          final widgetData = _widgets[index];
                          final label = widgetData['label'] as String? ?? 'Widget';
                          final pkg = widgetData['providerPackage'] as String? ?? '';
                          final previewBytes = widgetData['preview'] as Uint8List?;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(label),
                              subtitle: Text(pkg, style: const TextStyle(fontSize: 12)),
                              trailing: previewBytes != null
                                  ? Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: MemoryImage(previewBytes),
                                          fit: BoxFit.scaleDown,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.widgets, size: 40),
                              onTap: () {
                                widget.onWidgetSelected(widgetData);
                              },
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
