import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/rsa_key_pair.dart';
import '../../../providers/rsa_providers.dart';

class CreateRSAKeyDialog extends ConsumerStatefulWidget {
  final Color primaryColor;

  const CreateRSAKeyDialog({super.key, required this.primaryColor});

  @override
  ConsumerState<CreateRSAKeyDialog> createState() => _CreateRSAKeyDialogState();
}

class _CreateRSAKeyDialogState extends ConsumerState<CreateRSAKeyDialog> {
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _privateKeyController = TextEditingController();
  bool _isGenerating = false;
  bool _useManualInput = false;

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
      title: const Text('Create RSA Key Pair'),
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
                  labelText: 'Private Key',
                  hintText: 'Paste private key here',
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
      final service = ref.read(rsaKeyServiceProvider);
      RSAKeyPair keyPair;

      if (_useManualInput) {
        if (_publicKeyController.text.trim().isEmpty ||
            _privateKeyController.text.trim().isEmpty) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter both public and private keys'),
            ),
          );
          return;
        }

        if (!service.validateKeyPair(
          _publicKeyController.text,
          _privateKeyController.text,
        )) {
          setState(() {
            _isGenerating = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid key pair')));
          return;
        }

        // For manual input, create the key pair object and save it
        keyPair = RSAKeyPair(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          publicKey: _publicKeyController.text.trim(),
          privateKey: _privateKeyController.text.trim(),
          createdAt: DateTime.now(),
        );

        // Save manually created key pair
        await service.saveKeyPair(keyPair);
      } else {
        // For generation, generateKeyPair() already saves it internally
        keyPair = await service.generateKeyPair(_nameController.text.trim());
      }

      // Refresh the provider to update the UI
      ref.refresh(rsaKeyPairsProvider);

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
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
