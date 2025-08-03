import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/resource_providers.dart';
import '../../../models/rsa_key_pair.dart';
import '../../../providers/encryption_providers.dart';
import '../../../providers/rsa_providers.dart';
import '../../../resources/constants.dart';
import '../../encryption_page.dart';
import 'create_rsa_key_dialog.dart';

class RSAKeySelectionDialog extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String title;
  final String message;
  final bool publicKeyRequired;

  const RSAKeySelectionDialog({
    super.key,
    required this.primaryColor,
    this.title = 'Select RSA Key Pair',
    this.message = 'Please select an RSA key pair to use for decryption.',
    required this.publicKeyRequired,
  });

  @override
  ConsumerState<RSAKeySelectionDialog> createState() =>
      _RSAKeySelectionDialogState();
}

class _RSAKeySelectionDialogState extends ConsumerState<RSAKeySelectionDialog> {
  RSAKeyPair? _selectedKeyPair;

  @override
  Widget build(BuildContext context) {
    final keyPairsAsync = ref.watch(rsaKeyPairsProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            keyPairsAsync.when(
              data: (keyPairs) {
                if (keyPairs.isEmpty) {
                  return _buildEmptyState();
                }

                // Remove duplicates based on id
                final uniqueKeyPairs = <String, RSAKeyPair>{};
                for (final keyPair in keyPairs) {
                  uniqueKeyPairs[keyPair.id] = keyPair;
                }
                final deduplicatedKeyPairs = uniqueKeyPairs.values.toList();

                // Set default selection if none selected
                if (_selectedKeyPair == null &&
                    deduplicatedKeyPairs.isNotEmpty) {
                  _selectedKeyPair = deduplicatedKeyPairs.first;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Key Pairs:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<RSAKeyPair>(
                          value: _selectedKeyPair,
                          isExpanded: true,
                          hint: const Text('Select a key pair'),
                          items: deduplicatedKeyPairs.map((keyPair) {
                            return DropdownMenuItem<RSAKeyPair>(
                              value: keyPair,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    keyPair.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Created: ${_formatDate(keyPair.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (keyPair) {
                            setState(() {
                              _selectedKeyPair = keyPair;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Make sure you select the correct key pair that can decrypt this content.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading key pairs: $error',
                      style: TextStyle(color: Colors.red[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            widget.publicKeyRequired
                ? TextField(
                    onChanged: (val) {
                      try {
                        // Normalize the input PEM string
                        String normalized = val.trim().replaceAll(
                          RegExp(r'\r\n|\r|\n'),
                          '\n',
                        );
                        ref.read(rsaDecryptPublicKeyProvider.notifier).state =
                            normalized;
                        decryptPublicKeyGlobal = normalized;
                        // if (kDebugMode) {
                        //   print('Saved normalized public key: $normalized');
                        //   print('Key code units: ${normalized.codeUnits}');
                        // }
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error normalizing public key: $e');
                        }
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Public Key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        borderSide: BorderSide(
                          color: widget.primaryColor,
                          width: AppConstants.borderWidth,
                        ),
                      ),
                      errorText: ref.watch(rsaDecryptPublicKeyProvider).isEmpty
                          ? null
                          : (RegExp(
                                  r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n]+\n-----END PUBLIC KEY-----$',
                                ).hasMatch(
                                  ref.watch(rsaDecryptPublicKeyProvider),
                                )
                                ? null
                                : 'Invalid PEM format'),
                    ),
                    maxLines: 4,
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (keyPairsAsync.hasValue && keyPairsAsync.value!.isEmpty) ...[
          ElevatedButton(
            onPressed: _showCreateKeyDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Key Pair'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: _selectedKeyPair == null ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use Selected'),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.key_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Key Pairs Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You need to create or import an RSA key pair to decrypt this content.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selectedKeyPair);
  }

  void _showCreateKeyDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          CreateRSAKeyDialog(primaryColor: widget.primaryColor),
    ).then((_) {
      // Refresh the key pairs after creating a new one
      ref.refresh(rsaKeyPairsProvider);
    });
  }
}

// Utility function to show the RSA key selection dialog
Future<RSAKeyPair?> showRSAKeySelectionDialog({
  required BuildContext context,
  required Color primaryColor,
  String title = 'Select RSA Key Pair',
  String message = 'Please select an RSA key pair to use for decryption.',
  required bool publicKeyRequired,
}) {
  return showDialog<RSAKeyPair>(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (context) => RSAKeySelectionDialog(
      primaryColor: primaryColor,
      title: title,
      message: message,
      publicKeyRequired: publicKeyRequired,
    ),
  );
}
