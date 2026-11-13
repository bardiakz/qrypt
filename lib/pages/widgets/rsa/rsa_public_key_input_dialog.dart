import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/rsa_key_pair.dart';
import '../../../providers/rsa_providers.dart';
import '../../../resources/constants.dart';

class RSAPublicKeyInputDialog extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String title;
  final String message;

  const RSAPublicKeyInputDialog({
    super.key,
    required this.primaryColor,
    this.title = 'Enter RSA Public Key',
    this.message =
        'Please enter or select the sender\'s RSA public key to verify the signature.',
  });

  @override
  ConsumerState<RSAPublicKeyInputDialog> createState() =>
      _RSAPublicKeyInputDialogState();
}

class _RSAPublicKeyInputDialogState
    extends ConsumerState<RSAPublicKeyInputDialog> {
  final TextEditingController _publicKeyController = TextEditingController();
  String? _errorText;
  RSAKeyPair? _selectedSavedKeyPair;

  @override
  void initState() {
    super.initState();
    final existingKey = ref.read(rsaVerifyPublicKeyProvider);
    if (existingKey.isNotEmpty) {
      _publicKeyController.text = existingKey;
    }
  }

  @override
  void dispose() {
    _publicKeyController.dispose();
    super.dispose();
  }

  void _validateAndSavePublicKey(String value) {
    try {
      final normalized = value.trim().replaceAll(RegExp(r'\r\n|\r|\n'), '\n');

      setState(() {
        if (normalized.isEmpty) {
          _errorText = 'Public key is required';
        } else if (!normalized.contains('BEGIN PUBLIC KEY')) {
          _errorText =
              'Invalid RSA public key format. Expected PEM format with BEGIN PUBLIC KEY.';
        } else {
          _errorText = null;
          ref.read(rsaVerifyPublicKeyProvider.notifier).state = normalized;
          rsaVerifyPublicKeyGlobal = normalized;
        }
      });
    } catch (e) {
      setState(() {
        _errorText = 'Error processing public key: $e';
      });
      if (kDebugMode) {
        print('Error normalizing RSA public key: $e');
      }
    }
  }

  void _confirmSelection() {
    final publicKey = _publicKeyController.text.trim().replaceAll(
      RegExp(r'\r\n|\r|\n'),
      '\n',
    );
    if (publicKey.isNotEmpty && _errorText == null) {
      Navigator.of(context).pop(publicKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyPairsAsync = ref.watch(rsaKeyPairsProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),

              keyPairsAsync.when(
                data: (keyPairs) {
                  if (keyPairs.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select from Saved Key Pairs:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<RSAKeyPair>(
                        value: _selectedSavedKeyPair,
                        hint: const Text('Choose saved key pair...'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: keyPairs.map((kp) {
                          return DropdownMenuItem(
                            value: kp,
                            child: Text(kp.name),
                          );
                        }).toList(),
                        onChanged: (kp) {
                          if (kp != null) {
                            setState(() {
                              _selectedSavedKeyPair = kp;
                              _publicKeyController.text = kp.publicKey;
                              _validateAndSavePublicKey(kp.publicKey);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'OR PASTE PEM KEY',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              TextField(
                controller: _publicKeyController,
                onChanged: _validateAndSavePublicKey,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Sender\'s RSA Public Key (PEM)',
                  hintText: '-----BEGIN PUBLIC KEY-----\n...',
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
                  errorText: _errorText,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _publicKeyController.text.trim().isNotEmpty &&
                  _errorText == null
              ? _confirmSelection
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

Future<String?> showRSAPublicKeyInputDialog({
  required BuildContext context,
  required Color primaryColor,
  String title = 'Select RSA Verification Key',
  String message =
      'This content was signed with RSA-PSS. Please select or paste the sender\'s public key for verification.',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RSAPublicKeyInputDialog(
      primaryColor: primaryColor,
      title: title,
      message: message,
    ),
  );
}
