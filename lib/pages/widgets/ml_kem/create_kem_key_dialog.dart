import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/services/oqs_bridge.dart';
import 'package:uuid/uuid.dart';

import '../../../models/kem_key_pair.dart';
import '../../../models/kyber_models.dart';
import '../../../providers/kem_providers.dart';

class CreateKemKeyDialog extends ConsumerStatefulWidget {
  final Color primaryColor;

  const CreateKemKeyDialog({super.key, required this.primaryColor});

  @override
  ConsumerState<CreateKemKeyDialog> createState() => _CreateKemKeyDialogState();
}

class _CreateKemKeyDialogState extends ConsumerState<CreateKemKeyDialog> {
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _privateKeyController = TextEditingController();
  bool _isGenerating = false;
  bool _useManualInput = false;
  MLKemKeySize _selectedKeySize = MLKemKeySize.kem768;

  @override
  void dispose() {
    _nameController.dispose();
    _publicKeyController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create KEM Key Pair'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Key Pair Name',
                hintText: 'Enter a name for this key pair',
              ),
            ),
            if (!_useManualInput) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<MLKemKeySize>(
                initialValue: _selectedKeySize,
                decoration: const InputDecoration(
                  labelText: 'Key Size',
                  helperText: 'ML-KEM-768 is recommended for general post-quantum security',
                ),
                items: MLKemKeySize.values.map((size) {
                  return DropdownMenuItem<MLKemKeySize>(
                    value: size,
                    child: Text(
                      '${size.displayName}${size == MLKemKeySize.kem768 ? ' (Recommended)' : ''}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedKeySize = value;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Switch(
                  value: _useManualInput,
                  onChanged: (value) {
                    setState(() {
                      _useManualInput = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('Manual Input'),
              ],
            ),
            if (_useManualInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _publicKeyController,
                decoration: const InputDecoration(
                  labelText: 'Public Key',
                  hintText: 'Paste public key here',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _privateKeyController,
                decoration: const InputDecoration(
                  labelText: 'Secret Key',
                  hintText: 'Paste Secret key here',
                ),
                maxLines: 4,
                // obscureText: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : _createKeyPair,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_useManualInput ? 'Import' : 'Generate'),
        ),
      ],
    );
  }

  void _createKeyPair() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the key pair')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final service = ref.read(kemKeyServiceProvider);
      QryptKEMKeyPair keyPair;

      if (_useManualInput) {
        if (_publicKeyController.text.trim().isEmpty ||
            _privateKeyController.text.trim().isEmpty) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter both public and Secret keys'),
            ),
          );
          return;
        }

        final pubBytes = base64Decode(_publicKeyController.text.trim());
        final secBytes = base64Decode(_privateKeyController.text.trim());
        final detectedSize = MLKemKeySizeExtension.fromPublicKeyLength(pubBytes.length) ??
            MLKemKeySizeExtension.fromSecretKeyLength(secBytes.length);
        final detectedAlg = detectedSize?.displayName ?? 'ML-KEM-768';

        KEMKeyPair kp = KEMKeyPair(
          publicKey: pubBytes,
          secretKey: secBytes,
        );
        final isValid = await service.validateKeyPair(kp, algorithm: detectedAlg);
        if (!isValid) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid key pair - keys do not work together')),
          );
          return;
        }

        keyPair = QryptKEMKeyPair(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          kemKeyPair: kp,
          createdAt: DateTime.now(),
          algorithm: detectedAlg,
        );

        // Save manually created key pair
        await service.saveKeyPair(keyPair);
      } else {
        // For generation, generateKeyPair() saves it internally with the chosen algorithm
        keyPair = await service.generateKeyPair(
          _nameController.text.trim(),
          algorithm: _selectedKeySize.displayName,
        );
      }

      // Invalidate the provider to update the UI
      ref.invalidate(kemKeyPairsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key pair "${keyPair.name}" (${keyPair.algorithm ?? _selectedKeySize.displayName}) created successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create key pair: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
