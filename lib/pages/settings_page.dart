import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
          _buildSectionHeader('Security'),
          _buildSecuritySettings(context, ref),
          const SizedBox(height: 24),

          // Data Management Section
          _buildSectionHeader('Data Management'),
          _buildDataManagementSettings(context, ref),
          const SizedBox(height: 24),

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
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('App Theme'),
            subtitle: const Text('Choose your preferred theme'),
            trailing: DropdownButton<String>(
              value: 'System', // TODO: Connect to theme provider
              items: const [
                DropdownMenuItem(value: 'Light', child: Text('Light')),
                DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                DropdownMenuItem(value: 'System', child: Text('System')),
              ],
              onChanged: (value) {
                // TODO: Implement theme change logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Theme changed to $value')),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('Accent Color'),
            subtitle: const Text('Customize app accent color'),
            trailing: CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onTap: () {
              // TODO: Implement color picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Color picker coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Lock'),
            subtitle: const Text('Use fingerprint/face unlock'),
            value: true,
            // TODO: Connect to security provider
            onChanged: (value) {
              // TODO: Implement biometric toggle
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Biometric lock ${value ? 'enabled' : 'disabled'}',
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_clock),
            title: const Text('Auto Lock'),
            subtitle: const Text('Lock app when backgrounded'),
            value: false,
            // TODO: Connect to security provider
            onChanged: (value) {
              // TODO: Implement auto lock toggle
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Auto lock ${value ? 'enabled' : 'disabled'}'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Auto Lock Timeout'),
            subtitle: const Text('5 minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show timeout selector
              _showTimeoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementSettings(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Export Data'),
            subtitle: const Text('Export your encrypted data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement data export
              _showExportDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Import Data'),
            subtitle: const Text('Import from backup file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement data import
              _showImportDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Settings'),
            subtitle: const Text('Configure data synchronization'),
            trailing: Switch(
              value: false, // TODO: Connect to sync provider
              onChanged: (value) {
                // TODO: Implement sync toggle
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync ${value ? 'enabled' : 'disabled'}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0 (Build 1)'),
            // TODO: Get from package info
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show version details
              _showVersionDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub Repository'),
            subtitle: const Text('View source code and contribute'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              // TODO: Replace with actual GitHub URL
              const url = 'https://github.com/username/qrypt';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open GitHub repository'),
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report Issue'),
            subtitle: const Text('Report bugs or request features'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              // TODO: Replace with actual issues URL
              const url = 'https://github.com/username/qrypt/issues';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open issues page')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // TODO: Show privacy policy
              _showPrivacyDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // TODO: Show terms of service
              _showTermsDialog(context);
            },
          ),
        ],
      ),
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
              _showClearDataDialog(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade700),
            title: Text(
              'Sign Out',
              style: TextStyle(color: Colors.red.shade700),
            ),
            subtitle: const Text('Sign out of your account'),
            trailing: Icon(Icons.chevron_right, color: Colors.red.shade700),
            onTap: () {
              _showSignOutDialog(context);
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

  void _showVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Qrypt'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            Text('Build: 1'),
            Text('Release Date: July 2025'),
            SizedBox(height: 16),
            Text('A secure encryption and password management app.'),
          ],
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
            'Your privacy is important to us. This app stores all data locally '
            'and uses end-to-end encryption. No data is sent to external servers '
            'without your explicit consent.\n\n'
            'For the full privacy policy, please visit our website.',
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

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using this app, you agree to use it responsibly and in accordance '
            'with all applicable laws. The app is provided "as is" without warranty.\n\n'
            'For the full terms of service, please visit our website.',
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

  void _showClearDataDialog(BuildContext context) {
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
              _confirmClearData(context);
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

  void _confirmClearData(BuildContext context) {
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
              // TODO: Implement clear data logic
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

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement sign out logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
