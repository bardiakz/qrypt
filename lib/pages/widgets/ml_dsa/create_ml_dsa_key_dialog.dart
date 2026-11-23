import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/ml_dsa_key_pair.dart';
import '../../../providers/ml_dsa_providers.dart';
import '../../../services/ml_dsa/ml_dsa_key_service.dart';
import 'package:qrypt/services/oqs_bridge.dart';

class CreateMlDsaKeyDialog extends ConsumerStatefulWidget {
  final Color primaryColor;

  const CreateMlDsaKeyDialog({super.key, required this.primaryColor});

  @override
  ConsumerState<CreateMlDsaKeyDialog> createState() =>
      _CreateMlDsaKeyDialogState();
}

class _CreateMlDsaKeyDialogState extends ConsumerState<CreateMlDsaKeyDialog> {
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _privateKeyController = TextEditingController();
  bool _isGenerating = false;
  bool _useManualInput = false;
  String _selectedAlgorithm = 'ML-DSA-65';

  // Available ML-DSA algorithms
  final List<String> _algorithms = ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87'];

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
      title: const Text('Create ML-DSA Key Pair'),
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
            const SizedBox(height: 16),
            if (!_useManualInput) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedAlgorithm,
                decoration: const InputDecoration(
                  labelText: 'Algorithm',
                  border: OutlineInputBorder(),
                ),
                items: _algorithms.map((algorithm) {
                  return DropdownMenuItem<String>(
                    value: algorithm,
                    child: Text(algorithm),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedAlgorithm = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
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
              DropdownButtonFormField<String>(
                initialValue: _selectedAlgorithm,
                decoration: const InputDecoration(
                  labelText: 'Algorithm',
                  border: OutlineInputBorder(),
                ),
                items: _algorithms.map((algorithm) {
                  return DropdownMenuItem<String>(
                    value: algorithm,
                    child: Text(algorithm),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedAlgorithm = value;
                    });
                  }
                },
              ),
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

    MlDsaKeyService? scopedService;
    try {
      scopedService = MlDsaKeyService(algorithm: _selectedAlgorithm);
      QryptMLDSAKeyPair keyPair;

      if (_useManualInput) {
        final rawPublicKey = _publicKeyController.text.trim();
        final rawSecretKey = _privateKeyController.text.trim();

        if (rawPublicKey.isEmpty || rawSecretKey.isEmpty) {
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

        final SignatureKeyPair kp;
        try {
          kp = SignatureKeyPair(
            publicKey: base64Decode(rawPublicKey),
            secretKey: base64Decode(rawSecretKey),
          );
        } on FormatException {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keys must be valid Base64-encoded strings'),
            ),
          );
          return;
        }

        // Validate the key pair before saving
        if (!await scopedService.validateKeyPair(kp)) {
          setState(() {
            _isGenerating = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid $_selectedAlgorithm key pair — keys do not match or have wrong length',
                ),
              ),
            );
          }
          return;
        }

        // Create ML-DSA key pair from manual input
        keyPair = QryptMLDSAKeyPair.fromComponents(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          algorithm: _selectedAlgorithm,
          publicKey: kp.publicKey,
          secretKey: kp.secretKey,
          createdAt: DateTime.now(),
        );

        // Save manually created key pair
        await scopedService.saveKeyPair(keyPair);
      } else {
        // For generation, generateKeyPair() already saves it internally
        keyPair = await scopedService.generateKeyPair(
          _nameController.text.trim(),
        );
      }

      // Invalidate the provider to update the UI
      ref.invalidate(mlDsaKeyPairsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key pair "${keyPair.name}" created successfully'),
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
      scopedService?.dispose();
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
