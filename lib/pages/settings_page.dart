import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/services/obfuscation/custom_map_storage_service.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/qr/qr_share_dialog.dart';

import '../providers/aes_providers.dart';
import '../providers/encryption_providers.dart';
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
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Disclaimer & Terms'),
                subtitle: const Text('No-warranty and compatibility terms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  DisclaimerDialog.show(context, isFirstTime: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('Offline and data storage policy'),
                trailing: const Icon(Icons.chevron_right),
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
    final profile = await showDialog<CustomObfuscationProfile>(
      context: context,
      builder: (context) => const _GenerateRandomMapDialog(),
    );
    if (profile != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom map "${profile.name}" generated and saved'),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _showShareMapDialog(
    BuildContext context,
    CustomObfuscationProfile profile,
  ) async {
    final shareJson = CustomMapStorageService.instance.exportMap(profile);

    await showQrShareDialog(
      context: context,
      title: 'Share: ${profile.name}',
      data: shareJson,
      kind: QrPayloadKind.obfuscationMap,
      subtitle:
          'Recipients must import this map to decrypt messages obfuscated with it.',
      copySuccessMessage: 'Copied "${profile.name}" JSON to clipboard',
    );
  }

  Future<void> _showImportMapDialog(BuildContext context) async {
    final imported = await showDialog<List<CustomObfuscationProfile>>(
      context: context,
      builder: (context) => const _ImportCustomMapDialog(),
    );
    if (imported != null && imported.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Successfully imported ${imported.length} custom map(s)'),
        ),
      );
      if (mounted) setState(() {});
    }
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '100% Offline & Private',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Qrypt does not collect, monitor, track, or transmit any user data or telemetry. The application functions entirely offline without internet dependencies.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  'Local Secure Storage',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Cryptographic keys (AES, RSA, ML-KEM, ML-DSA), custom obfuscation maps, and user preferences are stored exclusively on your device using OS-backed secure storage. No data is ever uploaded or shared.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  'User Data Sovereignty',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'You have total control over your data. You can permanently erase all stored keys and application settings at any time via "Clear All Saved Data" below or by uninstalling the app.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  'No Warranty & Compatibility',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'The software is provided "AS IS". Backward compatibility is not guaranteed across future algorithm or format updates. See Disclaimer & Terms for full legal details.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL(
              context,
              'https://github.com/bardiakz/qrypt/blob/main/PRIVACY_POLICY.md',
              'Could not open Privacy Policy online',
            ),
            child: const Text('View Online'),
          ),
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
            onPressed: () async {
              Navigator.pop(context);
              const storage = FlutterSecureStorage();
              await storage.deleteAll();
              ref.invalidate(rsaKeyPairsProvider);
              ref.invalidate(kemKeyPairsProvider);
              ref.invalidate(mlDsaKeyPairsProvider);
              ref.invalidate(aesKeysProvider);
              ref.read(selectedAESEncryptKeyProvider.notifier).state = null;
              ref.read(selectedAESDecryptKeyProvider.notifier).state = null;
              ref.read(selectedCustomMapProvider.notifier).state = null;
              await CustomMapStorageService.instance.loadAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data cleared successfully')),
                );
              }
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

class _GenerateRandomMapDialog extends StatefulWidget {
  const _GenerateRandomMapDialog();

  @override
  State<_GenerateRandomMapDialog> createState() =>
      _GenerateRandomMapDialogState();
}

class _GenerateRandomMapDialogState extends State<_GenerateRandomMapDialog> {
  static const _poolOptions = [
    ('en-words', 'English Words (282 words)'),
    ('fa-words', 'Persian Words (220 words)'),
    ('latin', 'Latin Characters (26 chars)'),
    ('persian', 'Persian Characters (32 chars)'),
    ('cyrillic', 'Cyrillic Characters (40 chars)'),
    ('greek', 'Greek Characters (24 chars)'),
    ('hebrew', 'Hebrew Characters (27 chars)'),
    ('armenian', 'Armenian Characters (38 chars)'),
    ('georgian', 'Georgian Characters (33 chars)'),
    ('hiragana', 'Hiragana Characters (58 chars)'),
  ];

  late final TextEditingController _nameController;
  String _selectedPool = 'en-words';
  String? _errorText;
  bool _isGenerating = false;
  bool _isCustomName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _defaultNameForPool(_selectedPool),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultNameForPool(String pool) {
    final existingProfiles = CustomMapStorageService.instance.profiles;
    final baseName = switch (pool) {
      'en-words' => 'English Words Map',
      'fa-words' => 'Persian Words Map',
      'latin' => 'Latin Chars Map',
      'persian' => 'Persian Chars Map',
      'cyrillic' => 'Cyrillic Chars Map',
      'greek' => 'Greek Chars Map',
      'hebrew' => 'Hebrew Chars Map',
      'armenian' => 'Armenian Chars Map',
      'georgian' => 'Georgian Chars Map',
      'hiragana' => 'Hiragana Chars Map',
      _ => 'Custom Map',
    };
    int count = 1;
    while (existingProfiles.any((p) => p.name == '$baseName $count')) {
      count++;
    }
    return '$baseName $count';
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _nameController,
              onChanged: (val) {
                _isCustomName = val.trim().isNotEmpty;
              },
              decoration: const InputDecoration(
                labelText: 'Map Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPool,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Character / Word Pool',
                border: OutlineInputBorder(),
              ),
              items: _poolOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.$1,
                  child: Text(
                    opt.$2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPool = val;
                    if (!_isCustomName) {
                      _nameController.text = _defaultNameForPool(val);
                    }
                  });
                }
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
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
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isGenerating
              ? null
              : () async {
                  setState(() {
                    _isGenerating = true;
                    _errorText = null;
                  });
                  try {
                    final map = V2MapGenerator.generate(_selectedPool);
                    final name = _nameController.text.trim().isEmpty
                        ? _defaultNameForPool(_selectedPool)
                        : _nameController.text.trim();
                    final profile =
                        await CustomMapStorageService.instance.saveMap(
                      name: name,
                      map: map,
                    );
                    if (mounted) {
                      Navigator.of(context).pop(profile);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isGenerating = false;
                        _errorText = e
                            .toString()
                            .replaceFirst('Exception: ', '')
                            .replaceFirst('Bad state: ', '');
                      });
                    }
                  }
                },
          child: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate & Save'),
        ),
      ],
    );
  }
}

class _ImportCustomMapDialog extends StatefulWidget {
  const _ImportCustomMapDialog();

  @override
  State<_ImportCustomMapDialog> createState() => _ImportCustomMapDialogState();
}

class _ImportCustomMapDialogState extends State<_ImportCustomMapDialog> {
  late final TextEditingController _controller;
  String? _errorText;
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
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{"v":1,"n":"...","m":[...]}',
                border: const OutlineInputBorder(),
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
                    _controller.text = data.text!;
                  }
                },
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
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
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isImporting
              ? null
              : () async {
                  setState(() {
                    _isImporting = true;
                    _errorText = null;
                  });
                  try {
                    final imported = await CustomMapStorageService.instance
                        .importAllMaps(_controller.text.trim());
                    if (imported.isEmpty) {
                      throw const FormatException(
                        'No valid maps found to import',
                      );
                    }
                    if (mounted) {
                      Navigator.of(context).pop(imported);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isImporting = false;
                        _errorText = e
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
              : const Text('Import'),
        ),
      ],
    );
  }
}
