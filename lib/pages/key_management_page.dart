import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/pages/widgets/ml_dsa/ml_dsa_key_selector.dart';
import 'package:qrypt/pages/widgets/ml_kem/kem_key_selector.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_selector.dart';
import '../../../resources/global_resources.dart';

class KeyManagementPage extends ConsumerWidget {
  const KeyManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).primaryColor;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Key Management'),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: getContainerBackgroundColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: getBorderColor(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 32, color: primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cryptographic Keys',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          // const SizedBox(height: 4),
                          // Text(
                          //   'Manage your encryption, decryption, and signing keys',
                          //   style: Theme.of(context).textTheme.bodyMedium
                          //       ?.copyWith(color: Colors.grey[600]),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // RSA Keys Section
              _buildSectionHeader(
                context,
                'RSA Keys',
                'Traditional asymmetric encryption',
                Icons.lock,
                primaryColor,
              ),
              const SizedBox(height: 12),
              RSAEncryptKeySelector(primaryColor: primaryColor),

              const SizedBox(height: 32),

              // KEM Keys Section
              _buildSectionHeader(
                context,
                'ML-KEM Keys',
                'Key Encapsulation Mechanism for quantum-resistant encryption',
                Icons.shield,
                primaryColor,
              ),
              const SizedBox(height: 12),
              KemEncryptKeySelector(primaryColor: primaryColor),

              const SizedBox(height: 32),

              // ML-DSA Keys Section
              _buildSectionHeader(
                context,
                'ML-DSA Keys',
                'Signature Algorithm for quantum-resistant signing',
                Icons.edit_document,
                primaryColor,
              ),
              const SizedBox(height: 12),
              MlDsaSignKeySelector(primaryColor: primaryColor),

              const SizedBox(height: 32),

              // Additional Actions Section
              // Container(
              //   padding: const EdgeInsets.all(16.0),
              //   decoration: BoxDecoration(
              //     color: getContainerBackgroundColor(context),
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(color: getBorderColor(context)),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         'Key Management Actions',
              //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //       const SizedBox(height: 16),
              //       Row(
              //         children: [
              //           Expanded(
              //             child: ElevatedButton.icon(
              //               onPressed: () => _showKeyImportDialog(context),
              //               icon: const Icon(Icons.file_upload),
              //               label: const Text('Import Keys'),
              //               style: ElevatedButton.styleFrom(
              //                 backgroundColor: primaryColor.withOpacity(0.1),
              //                 foregroundColor: primaryColor,
              //                 elevation: 0,
              //               ),
              //             ),
              //           ),
              //           const SizedBox(width: 12),
              //           Expanded(
              //             child: ElevatedButton.icon(
              //               onPressed: () => _showKeyExportDialog(context),
              //               icon: const Icon(Icons.file_download),
              //               label: const Text('Export Keys'),
              //               style: ElevatedButton.styleFrom(
              //                 backgroundColor: primaryColor.withOpacity(0.1),
              //                 foregroundColor: primaryColor,
              //                 elevation: 0,
              //               ),
              //             ),
              //           ),
              //         ],
              //       ),
              //       const SizedBox(height: 12),
              //       SizedBox(
              //         width: double.infinity,
              //         child: ElevatedButton.icon(
              //           onPressed: () => _showKeyBackupDialog(context),
              //           icon: const Icon(Icons.backup),
              //           label: const Text('Backup All Keys'),
              //           style: ElevatedButton.styleFrom(
              //             backgroundColor: Colors.green.withOpacity(0.1),
              //             foregroundColor: Colors.green[700],
              //             elevation: 0,
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              //
              // const SizedBox(height: 32),

              // Security Notice
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.amber[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Notice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep your private keys secure and never share them. Consider backing up your keys in a secure location.',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color primaryColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showKeyImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Keys'),
        content: const Text('Select the key files you want to import.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement key import functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Key import functionality coming soon'),
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showKeyExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Keys'),
        content: const Text(
          'Choose which keys to export and the export format.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement key export functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Key export functionality coming soon'),
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showKeyBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup All Keys'),
        content: const Text(
          'This will create a secure backup of all your keys. Make sure to store it in a safe location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement backup functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Key backup functionality coming soon'),
                ),
              );
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }
}
