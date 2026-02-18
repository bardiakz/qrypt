import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/resource_providers.dart';
import '../providers/rsa_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Theme Section
          _buildSectionHeader('Appearance'),
          _buildThemeSelector(context, ref),
          const SizedBox(height: 24),

          _buildSectionHeader('Obfuscation Maps'),
          _buildObfuscationMapSettings(context),
          const SizedBox(height: 24),

          // Security Section
          // _buildSectionHeader('Security'),
          // _buildSecuritySettings(context, ref),
          // const SizedBox(height: 24),

          // Data Management Section
          // _buildSectionHeader('Data Management'),
          // _buildDataManagementSettings(context, ref),
          // const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildAboutSettings(context, ref),
          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          _buildDangerZone(context, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('App Theme'),
            subtitle: const Text('Choose your preferred theme'),
            trailing: DropdownButton<ThemeMode>(
              value: currentTheme,
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
              ],
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setTheme(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Theme changed to ${value.label}')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          // SwitchListTile(
          //   secondary: const Icon(Icons.fingerprint),
          //   title: const Text('Biometric Lock'),
          //   subtitle: const Text('Use fingerprint/face unlock'),
          //   value: true,
          //   // TODO: Connect to security provider
          //   onChanged: (value) {
          //     // TODO: Implement biometric toggle
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(
          //         content: Text(
          //           'Biometric lock ${value ? 'enabled' : 'disabled'}',
          //         ),
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }

  // Widget _buildDataManagementSettings(BuildContext context, WidgetRef ref) {
  //   return Card(
  //     child: Column(
  //       children: [
  //         ListTile(
  //           leading: const Icon(Icons.backup),
  //           title: const Text('Export Data'),
  //           subtitle: const Text('Export your encrypted data'),
  //           trailing: const Icon(Icons.chevron_right),
  //           onTap: () {
  //             // TODO: Implement data export
  //             _showExportDialog(context);
  //           },
  //         ),
  //         ListTile(
  //           leading: const Icon(Icons.restore),
  //           title: const Text('Import Data'),
  //           subtitle: const Text('Import from backup file'),
  //           trailing: const Icon(Icons.chevron_right),
  //           onTap: () {
  //             // TODO: Implement data import
  //             _showImportDialog(context);
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildAboutSettings(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final info = snapshot.data!;
        final version = info.version;
        final build = info.buildNumber;

        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                subtitle: Text('v$version (Build $build)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showVersionDialog(context, version, build);
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('GitHub Repository'),
                subtitle: const Text('View source code and contribute'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchURL(
                  context,
                  'https://github.com/bardiakz/qrypt',
                  'Could not open GitHub repository',
                ),
              ),

              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report Issue'),
                subtitle: const Text('Report bugs or request features'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchURL(
                  context,
                  'https://github.com/bardiakz/qrypt/issues',
                  'Could not open issues page',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Disclaimer'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  _showPrivacyDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDangerZone(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.red.shade50,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
            title: Text(
              'Clear All Saved Data',
              style: TextStyle(color: Colors.red.shade700),
            ),
            subtitle: const Text('This action cannot be undone'),
            trailing: Icon(Icons.chevron_right, color: Colors.red.shade700),
            onTap: () {
              _showClearDataDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObfuscationMapSettings(BuildContext context) {
    const editableMethods = <ObfuscationMethod>[
      ObfuscationMethod.en1,
      ObfuscationMethod.en2,
      ObfuscationMethod.fa1,
      ObfuscationMethod.fa2,
    ];

    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Custom Obfuscation Maps'),
            subtitle: Text(
              'Customize EN1, EN2, FA1, and FA2 substitution maps.',
            ),
          ),
          const Divider(height: 1),
          ...editableMethods.map((method) {
            return FutureBuilder<Map<String, String>?>(
              future: Obfuscate.getCustomMap(method),
              builder: (context, snapshot) {
                final hasCustomMap =
                    snapshot.hasData &&
                    snapshot.data != null &&
                    snapshot.data!.isNotEmpty;

                return ListTile(
                  leading: Icon(
                    hasCustomMap ? Icons.tune : Icons.lock_outline,
                    color: hasCustomMap
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(method.displayName),
                  subtitle: Text(
                    hasCustomMap
                        ? 'Custom map active (built-in remains unchanged)'
                        : 'Using built-in map (read-only)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openObfuscationMapEditor(context, method),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openObfuscationMapEditor(
    BuildContext context,
    ObfuscationMethod method,
  ) async {
    final customMap = await Obfuscate.getCustomMap(method);
    final builtInMap = Obfuscate.getBuiltInMapForMethod(method);
    final hasCustomMap = customMap != null && customMap.isNotEmpty;
    final controller = TextEditingController(
      text: hasCustomMap ? _mapToEditorText(customMap) : '',
    );

    if (!context.mounted) {
      controller.dispose();
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        String? errorText;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> saveMap() async {
              setState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                final parsed = _parseEditorText(controller.text);
                await Obfuscate.setCustomMap(method, parsed);
                TagManager.initializeTags();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${method.displayName} custom map saved'),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  errorText = e.toString().replaceFirst('Exception: ', '');
                  isSaving = false;
                });
              }
            }

            Future<void> resetMap() async {
              setState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                await Obfuscate.clearCustomMap(method);
                TagManager.initializeTags();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${method.displayName} reset to built-in map',
                      ),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  errorText = e.toString().replaceFirst('Exception: ', '');
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: Text(
                hasCustomMap
                    ? 'Edit Custom ${method.displayName}'
                    : 'Add Custom ${method.displayName}',
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Built-in map is read-only. Add your custom map below. Format: key => value (one mapping per line). Use [space] for a space key.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      maxLines: 16,
                      minLines: 12,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'A => atom\\nB => binary\\n[space] => blank',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          controller.text = _mapToEditorText(builtInMap);
                        },
                  child: const Text('Use Built-in as Template'),
                ),
                if (hasCustomMap)
                  TextButton(
                    onPressed: isSaving ? null : resetMap,
                    child: const Text('Reset to Built-in'),
                  ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveMap,
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (mounted) {
      setState(() {});
    }
  }

  String _mapToEditorText(Map<String, String> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
        .map((entry) => '${_serializeKey(entry.key)} => ${entry.value}')
        .join('\n');
  }

  String _serializeKey(String key) {
    if (key == ' ') return '[space]';
    return key;
  }

  Map<String, String> _parseEditorText(String text) {
    final map = <String, String>{};
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final separator = rawLine.indexOf('=>');
      if (separator < 0) {
        throw FormatException('Line ${i + 1}: expected key => value');
      }

      final rawKey = rawLine.substring(0, separator).trim();
      final value = rawLine.substring(separator + 2).trim();
      final key = rawKey == '[space]' ? ' ' : rawKey;

      if (key.isEmpty) {
        throw FormatException('Line ${i + 1}: key cannot be empty');
      }
      if (value.isEmpty) {
        throw FormatException('Line ${i + 1}: value cannot be empty');
      }
      if (map.containsKey(key)) {
        throw FormatException('Line ${i + 1}: duplicate key "$rawKey"');
      }

      map[key] = value;
    }

    if (map.isEmpty) {
      throw FormatException('Map cannot be empty');
    }

    return map;
  }

  void _showTimeoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Immediately'),
              leading: Radio<int>(value: 0, groupValue: 5, onChanged: (_) {}),
            ),
            ListTile(
              title: const Text('1 minute'),
              leading: Radio<int>(value: 1, groupValue: 5, onChanged: (_) {}),
            ),
            ListTile(
              title: const Text('5 minutes'),
              leading: Radio<int>(value: 5, groupValue: 5, onChanged: (_) {}),
            ),
            ListTile(
              title: const Text('15 minutes'),
              leading: Radio<int>(value: 15, groupValue: 5, onChanged: (_) {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Save timeout setting
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'This will create an encrypted backup file of all your data. '
          'Keep this file secure as it contains sensitive information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement export logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export functionality coming soon'),
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'Select an encrypted backup file to import. '
          'This will merge with your existing data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement import logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Import functionality coming soon'),
                ),
              );
            },
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  void _showVersionDialog(BuildContext context, String version, String build) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Qrypt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Version: $version'), Text('Build: $build')],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'This tool is for educational and legitimate use cases only. Users are responsible for compliance with local laws and regulations regarding encryption and data protection.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your saved passwords, notes, and settings. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmClearData(context, ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'are you sure you want to permanently delete all secure storage data?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final storage = FlutterSecureStorage();
              storage.deleteAll();
              ref.invalidate(rsaKeyPairsProvider);
              ref.invalidate(kemKeyPairsProvider);
              ref.invalidate(mlDsaKeyPairsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(
    BuildContext context,
    String url,
    String errorMessage,
  ) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening URL: $e')));
      }
    }
  }
}
