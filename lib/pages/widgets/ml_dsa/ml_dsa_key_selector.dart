import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import '../../../providers/ml_dsa_providers.dart';
import '../../../resources/global_resources.dart';
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
    final selectedKeyPair = ref.watch(_getSelectedProvider());

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
              ),
            ],
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

              // Remove duplicates based on id to prevent dropdown issues
              final uniqueKeyPairs = <String, QryptMLDSAKeyPair>{};
              for (final keyPair in keyPairs) {
                uniqueKeyPairs[keyPair.id] = keyPair;
              }
              final deduplicatedKeyPairs = uniqueKeyPairs.values.toList();

              // Find the currently selected key pair by ID in the fresh list
              QryptMLDSAKeyPair? currentSelectedKeyPair;

              if (selectedKeyPair != null) {
                // Look for a key pair with the same ID in the current list
                try {
                  currentSelectedKeyPair = deduplicatedKeyPairs.firstWhere(
                    (kp) => kp.id == selectedKeyPair.id,
                  );
                } catch (e) {
                  // If the selected key pair is not found, it might have been deleted
                  currentSelectedKeyPair = null;
                }
              }

              // If no valid selection, default to the first key pair
              if (currentSelectedKeyPair == null &&
                  deduplicatedKeyPairs.isNotEmpty) {
                currentSelectedKeyPair = deduplicatedKeyPairs.first;
                // Update the provider to reflect this default selection
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateSelectedProvider(ref, deduplicatedKeyPairs.first);
                });
              }

              return DropdownButtonFormField<QryptMLDSAKeyPair>(
                initialValue: currentSelectedKeyPair,
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
                    child: Text(keyPair.name),
                  );
                }).toList(),
                onChanged: (keyPair) {
                  if (keyPair != null) {
                    _updateSelectedProvider(ref, keyPair);
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

  const MlDsaSignKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return MlDsaKeySelector(
      primaryColor: primaryColor,
      keyType: MlDsaKeyType.sign,
      title: 'ML-DSA Key Pair (Sign)',
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
