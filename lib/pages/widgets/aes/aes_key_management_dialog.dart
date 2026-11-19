import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/aes_key.dart';
import '../../../providers/aes_providers.dart';
import '../../../resources/global_resources.dart';
import 'create_aes_key_dialog.dart';

class AESKeyManagementDialog extends ConsumerWidget {
  final Color primaryColor;
  final void Function(AESKey)? onKeySelected;

  const AESKeyManagementDialog({
    super.key,
    required this.primaryColor,
    this.onKeySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysAsync = ref.watch(aesKeysProvider);

    return AlertDialog(
      title: const Text('Manage AES Keys'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: keysAsync.when(
          data: (keys) {
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
                      label: const Text('Import / Paste'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: keys.isEmpty
                      ? const Center(
                          child: Text(
                            'No AES keys saved yet.\nGenerate or import one to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: keys.length,
                          itemBuilder: (context, index) {
                            final key = keys[index];
                            final bitLength = key.bitLength;
                            return Card(
                              child: ListTile(
                                onTap: onKeySelected != null
                                    ? () {
                                        onKeySelected!(key);
                                        Navigator.of(context).pop();
                                      }
                                    : null,
                                title: Text(
                                  key.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '$bitLength-bit (${key.byteLength} bytes) • ${key.createdAt.toString().split('.')[0]}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      tooltip: 'Copy key',
                                      onPressed: () =>
                                          copyToClipboard(key.key, context),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      tooltip: 'Delete key',
                                      onPressed: () =>
                                          _deleteKey(context, ref, key),
                                    ),
                                  ],
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
    showDialog(
      context: context,
      builder: (context) => CreateAESKeyDialog(primaryColor: primaryColor),
    );
  }

  void _showImportKeyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) =>
          CreateAESKeyDialog(primaryColor: primaryColor, initialKey: ''),
    );
  }

  Future<void> _deleteKey(
    BuildContext context,
    WidgetRef ref,
    AESKey key,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AES Key'),
        content: Text('Are you sure you want to delete "${key.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final storage = ref.read(aesKeyStorageServiceProvider);
        await storage.deleteKey(key.id);
        ref.invalidate(aesKeysProvider);

        // Clear active selection if the deleted key was selected
        final selectedEncrypt = ref.read(selectedAESEncryptKeyProvider);
        if (selectedEncrypt?.id == key.id) {
          ref.read(selectedAESEncryptKeyProvider.notifier).state = null;
        }
        final selectedDecrypt = ref.read(selectedAESDecryptKeyProvider);
        if (selectedDecrypt?.id == key.id) {
          ref.read(selectedAESDecryptKeyProvider.notifier).state = null;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AES key "${key.name}" deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete key: $e')));
        }
      }
    }
  }
}
