import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/aes_key.dart';
import '../../../providers/aes_providers.dart';
import '../../../resources/global_resources.dart';

class CreateAESKeyDialog extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String? initialKey;

  const CreateAESKeyDialog({
    super.key,
    required this.primaryColor,
    this.initialKey,
  });

  @override
  ConsumerState<CreateAESKeyDialog> createState() => _CreateAESKeyDialogState();
}

class _CreateAESKeyDialogState extends ConsumerState<CreateAESKeyDialog> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  int _selectedLength = 32;
  bool _useManualInput = false;
  String _generatedPreview = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialKey != null && widget.initialKey!.isNotEmpty) {
      _keyController.text = widget.initialKey!;
      _useManualInput = true;
    } else {
      _regenerateKey();
    }
  }

  void _regenerateKey() {
    setState(() {
      _generatedPreview = generateRandomAesKey(length: _selectedLength);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save AES Key'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Key Name',
                  hintText: 'e.g. Personal, Work, Project',
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
                        if (!value && _generatedPreview.isEmpty) {
                          _regenerateKey();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Manual Input / Paste')),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 140),
                child: _useManualInput
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _keyController,
                            decoration: InputDecoration(
                              labelText: 'AES Secret Key',
                              hintText: '16, 24, or 32 characters',
                              errorText: _keyController.text.isEmpty
                                  ? null
                                  : validateAesKey(_keyController.text),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.paste),
                                    tooltip: 'Paste from clipboard',
                                    onPressed: () async {
                                      final text = await pasteFromClipboard(
                                        context,
                                      );
                                      if (text != null) {
                                        setState(() {
                                          _keyController.text = text;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter exactly 16 (128-bit), 24 (192-bit), or 32 (256-bit) characters.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Key Length',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedLength,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            selectedItemBuilder: (BuildContext context) =>
                                const [
                                  Text(
                                    '128-bit (16 chars)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '192-bit (24 chars)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '256-bit (32 chars)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                            items: const [
                              DropdownMenuItem(
                                value: 16,
                                child: Text(
                                  '128-bit (16 chars)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 24,
                                child: Text(
                                  '192-bit (24 chars)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 32,
                                child: Text(
                                  '256-bit (32 chars) - Recommended',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLength = val;
                                  _regenerateKey();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: getTextFieldBackgroundColor(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: getBorderColor(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _generatedPreview,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  tooltip: 'Copy key to share with recipient',
                                  onPressed: () => copyToClipboard(
                                    _generatedPreview,
                                    context,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'Re-generate',
                                  onPressed: _regenerateKey,
                                ),
                              ],
                            ),
                          ),
                        ],
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
          onPressed: _saveKey,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveKey() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the key')),
      );
      return;
    }

    final keyString = _useManualInput
        ? _keyController.text.trim()
        : _generatedPreview;

    final validationError = validateAesKey(keyString);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final newKey = AESKey(
      id: const Uuid().v4(),
      name: name,
      key: keyString,
      createdAt: DateTime.now(),
    );

    try {
      final storage = ref.read(aesKeyStorageServiceProvider);
      await storage.saveKey(newKey);
      await storage.setLastUsedKeyId(newKey.id);
      ref.invalidate(aesKeysProvider);

      if (mounted) {
        Navigator.of(context).pop(newKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AES key "$name" saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save key: $e')));
      }
    }
  }
}
