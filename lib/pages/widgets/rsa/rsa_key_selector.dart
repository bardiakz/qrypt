import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/rsa_key_pair.dart';
import '../../../providers/rsa_providers.dart';
import '../../../resources/global_resources.dart';
import '../asymmetric_selector_header.dart';
import '../qr/qr_share_dialog.dart';
import 'create_rsa_key_dialog.dart';
import 'rsa_key_management_dialog.dart';

enum RSAKeyType { encrypt, decrypt, sign }

class RSAKeySelector extends ConsumerWidget {
  final Color primaryColor;
  final RSAKeyType keyType;
  final String title;

  const RSAKeySelector({
    super.key,
    required this.primaryColor,
    required this.keyType,
    this.title = 'RSA Key Pair',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyPairsAsync = ref.watch(rsaKeyPairsProvider);
    final RSAKeyPair? selectedKeyPair = ref.watch(_getSelectedProvider());
    final resolved = keyPairsAsync.whenOrNull(
      data: (keyPairs) => resolveSelectedKeyPair<RSAKeyPair>(
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
            manageTooltip: 'Manage RSA Keys',
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

              return DropdownButtonFormField<RSAKeyPair>(
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
                  return DropdownMenuItem<RSAKeyPair>(
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
      case RSAKeyType.encrypt:
        return selectedRSAEncryptKeyPairProvider;
      case RSAKeyType.decrypt:
        return selectedRSADecryptKeyPairProvider;
      case RSAKeyType.sign:
        return selectedRSASignKeyPairProvider;
    }
  }

  // Update the appropriate provider based on key type
  void _updateSelectedProvider(WidgetRef ref, RSAKeyPair keyPair) {
    switch (keyType) {
      case RSAKeyType.encrypt:
        ref.read(selectedRSAEncryptKeyPairProvider.notifier).state = keyPair;
        break;
      case RSAKeyType.decrypt:
        ref.read(selectedRSADecryptKeyPairProvider.notifier).state = keyPair;
        break;
      case RSAKeyType.sign:
        ref.read(selectedRSASignKeyPairProvider.notifier).state = keyPair;
        break;
    }
  }

  void _sharePublicKey(BuildContext context, RSAKeyPair keyPair) {
    showQrShareDialog(
      context: context,
      title: 'RSA Public Key: ${keyPair.name}',
      data: keyPair.publicKey,
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this public key with senders',
      primaryColor: primaryColor,
    );
  }

  void _showKeyManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => RSAKeyManagementDialog(primaryColor: primaryColor),
    );
  }

  void _showCreateKeyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateRSAKeyDialog(primaryColor: primaryColor),
    );
  }
}

class RSAEncryptKeySelector extends StatelessWidget {
  final Color primaryColor;
  final String title;

  const RSAEncryptKeySelector({
    super.key,
    required this.primaryColor,
    this.title = 'RSA Key Pair (Encrypt)',
  });

  @override
  Widget build(BuildContext context) {
    return RSAKeySelector(
      primaryColor: primaryColor,
      keyType: RSAKeyType.encrypt,
      title: title,
    );
  }
}

class RSADecryptKeySelector extends StatelessWidget {
  final Color primaryColor;

  const RSADecryptKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return RSAKeySelector(
      primaryColor: primaryColor,
      keyType: RSAKeyType.decrypt,
      title: 'RSA Key Pair (Decrypt)',
    );
  }
}

class RSASignKeySelector extends StatelessWidget {
  final Color primaryColor;

  const RSASignKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return RSAKeySelector(
      primaryColor: primaryColor,
      keyType: RSAKeyType.sign,
      title: 'RSA Key Pair (Sign)',
    );
  }
}
