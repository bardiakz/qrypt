import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/rsa_key_pair.dart';
import '../../../providers/rsa_providers.dart';
import '../qr/qr_share_dialog.dart';
import 'create_rsa_key_dialog.dart';

class RSAKeyManagementDialog extends ConsumerWidget {
  final Color primaryColor;

  const RSAKeyManagementDialog({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyPairsAsync = ref.watch(rsaKeyPairsProvider);

    return AlertDialog(
      title: const Text('Manage RSA Keys'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: keyPairsAsync.when(
          data: (keyPairs) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCreateKeyDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Generate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showImportKeyDialog(context, ref),
                      icon: const Icon(Icons.upload),
                      label: const Text('Import'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: keyPairs.length,
                    itemBuilder: (context, index) {
                      final keyPair = keyPairs[index];
                      return Card(
                        child: ListTile(
                          title: Text(keyPair.name),
                          subtitle: Text(
                            'Created: ${keyPair.createdAt.toString().split('.')[0]}',
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.download),
                                    SizedBox(width: 8),
                                    Text('Export'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteKeyPair(context, ref, keyPair.id);
                              } else if (value == 'export') {
                                _exportKeyPair(context, keyPair);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showCreateKeyDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => CreateRSAKeyDialog(primaryColor: primaryColor),
    );
  }

  void _showImportKeyDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => CreateRSAKeyDialog(primaryColor: primaryColor),
    );
  }

  void _deleteKeyPair(BuildContext context, WidgetRef ref, String keyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Key Pair'),
        content: const Text(
          'Are you sure you want to delete this key pair? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(rsaKeyServiceProvider).deleteKeyPair(keyId);
        ref.invalidate(rsaKeyPairsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key pair deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete key pair: $e')),
          );
        }
      }
    }
  }

  void _exportKeyPair(BuildContext context, RSAKeyPair keyPair) {
    bool showPrivateKey = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Export ${keyPair.name}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Public Key:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2, size: 20),
                      tooltip: 'Show Public Key QR',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        showQrShareDialog(
                          context: context,
                          title: 'RSA Public Key: ${keyPair.name}',
                          data: keyPair.publicKey,
                          kind: QrPayloadKind.publicKey,
                          subtitle: 'Share this public key with senders',
                          primaryColor: primaryColor,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(keyPair.publicKey),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Private Key:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        showPrivateKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(
                        showPrivateKey
                            ? 'Hide Private Key'
                            : 'Reveal Private Key',
                      ),
                      onPressed: () {
                        setDialogState(() {
                          showPrivateKey = !showPrivateKey;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (showPrivateKey)
                  SelectableText(keyPair.privateKey)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Hidden to protect against shoulder-surfing. Reveal only in a private environment.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
