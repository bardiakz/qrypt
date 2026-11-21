import 'package:flutter/material.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/services/obfuscation/custom_map_storage_service.dart';

/// Shows a dialog prompting the user to select one of their saved custom maps,
/// or import a new one directly.
Future<CustomObfuscationProfile?> showCustomMapPickerDialog(
  BuildContext context, {
  String title = 'Select Custom Obfuscation Map',
  String? message,
}) async {
  final storage = CustomMapStorageService.instance;
  await storage.initialize();

  if (!context.mounted) return null;

  return showDialog<CustomObfuscationProfile>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final profiles = storage.profiles;

          Future<void> openImportDialog() async {
            final imported = await showDialog<CustomObfuscationProfile>(
              context: context,
              builder: (ctx) => const _ImportMapForPickerDialog(),
            );

            if (imported != null) {
              setState(() {});
              if (context.mounted) {
                Navigator.of(context).pop(imported);
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message != null) ...[
                    Text(message, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  if (profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No custom maps saved on this device.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = profiles[index];
                          return ListTile(
                            leading: const Icon(Icons.vpn_key_outlined),
                            title: Text(p.name),
                            subtitle: Text(
                              'Created ${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: openImportDialog,
                child: const Text('Import New Map'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ImportMapForPickerDialog extends StatefulWidget {
  const _ImportMapForPickerDialog();

  @override
  State<_ImportMapForPickerDialog> createState() =>
      _ImportMapForPickerDialogState();
}

class _ImportMapForPickerDialogState extends State<_ImportMapForPickerDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Custom Map'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paste the JSON representation of the custom map below.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '{"v":1,"n":"...","m":[...]}',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isImporting
              ? null
              : () async {
                  setState(() {
                    _isImporting = true;
                    _error = null;
                  });
                  try {
                    final profile = await CustomMapStorageService.instance
                        .importMap(_controller.text.trim());
                    if (mounted) {
                      Navigator.of(context).pop(profile);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isImporting = false;
                        _error = e
                            .toString()
                            .replaceFirst('Exception: ', '')
                            .replaceFirst('Bad state: ', '');
                      });
                    }
                  }
                },
          child: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import & Use'),
        ),
      ],
    );
  }
}
