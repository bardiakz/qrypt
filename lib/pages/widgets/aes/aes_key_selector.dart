import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/aes_key.dart';
import '../../../providers/aes_providers.dart';
import '../../../providers/encryption_providers.dart';
import '../../../resources/global_resources.dart';
import 'aes_key_management_dialog.dart';
import 'create_aes_key_dialog.dart';

enum AESKeyType { encrypt, decrypt }

class AESKeySelector extends ConsumerWidget {
  final Color primaryColor;
  final AESKeyType keyType;
  final String title;
  final void Function(AESKey)? onKeyChanged;

  const AESKeySelector({
    super.key,
    required this.primaryColor,
    required this.keyType,
    this.title = 'AES Symmetric Key',
    this.onKeyChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysAsync = ref.watch(aesKeysProvider);
    final selectedKey = ref.watch(_getSelectedProvider());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getContainerBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => _showKeyManagementDialog(context, ref),
                icon: Icon(Icons.key, color: primaryColor),
                tooltip: 'Manage AES Keys',
              ),
            ],
          ),
          const SizedBox(height: 12),
          keysAsync.when(
            data: (keys) {
              if (keys.isEmpty) {
                return Column(
                  children: [
                    const Text('No saved AES keys available'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showCreateKeyDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Create AES Key'),
                    ),
                  ],
                );
              }

              // Deduplicate keys based on id
              final uniqueKeys = <String, AESKey>{};
              for (final k in keys) {
                uniqueKeys[k.id] = k;
              }
              final deduplicatedKeys = uniqueKeys.values.toList();

              AESKey? currentSelectedKey;
              if (selectedKey != null) {
                try {
                  currentSelectedKey = deduplicatedKeys.firstWhere(
                    (k) => k.id == selectedKey.id,
                  );
                } catch (_) {
                  currentSelectedKey = null;
                }
              }

              if (currentSelectedKey == null && deduplicatedKeys.isNotEmpty) {
                currentSelectedKey = deduplicatedKeys.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateSelectedProvider(ref, deduplicatedKeys.first);
                });
              }

              return DropdownButtonFormField<AESKey>(
                initialValue: currentSelectedKey,
                decoration: InputDecoration(
                  hintText: 'Select AES key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                items: deduplicatedKeys.map((k) {
                  return DropdownMenuItem<AESKey>(
                    value: k,
                    child: Text('${k.name} (${k.key.length * 8}-bit)'),
                  );
                }).toList(),
                onChanged: (k) {
                  if (k != null) {
                    _updateSelectedProvider(ref, k);
                  }
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }

  _getSelectedProvider() {
    switch (keyType) {
      case AESKeyType.encrypt:
        return selectedAESEncryptKeyProvider;
      case AESKeyType.decrypt:
        return selectedAESDecryptKeyProvider;
    }
  }

  void _updateSelectedProvider(WidgetRef ref, AESKey key) {
    switch (keyType) {
      case AESKeyType.encrypt:
        ref.read(selectedAESEncryptKeyProvider.notifier).state = key;
        ref.read(customEncryptAesKeyProvider.notifier).state = key.key;
        ref.read(useCustomEncryptAesKeyProvider.notifier).state = true;
        break;
      case AESKeyType.decrypt:
        ref.read(selectedAESDecryptKeyProvider.notifier).state = key;
        ref.read(customDecryptAesKeyProvider.notifier).state = key.key;
        ref.read(useCustomDecryptAesKeyProvider.notifier).state = true;
        break;
    }
    onKeyChanged?.call(key);
  }

  void _showKeyManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AESKeyManagementDialog(
        primaryColor: primaryColor,
        onKeySelected: (key) => _updateSelectedProvider(ref, key),
      ),
    );
  }

  void _showCreateKeyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateAESKeyDialog(primaryColor: primaryColor),
    );
  }
}

class AESEncryptKeySelector extends StatelessWidget {
  final Color primaryColor;
  final void Function(AESKey)? onKeyChanged;

  const AESEncryptKeySelector({
    super.key,
    required this.primaryColor,
    this.onKeyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AESKeySelector(
      primaryColor: primaryColor,
      keyType: AESKeyType.encrypt,
      title: 'AES Key (Encrypt)',
      onKeyChanged: onKeyChanged,
    );
  }
}

class AESDecryptKeySelector extends StatelessWidget {
  final Color primaryColor;
  final void Function(AESKey)? onKeyChanged;

  const AESDecryptKeySelector({
    super.key,
    required this.primaryColor,
    this.onKeyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AESKeySelector(
      primaryColor: primaryColor,
      keyType: AESKeyType.decrypt,
      title: 'AES Key (Decrypt)',
      onKeyChanged: onKeyChanged,
    );
  }
}
