import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/ml_dsa_providers.dart';
import '../../../resources/constants.dart';

class MlDsaPublicKeyInputDialog extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String title;
  final String message;

  const MlDsaPublicKeyInputDialog({
    super.key,
    required this.primaryColor,
    this.title = 'Enter ML-DSA Public Key',
    this.message =
        'Please enter the sender\'s ML-DSA public key to verify the signature.',
  });

  @override
  ConsumerState<MlDsaPublicKeyInputDialog> createState() =>
      _MlDsaPublicKeyInputDialogState();
}

class _MlDsaPublicKeyInputDialogState
    extends ConsumerState<MlDsaPublicKeyInputDialog> {
  final TextEditingController _publicKeyController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Initialize with existing public key if available
    final existingKey = ref.read(verifyMlDsaPublicKeyProvider);
    if (existingKey.isNotEmpty) {
      _publicKeyController.text = existingKey;
    }
  }

  @override
  void dispose() {
    _publicKeyController.dispose();
    super.dispose();
  }

  // bool _isValidPemFormat(String publicKey) {
  //   if (publicKey.trim().isEmpty) return false;
  //
  //   final pemRegex = RegExp(
  //     r'^-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/=\n\s]+\n-----END PUBLIC KEY-----$',
  //     multiLine: true,
  //   );
  //
  //   return pemRegex.hasMatch(publicKey.trim());
  // }

  void _validateAndSavePublicKey(String value) {
    try {
      // Normalize the input by removing whitespace and newlines
      String normalized = value.trim().replaceAll(RegExp(r'\s+'), '');

      setState(() {
        if (normalized.isEmpty) {
          _errorText = 'Public key is required';
        }
        // else if (!_isValidPemFormat(normalized)) {
        //   _errorText = 'Invalid ML-DSA public key format. Expected a base64-encoded string.';
        // }
        else {
          _errorText = null;
          // Save to provider
          ref.read(verifyMlDsaPublicKeyProvider.notifier).state = normalized;
          verifyMlDsaPublicKeyGlobal = normalized;

          if (kDebugMode) {
            print(
              'Saved normalized ML-DSA public key: ${normalized.substring(0, 50)}...',
            );
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorText = 'Error processing public key: $e';
      });

      if (kDebugMode) {
        print('Error normalizing public key: $e');
      }
    }
  }

  bool _canConfirm() {
    return _publicKeyController.text.trim().isNotEmpty && _errorText == null;
  }

  void _confirmSelection() {
    final publicKey = _publicKeyController.text.trim();
    if (publicKey.isNotEmpty && _errorText == null) {
      Navigator.of(context).pop(publicKey);
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Public Key Input Field
            TextField(
              controller: _publicKeyController,
              onChanged: _validateAndSavePublicKey,
              decoration: InputDecoration(
                labelText: 'Sender\'s ML-DSA Public Key ',
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
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                  borderSide: const BorderSide(color: Colors.red, width: 1.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                  borderSide: const BorderSide(color: Colors.red, width: 1.0),
                ),
                errorText: _errorText,
                errorMaxLines: 3,
              ),
              maxLines: 8,
              minLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),

            const SizedBox(height: 12),

            // Info message
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Enter the sender\'s public key in PEM format to verify the ML-DSA signature.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canConfirm() ? _confirmSelection : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Verify'),
        ),
      ],
    );
  }
}

// Utility function to show the ML-DSA public key input dialog
Future<String?> showMlDsaPublicKeyInputDialog({
  required BuildContext context,
  required Color primaryColor,
  String title = 'Enter ML-DSA Public Key',
  String message =
      'Please enter the sender\'s ML-DSA public key to verify the signature.',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (context) => MlDsaPublicKeyInputDialog(
      primaryColor: primaryColor,
      title: title,
      message: message,
    ),
  );
}
