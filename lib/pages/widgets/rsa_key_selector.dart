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
                      child: const Text('Create Key Pair'),
                    ),
                  ],
                );
              }

              return DropdownButtonFormField<RSAKeyPair>(
                value: selectedKeyPair,
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
                items: keyPairs.map((keyPair) {
                  return DropdownMenuItem(
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
