import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import '../../../providers/ml_dsa_providers.dart';
import '../../../resources/global_resources.dart';
import '../asymmetric_selector_header.dart';
import '../qr/qr_share_dialog.dart';
import 'create_ml_dsa_key_dialog.dart';
import 'ml_dsa_key_management_dialog.dart';

enum MlDsaKeyType { sign, verify }

class MlDsaKeySelector extends ConsumerWidget {
  final Color primaryColor;
  final MlDsaKeyType keyType;
  final String title;

  const MlDsaKeySelector({
    super.key,
    required this.primaryColor,
    required this.keyType,
    this.title = 'ML-DSA Key Pair',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyPairsAsync = ref.watch(mlDsaKeyPairsProvider);
    final QryptMLDSAKeyPair? selectedKeyPair = ref.watch(_getSelectedProvider());
    final resolved = keyPairsAsync.whenOrNull(
      data: (keyPairs) => resolveSelectedKeyPair<QryptMLDSAKeyPair>(
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
            manageTooltip: 'Manage ML-DSA Keys',
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

              return DropdownButtonFormField<QryptMLDSAKeyPair>(
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
                  return DropdownMenuItem<QryptMLDSAKeyPair>(
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
      case MlDsaKeyType.sign:
        return selectedMlDsaSignKeyPairProvider;
      case MlDsaKeyType.verify:
        return selectedMlDsaVerifyKeyPairProvider;
    }
  }

  // Update the appropriate provider based on key type
  void _updateSelectedProvider(WidgetRef ref, QryptMLDSAKeyPair keyPair) {
    switch (keyType) {
      case MlDsaKeyType.sign:
        ref.read(selectedMlDsaSignKeyPairProvider.notifier).state = keyPair;
        break;
      case MlDsaKeyType.verify:
        ref.read(selectedMlDsaVerifyKeyPairProvider.notifier).state = keyPair;
        break;
    }
  }

  void _sharePublicKey(BuildContext context, QryptMLDSAKeyPair keyPair) {
    showQrShareDialog(
      context: context,
      title: 'ML-DSA Public Key: ${keyPair.name}',
      data: base64Encode(keyPair.publicKey),
      kind: QrPayloadKind.publicKey,
      subtitle: 'Share this verification key with recipients',
      primaryColor: primaryColor,
    );
  }

  void _showKeyManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) =>
          MlDsaKeyManagementDialog(primaryColor: primaryColor),
    );
  }

  void _showCreateKeyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateMlDsaKeyDialog(primaryColor: primaryColor),
    );
  }
}

class MlDsaSignKeySelector extends StatelessWidget {
  final Color primaryColor;
  final String title;

  const MlDsaSignKeySelector({
    super.key,
    required this.primaryColor,
    this.title = 'ML-DSA Key Pair (Sign)',
  });

  @override
  Widget build(BuildContext context) {
    return MlDsaKeySelector(
      primaryColor: primaryColor,
      keyType: MlDsaKeyType.sign,
      title: title,
    );
  }
}

class MlDsaVerifyKeySelector extends StatelessWidget {
  final Color primaryColor;

  const MlDsaVerifyKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return MlDsaKeySelector(
      primaryColor: primaryColor,
      keyType: MlDsaKeyType.verify,
      title: 'ML-DSA Key Pair (Verify)',
    );
  }
}
