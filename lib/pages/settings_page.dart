import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/resource_providers.dart';
import '../providers/rsa_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Type "DELETE" to confirm you want to permanently delete all data.',
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
              ref.refresh(rsaKeyPairsProvider);
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
