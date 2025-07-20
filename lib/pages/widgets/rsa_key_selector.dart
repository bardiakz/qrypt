import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/pages/widgets/rsa_key_management_dialog.dart';

import '../../models/rsa_key_pair.dart';
import '../../providers/rsa_providers.dart';
import 'create_rsa_key_dialog.dart';

class RSAKeySelector extends ConsumerWidget {
  final Color primaryColor;

  const RSAKeySelector({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyPairsAsync = ref.watch(rsaKeyPairsProvider);
    final selectedKeyPair = ref.watch(selectedRSAKeyPairProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RSA Key Pair',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              final uniqueKeyPairs = <String, RSAKeyPair>{};
              for (final keyPair in keyPairs) {
                uniqueKeyPairs[keyPair.id] = keyPair;
              }
              final deduplicatedKeyPairs = uniqueKeyPairs.values.toList();

              // Find the currently selected key pair by ID in the fresh list
              RSAKeyPair? currentSelectedKeyPair;

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
                  ref.read(selectedRSAKeyPairProvider.notifier).state =
                      deduplicatedKeyPairs.first;
                });
              }

              return DropdownButtonFormField<RSAKeyPair>(
                value: currentSelectedKeyPair,
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
                    child: Text(keyPair.name),
                  );
                }).toList(),
                onChanged: (keyPair) {
                  ref.read(selectedRSAKeyPairProvider.notifier).state = keyPair;
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
