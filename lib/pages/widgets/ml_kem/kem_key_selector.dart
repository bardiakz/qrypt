import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import '../../../providers/kem_providers.dart';
import '../../../resources/global_resources.dart';
import '../asymmetric_selector_header.dart';
import '../qr/qr_share_dialog.dart';
import 'create_kem_key_dialog.dart';
import 'kem_key_management_dialog.dart';

enum KemKeyType { encrypt, decrypt }

class KemKeySelector extends ConsumerWidget {
  final Color primaryColor;
  final KemKeyType keyType;
  final String title;

  const KemKeySelector({
    super.key,
    required this.primaryColor,
    required this.keyType,
    this.title = 'KEM Key Pair',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyPairsAsync = ref.watch(kemKeyPairsProvider);
    final QryptKEMKeyPair? selectedKeyPair = ref.watch(_getSelectedProvider());
    final resolved = keyPairsAsync.whenOrNull(
      data: (keyPairs) => resolveSelectedKeyPair<QryptKEMKeyPair>(
        keyPairs,
        selectedKeyPair,
        (kp) => kp.id,
      ),
    );
    final effectiveSelected = resolved?.selected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getContainerBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsymmetricSelectorHeader(
            title: title,
            primaryColor: primaryColor,
            manageTooltip: 'Manage ML-KEM Keys',
            shareTooltip: effectiveSelected == null
                ? 'Share Public Key'
                : 'Share Public Key (${effectiveSelected.name})',
            onManagePressed: () => _showKeyManagementDialog(context, ref),
            onSharePublicKey: effectiveSelected == null
                ? null
                : () => _sharePublicKey(context, effectiveSelected),
          ),
          const SizedBox(height: 12),
          keyPairsAsync.when(
            data: (keyPairs) {
              if (keyPairs.isEmpty) {
                return Column(
                  children: [
                    const Text('No key pairs available'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showCreateKeyDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Create Key Pair'),
                    ),
                  ],
                );
              }

              final currentResolved = resolved!;
              final deduplicatedKeyPairs = currentResolved.items;
              final currentSelectedKeyPair = currentResolved.selected;

              if (currentResolved.defaultedToFirst &&
                  currentSelectedKeyPair != null) {
                // Update the provider to reflect this default selection
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateSelectedProvider(ref, currentSelectedKeyPair);
                });
              }

              return DropdownButtonFormField<QryptKEMKeyPair>(
                initialValue: currentSelectedKeyPair,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Select key pair',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                items: deduplicatedKeyPairs.map((keyPair) {
                  return DropdownMenuItem<QryptKEMKeyPair>(
                    value: keyPair,
                    child: Text(
                      keyPair.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (keyPair) {
                  if (keyPair != null) {
                    _updateSelectedProvider(ref, keyPair);
                  }
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }

  // Get the appropriate provider based on key type
  _getSelectedProvider() {
    switch (keyType) {
      case KemKeyType.encrypt:
        return selectedKemEncryptKeyPairProvider;
      case KemKeyType.decrypt:
        return selectedKemDecryptKeyPairProvider;
    }
  }

  // Update the appropriate provider based on key type
  void _updateSelectedProvider(WidgetRef ref, QryptKEMKeyPair keyPair) {
    switch (keyType) {
      case KemKeyType.encrypt:
        ref.read(selectedKemEncryptKeyPairProvider.notifier).state = keyPair;
        break;
      case KemKeyType.decrypt:
        ref.read(selectedKemDecryptKeyPairProvider.notifier).state = keyPair;
        break;
    }
  }

  void _sharePublicKey(BuildContext context, QryptKEMKeyPair keyPair) {
    showQrShareDialog(
      context: context,
      title: 'ML-KEM Public Key: ${keyPair.name}',
      data: base64Encode(keyPair.kemKeyPair.publicKey),
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this public key for encapsulation',
      primaryColor: primaryColor,
    );
  }

  void _showKeyManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => KemKeyManagementDialog(primaryColor: primaryColor),
    );
  }

  void _showCreateKeyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateKemKeyDialog(primaryColor: primaryColor),
    );
  }
}

class KemEncryptKeySelector extends StatelessWidget {
  final Color primaryColor;
  final String title;

  const KemEncryptKeySelector({
    super.key,
    required this.primaryColor,
    this.title = 'KEM Key Pair (Encrypt)',
  });

  @override
  Widget build(BuildContext context) {
    return KemKeySelector(
      primaryColor: primaryColor,
      keyType: KemKeyType.encrypt,
      title: title,
    );
  }
}

class KemDecryptKeySelector extends StatelessWidget {
  final Color primaryColor;

  const KemDecryptKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return KemKeySelector(
      primaryColor: primaryColor,
      keyType: KemKeyType.decrypt,
      title: 'KEM Key Pair (Decrypt)',
    );
  }
}
