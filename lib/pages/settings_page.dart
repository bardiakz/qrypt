import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/obfuscation/custom_map_storage_service.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';
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
    return FutureBuilder<List<CustomObfuscationProfile>>(
      future: CustomMapStorageService.instance.loadAll(),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? CustomMapStorageService.instance.profiles;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('Custom Obfuscation Maps'),
                subtitle: Text(
                  'Generate, import, and share custom substitution maps. Built-in maps are locked.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.casino_outlined, size: 18),
                      label: const Text('Generate Random Map'),
                      onPressed: () => _showGenerateRandomMapDialog(context),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Import Map'),
                      onPressed: () => _showImportMapDialog(context),
                    ),
                    if (profiles.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Export All'),
                        onPressed: () => _exportAllMaps(context),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (profiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No custom maps created yet. Generate a random map or import one to get started.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    return ListTile(
                      leading: Icon(
                        Icons.tune,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '17 keys • Created ${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_2),
                            tooltip: 'Share / QR Code',
                            onPressed: () => _showShareMapDialog(context, p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade600,
                            tooltip: 'Delete',
                            onPressed: () => _confirmDeleteMap(context, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showGenerateRandomMapDialog(BuildContext context) async {
    final nameController = TextEditingController(text: 'My Custom Map');
    String selectedPool = 'en-words';
    String? errorText;
    bool isGenerating = false;

    final poolOptions = const [
      ('en-words', 'English Words (282 words)'),
      ('fa-words', 'Persian Words (220 words)'),
      ('latin', 'Latin Characters (26 chars)'),
      ('persian', 'Persian Characters (32 chars)'),
      ('cyrillic', 'Cyrillic Characters (40 chars)'),
      ('greek', 'Greek Characters (24 chars)'),
      ('hebrew', 'Hebrew Characters (27 chars)'),
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Generate Random Map'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generates a fresh, mathematically validated 17-key map using cryptographically secure randomness.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Map Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPool,
                      decoration: const InputDecoration(
                        labelText: 'Character / Word Pool',
                        border: OutlineInputBorder(),
                      ),
                      items: poolOptions.map((opt) {
                        return DropdownMenuItem(
                          value: opt.$1,
                          child: Text(opt.$2),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedPool = val);
                        }
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
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
                  onPressed: isGenerating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isGenerating
                      ? null
                      : () async {
                          setState(() {
                            isGenerating = true;
                            errorText = null;
                          });
                          try {
                            final map = V2MapGenerator.generate(selectedPool);
                            final name = nameController.text.trim().isEmpty
                                ? 'My Custom Map'
                                : nameController.text.trim();
                            await CustomMapStorageService.instance.saveMap(
                              name: name,
                              map: map,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Custom map "$name" generated and saved',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isGenerating = false;
                              errorText = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  child: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate & Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _showShareMapDialog(
    BuildContext context,
    CustomObfuscationProfile profile,
  ) async {
    final shareJson = CustomMapStorageService.instance.exportMap(profile);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share: ${profile.name}'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Recipients must import this map to decrypt messages obfuscated with it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: shareJson,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy JSON to Clipboard'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareJson));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Copied "${profile.name}" JSON to clipboard',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportMapDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    bool isImporting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Import Custom Map'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Paste the JSON map or bundle below to import it into your saved maps.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: '{"v":1,"n":"...","m":[...]}',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.paste, size: 16),
                        label: const Text('Paste from Clipboard'),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data != null && data.text != null) {
                            controller.text = data.text!;
                          }
                        },
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
                  onPressed: isImporting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isImporting
                      ? null
                      : () async {
                          setState(() {
                            isImporting = true;
                            errorText = null;
                          });
                          try {
                            final imported = await CustomMapStorageService
                                .instance
                                .importAllMaps(controller.text.trim());
                            if (imported.isEmpty) {
                              throw const FormatException(
                                'No valid maps found to import',
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Successfully imported ${imported.length} custom map(s)',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isImporting = false;
                              errorText = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  child: isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _exportAllMaps(BuildContext context) async {
    final bundleJson =
        await CustomMapStorageService.instance.exportAllMaps();
    await Clipboard.setData(ClipboardData(text: bundleJson));
    if (context.mounted) {
      final count = CustomMapStorageService.instance.profiles.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported $count custom map(s) to clipboard'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteMap(
    BuildContext context,
    CustomObfuscationProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Custom Map?'),
          content: Text(
            'Are you sure you want to delete "${profile.name}"? '
            'Messages obfuscated with this map cannot be decrypted unless re-imported.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await CustomMapStorageService.instance.deleteMap(profile.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${profile.name}"')),
        );
      }
    }
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
