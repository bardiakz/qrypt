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
            final controller = TextEditingController();
            String? error;

            final imported = await showDialog<CustomObfuscationProfile>(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (ctx, setImportState) {
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
                            controller: controller,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '{"v":1,"n":"...","m":[...]}',
                              border: const OutlineInputBorder(),
                              errorText: error,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final profile = await storage.importMap(
                                controller.text.trim(),
                              );
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop(profile);
                              }
                            } catch (e) {
                              setImportState(() {
                                error = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              });
                            }
                          },
                          child: const Text('Import & Use'),
                        ),
                      ],
                    );
                  },
                );
              },
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
